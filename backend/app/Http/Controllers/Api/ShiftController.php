<?php

namespace App\Http\Controllers\Api;

use App\Domain\Inventory\BarCheckTemplateService;
use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\ShiftCashSummaryService;
use App\Services\ShiftHistoryQueryService;
use App\Services\ShiftSnapshotService;
use App\Services\StockCountService;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\TenantContext;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** The authenticated operator's shift lifecycle and its canonical read models. */
class ShiftController extends Controller
{
    private const DIFFERENCE_REASONS = ['change_error', 'unrecorded_transaction', 'unrecorded_withdrawal', 'unrecorded_expense', 'unknown_surplus', 'unknown_shortage', 'other'];

    public function __construct(
        private readonly BarCheckTemplateService $barCheckTemplates,
        private readonly ShiftCashSummaryService $cashSummary,
        private readonly ShiftSnapshotService $snapshots,
        private readonly ShiftHistoryQueryService $history,
        private readonly StockCountService $counts,
        private readonly BranchAccessService $branches,
    ) {}

    public function current(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $branchId = $this->requestedBranchId($request, $tenantId);
        $shift = $this->openShift($request, $tenantId, $branchId);

        return response()->json(['data' => $shift ? $this->serialize($shift) : null]);
    }

    /** The one payload used by overview and close-wizard screens. */
    public function snapshot(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $shift = $this->openShift($request, $tenantId, $this->requestedBranchId($request, $tenantId));

        return response()->json(['data' => $shift ? $this->snapshots->buildSnapshot($tenantId, $shift) : null]);
    }

    public function history(Request $request): JsonResponse
    {
        $data = $request->validate(['page' => ['nullable', 'integer', 'min:1'], 'perPage' => ['nullable', 'integer', 'min:1', 'max:100']]);

        return response()->json($this->history->list($request->attributes->get('auth_user'), (int) ($data['page'] ?? 1), (int) ($data['perPage'] ?? 25)));
    }

    public function report(Request $request, string $shiftNumber): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $actor = $request->attributes->get('auth_user');
        $shift = DB::table('shifts')->where('tenant_id', $tenantId)->where('shift_number', $shiftNumber)->where('status', 'closed')->whereNull('deleted_at')->first();
        abort_if(! $shift || ! in_array((int) $shift->branch_id, $this->branches->accessibleBranchIds($actor), true), 404, 'Shift report not found.');

        return response()->json(['data' => $this->closingPayload($tenantId, $shift)]);
    }

    public function open(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validate(['branchId' => ['required', 'integer', $this->tenantExists('branches', $tenantId)], 'userId' => ['prohibited'], 'openingCash' => ['required', 'numeric', 'min:0'], 'note' => ['nullable', 'string', 'max:4000']]);
        $this->branches->authorizeRequestBranch($request, (int) $data['branchId']);
        $actor = $request->attributes->get('auth_user');
        $shift = DB::transaction(function () use ($tenantId, $data, $actor): object {
            DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->first();
            $now = now();
            $drawerIds = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('branch_id', $data['branchId'])
                ->where('kind', 'cash')->where('type', 'cash_drawer')->where('is_active', true)->pluck('id');
            $id = DB::table('shifts')->insertGetId(['tenant_id' => $tenantId, 'branch_id' => $data['branchId'], 'user_id' => $actor->id, 'financial_location_id' => $drawerIds->count() === 1 ? $drawerIds->first() : null, 'shift_number' => $this->nextShiftNumber($tenantId, $now->toDateString()), 'opening_cash' => $data['openingCash'], 'status' => 'open', 'opened_at' => $now, 'notes' => $data['note'] ?? null, 'created_at' => $now, 'updated_at' => $now]);

            return DB::table('shifts')->where('id', $id)->first();
        });

        return response()->json(['data' => $this->serialize($shift)], 201);
    }

    public function close(Request $request, int $shift): JsonResponse
    {
        $data = $request->validate([
            'closingCash' => ['required', 'numeric', 'min:0'], 'note' => ['nullable', 'string', 'max:4000'],
            'cashDifferenceReason' => ['nullable', Rule::in(self::DIFFERENCE_REASONS)], 'cashDifferenceReasonDetail' => ['nullable', 'string', 'max:4000'],
            'barCountLines' => ['nullable', 'array'], 'barCountLines.*.inventoryItemId' => ['required_with:barCountLines', 'integer'], 'barCountLines.*.counted' => ['required_with:barCountLines', 'numeric', 'min:0'],
        ]);
        $tenantId = TenantContext::id($request);
        $actor = $request->attributes->get('auth_user');
        $closed = DB::transaction(function () use ($request, $data, $tenantId, $actor, $shift): object {
            $row = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shift)->whereNull('deleted_at')->lockForUpdate()->first();
            abort_if(! $row, 404, 'Shift not found.');
            $this->branches->authorizeRequestBranch($request, (int) $row->branch_id);
            abort_unless((int) $row->user_id === (int) $actor->id, 403, 'Only the shift owner can close this shift.');
            abort_unless($row->status === 'open', 422, 'Only an open shift can be closed.');
            $this->submitRequiredBarCounts($request, $tenantId, $row, $data['barCountLines'] ?? [], FinancialActor::id($request, $tenantId));
            $this->assertNoPendingRequiredBarCheck($tenantId, $row);
            $summary = $this->cashSummary->summarize($tenantId, $row);
            $difference = Money::cents($data['closingCash']) - Money::cents($summary['expectedCash']);
            if (abs($difference) > 50 && empty($data['cashDifferenceReason'])) {
                abort(422, 'A cash difference reason is required.');
            }
            if (($data['cashDifferenceReason'] ?? null) === 'other' && trim((string) ($data['cashDifferenceReasonDetail'] ?? '')) === '') {
                abort(422, 'Additional details are required for other.');
            }
            $number = $row->shift_number ?: $this->nextShiftNumber($tenantId, now()->toDateString());
            DB::table('shifts')->where('id', $row->id)->update(['shift_number' => $number, 'report_number' => 'RPT-'.str_replace('SH-', '', $number), 'closing_cash' => $data['closingCash'], 'expected_cash' => $summary['expectedCash'], 'cash_difference' => Money::decimal($difference), 'cash_difference_reason' => $data['cashDifferenceReason'] ?? null, 'cash_difference_reason_detail' => $data['cashDifferenceReasonDetail'] ?? null, 'status' => 'closed', 'closed_at' => now(), 'notes' => $data['note'] ?? $row->notes, 'updated_at' => now()]);

            return DB::table('shifts')->where('id', $row->id)->first();
        });

        return response()->json(['data' => $this->closingPayload($tenantId, $closed)]);
    }

    private function requestedBranchId(Request $request, int $tenantId): int
    {
        $request->validate(['branchId' => ['nullable', 'integer', $this->tenantExists('branches', $tenantId)]]);
        $branchId = (int) $request->query('branchId');
        if ($branchId > 0) {
            $this->branches->authorizeRequestBranch($request, $branchId);
        }

        return $branchId;
    }

    private function openShift(Request $request, int $tenantId, int $branchId): ?object
    {
        $actor = $request->attributes->get('auth_user');

        return DB::table('shifts')->where('tenant_id', $tenantId)->where('user_id', $actor->id)->whereIn('branch_id', $this->branches->accessibleBranchIds($actor))->when($branchId > 0, fn ($query) => $query->where('branch_id', $branchId))->where('status', 'open')->whereNull('deleted_at')->latest('opened_at')->first();
    }

    private function submitRequiredBarCounts(Request $request, int $tenant, object $shift, array $lines, ?int $actorId): void
    {
        $templates = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('branch_id', $shift->branch_id)->where('is_active', true)->where('required_for_shift_close', true)->get();
        foreach ($templates as $template) {
            if (! $this->barCheckTemplates->isUsable($tenant, $template)) {
                continue;
            }
            $countId = $this->counts->startBarCheck($request, $tenant, (int) $shift->id, (int) $template->warehouse_id, $actorId);
            foreach ($lines as $line) {
                $this->counts->upsertLine($tenant, $countId, ['itemId' => $line['inventoryItemId'], 'countedQuantity' => (string) $line['counted']], $actorId);
            }
            $this->counts->transition($request, $tenant, $countId, 'submit', $actorId);
            $this->counts->transition($request, $tenant, $countId, 'approve', $actorId);
            $this->counts->transition($request, $tenant, $countId, 'post', $actorId);
        }
    }

    private function assertNoPendingRequiredBarCheck(int $tenant, object $shift): void
    {
        $pending = DB::table('bar_check_templates as t')->where('t.tenant_id', $tenant)->where('t.branch_id', $shift->branch_id)->where('t.is_active', true)->where('t.required_for_shift_close', true)->whereNotExists(fn ($query) => $query->selectRaw('1')->from('stock_counts as c')->whereColumn('c.bar_check_template_id', 't.id')->where('c.shift_id', $shift->id)->where('c.status', 'posted'))->exists();
        abort_if($pending, 422, 'Complete the required bar check before closing the shift.');
    }

    /** @return array<string, mixed> */
    private function closingPayload(int $tenant, object $shift): array
    {
        $snapshot = $this->snapshots->buildSnapshot($tenant, $shift);

        return $this->serialize($shift) + ['snapshot' => $snapshot, 'cash' => ['expected' => $shift->expected_cash, 'actual' => $shift->closing_cash, 'reason' => $shift->cash_difference_reason, 'reasonDetail' => $shift->cash_difference_reason_detail ?? ''], 'closingNotes' => $shift->notes ?? '', 'closedAt' => $this->timestamp($shift->closed_at), 'closedBy' => $snapshot['identity']['closedBy'], 'reportNumber' => $shift->report_number];
    }

    private function serialize(object $shift): array
    {
        return ['id' => (int) $shift->id, 'shiftNumber' => $shift->shift_number, 'branchId' => (int) $shift->branch_id, 'userId' => (int) $shift->user_id, 'status' => $shift->status, 'openingCash' => (float) $shift->opening_cash, 'closingCash' => $shift->closing_cash === null ? null : (float) $shift->closing_cash, 'expectedCash' => (float) $shift->expected_cash, 'cashDifference' => (float) $shift->cash_difference, 'openedAt' => $this->timestamp($shift->opened_at), 'closedAt' => $this->timestamp($shift->closed_at)];
    }

    private function timestamp(?string $value): ?string
    {
        return $value === null ? null : CarbonImmutable::parse($value, 'UTC')->toIso8601String();
    }

    private function nextShiftNumber(int $tenant, string $date): string
    {
        $count = DB::table('shifts')->where('tenant_id', $tenant)->whereDate('opened_at', $date)->count() + 1;

        return sprintf('SH-%s-%03d', str_replace('-', '', $date), $count);
    }

    private function tenantExists(string $table, int $tenantId)
    {
        return Rule::exists($table, 'id')->where(fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at'));
    }
}
