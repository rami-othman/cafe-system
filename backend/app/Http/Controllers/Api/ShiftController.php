<?php

namespace App\Http\Controllers\Api;

use App\Domain\Inventory\BarCheckTemplateService;
use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\ShiftCloseService;
use App\Services\ShiftDrawerReadinessService;
use App\Services\ShiftHistoryQueryService;
use App\Services\ShiftSnapshotService;
use App\Services\StockCountService;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\ShiftClosePresentation;
use App\Support\TenantContext;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/** The authenticated operator's shift lifecycle and its canonical read models. */
class ShiftController extends Controller
{
    private const DIFFERENCE_REASONS = ['change_error', 'unrecorded_transaction', 'unrecorded_withdrawal', 'unrecorded_expense', 'unknown_surplus', 'unknown_shortage', 'other'];

    public function __construct(
        private readonly BarCheckTemplateService $barCheckTemplates,
        private readonly ShiftCloseService $closer,
        private readonly ShiftDrawerReadinessService $readiness,
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

    /** Drawer/close configuration readiness for opening a shift on a branch. */
    public function readiness(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validate(['branchId' => ['required', 'integer', $this->tenantExists('branches', $tenantId)]]);
        $this->branches->authorizeRequestBranch($request, (int) $data['branchId']);

        return response()->json(['data' => $this->readiness->payload($tenantId, (int) $data['branchId'])]);
    }

    /**
     * Opens a shift on the branch's physical POS drawer.
     *
     * Invariant: one open (live) shift per tenant + financial_location_id. The
     * branch and drawer rows are locked (not the tenant row), so opens on the
     * same drawer serialize while other drawers proceed in parallel; the
     * partial unique index shifts_one_open_per_location is the final guarantee
     * and its violation is reported as the same friendly validation error.
     */
    public function open(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validate(['branchId' => ['required', 'integer', $this->tenantExists('branches', $tenantId)], 'userId' => ['prohibited'], 'openingCash' => ['required', 'numeric', 'min:0'], 'note' => ['nullable', 'string', 'max:4000']]);
        $this->branches->authorizeRequestBranch($request, (int) $data['branchId']);
        $actor = $request->attributes->get('auth_user');
        try {
            $shift = DB::transaction(function () use ($tenantId, $data, $actor): object {
                // Locks the branch (configuration) row, then only the drawer location row.
                $config = $this->readiness->assertReady($tenantId, (int) $data['branchId'], true);
                $drawer = $config['drawer'];
                if ($this->readiness->openShiftOnDrawer($tenantId, (int) $drawer->id)) {
                    throw ValidationException::withMessages(['branchId' => __('shifts.drawer_has_open_shift')]);
                }
                $ledgerCash = $this->readiness->drawerLedgerBalance($tenantId, $drawer);
                if (Money::cents($data['openingCash'], 'openingCash') !== Money::cents($ledgerCash)) {
                    throw ValidationException::withMessages(['openingCash' => __('shifts.opening_cash_mismatch', ['ledger' => $ledgerCash])]);
                }
                $this->closer->lockShiftNumbering($tenantId);
                $now = now();
                // Snapshot the close configuration: later branch edits never mutate an open shift.
                $id = DB::table('shifts')->insertGetId(['tenant_id' => $tenantId, 'branch_id' => $data['branchId'], 'user_id' => $actor->id, 'financial_location_id' => $drawer->id, 'close_destination_financial_location_id' => $config['destination']->id, 'closing_float_amount' => $config['closingFloat'], 'shift_number' => $this->closer->nextShiftNumber($tenantId, $now->toDateString()), 'opening_cash' => $data['openingCash'], 'status' => 'open', 'opened_at' => $now, 'notes' => $data['note'] ?? null, 'created_at' => $now, 'updated_at' => $now]);

                return DB::table('shifts')->where('id', $id)->first();
            });
        } catch (QueryException $exception) {
            if (self::isOpenShiftUniqueViolation($exception)) {
                throw ValidationException::withMessages(['branchId' => __('shifts.drawer_has_open_shift')]);
            }
            throw $exception;
        }

        return response()->json(['data' => $this->serialize($shift)], 201);
    }

    public static function isOpenShiftUniqueViolation(QueryException $exception): bool
    {
        $state = $exception->errorInfo[0] ?? $exception->getCode();

        return (string) $state === '23505' && str_contains($exception->getMessage(), 'shifts_one_open_per_location');
    }

    /**
     * Canonical manual close: lock -> tenant/branch/owner authorization -> open
     * -> required bar checks -> ShiftCashSummary -> counted == expected ->
     * drawer + destination validation -> counted == drawer ledger -> one
     * transfer (counted - float, key shift-close-transfer:{id}) -> closed, all
     * in one transaction. Retrying an identical close returns the same result.
     */
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
            $row = $this->closer->lock($tenantId, $shift);
            abort_if(! $row, 404, __('shifts.shift_not_found'));
            $this->branches->authorizeRequestBranch($request, (int) $row->branch_id);
            abort_unless((int) $row->user_id === (int) $actor->id, 403, __('shifts.only_owner_can_close'));
            if ($row->status === 'closed' && $row->close_type === ShiftCloseService::TYPE_MANUAL
                && Money::cents($row->closing_cash) === Money::cents($data['closingCash'], 'closingCash')) {
                return $row;
            }
            if ($row->status !== 'open') {
                throw ValidationException::withMessages(['shift' => __('shifts.shift_not_open')]);
            }
            $this->submitRequiredBarCounts($request, $tenantId, $row, $data['barCountLines'] ?? [], FinancialActor::id($request, $tenantId));

            return $this->closer->close($request, $tenantId, $row, ShiftCloseService::TYPE_MANUAL, (string) $data['closingCash'], [
                'cash_difference_reason' => $data['cashDifferenceReason'] ?? null,
                'cash_difference_reason_detail' => $data['cashDifferenceReasonDetail'] ?? null,
                'notes' => $data['note'] ?? $row->notes,
            ]);
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
            if (DB::table('stock_counts')->where('tenant_id', $tenant)->where('shift_id', $shift->id)
                ->where('bar_check_template_id', $template->id)->where('status', 'posted')->exists()) {
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

    /** @return array<string, mixed> */
    private function closingPayload(int $tenant, object $shift): array
    {
        $snapshot = $this->snapshots->buildSnapshot($tenant, $shift);
        $presentation = ShiftClosePresentation::for($shift);

        return $this->serialize($shift) + ['snapshot' => $snapshot, 'cash' => ['expected' => $presentation['expectedCash'], 'actual' => $shift->closing_cash, 'difference' => $presentation['cashDifference'], 'counted' => $presentation['cashCounted'], 'reason' => $shift->cash_difference_reason, 'reasonDetail' => $shift->cash_difference_reason_detail ?? ''], 'closingNotes' => $shift->notes ?? '', 'closedAt' => $this->timestamp($shift->closed_at), 'closedBy' => in_array($shift->close_type, [ShiftCloseService::TYPE_AUTOMATIC, ShiftCloseService::TYPE_LEGACY_RECONCILE], true) ? 'System' : $snapshot['identity']['closedBy'], 'reportNumber' => $shift->report_number];
    }

    private function serialize(object $shift): array
    {
        $presentation = ShiftClosePresentation::for($shift);

        return ['id' => (int) $shift->id, 'shiftNumber' => $shift->shift_number, 'branchId' => (int) $shift->branch_id, 'userId' => (int) $shift->user_id, 'status' => $shift->status, 'closeType' => $shift->close_type, 'closeMode' => $presentation['closeMode'], 'cashCounted' => $presentation['cashCounted'], 'administrativeClose' => $presentation['administrativeClose'], 'financialLocationId' => $shift->financial_location_id, 'closeDestinationFinancialLocationId' => $shift->close_destination_financial_location_id, 'closingFloatAmount' => $shift->closing_float_amount, 'closeTransferId' => $shift->close_transfer_id, 'openingCash' => (float) $shift->opening_cash, 'closingCash' => $shift->closing_cash === null ? null : (float) $shift->closing_cash, 'expectedCash' => $presentation['expectedCash'] === null ? null : (float) $presentation['expectedCash'], 'cashDifference' => $presentation['cashDifference'] === null ? null : (float) $presentation['cashDifference'], 'openedAt' => $this->timestamp($shift->opened_at), 'closedAt' => $this->timestamp($shift->closed_at)];
    }

    private function timestamp(?string $value): ?string
    {
        return $value === null ? null : CarbonImmutable::parse($value, 'UTC')->toIso8601String();
    }

    private function tenantExists(string $table, int $tenantId)
    {
        return Rule::exists($table, 'id')->where(fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at'));
    }
}
