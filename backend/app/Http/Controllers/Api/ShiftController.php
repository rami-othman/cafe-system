<?php

namespace App\Http\Controllers\Api;

use App\Domain\Inventory\BarCheckTemplateService;
use App\Http\Controllers\Controller;
use App\Services\ShiftCashSummaryService;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ShiftController extends Controller
{
    public function __construct(private readonly BarCheckTemplateService $barCheckTemplates, private readonly ShiftCashSummaryService $cashSummary) {}
    public function current(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $branchId = (int) $request->query('branchId');

        $shift = DB::table('shifts')
            ->where('tenant_id', $tenantId)
            ->when($branchId > 0, fn ($query) => $query->where('branch_id', $branchId))
            ->where('status', 'open')
            ->whereNull('deleted_at')
            ->latest('opened_at')
            ->first();

        return response()->json(['data' => $shift ? $this->serialize($shift) : null]);
    }

    public function open(Request $request): JsonResponse
    {
        $data = $request->validate([
            'branchId' => ['required', 'integer', 'exists:branches,id'],
            'userId' => ['nullable', 'integer', 'exists:users,id'],
            'openingCash' => ['required', 'numeric', 'min:0'],
        ]);

        $tenantId = TenantContext::id($request);
        $now = now();

        $id = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $data['branchId'],
            'user_id' => $data['userId'] ?? (int) DB::table('users')->where('tenant_id', $tenantId)->orderBy('id')->value('id'),
            'opening_cash' => $data['openingCash'],
            'status' => 'open',
            'opened_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $shift = DB::table('shifts')->where('id', $id)->first();

        return response()->json(['data' => $this->serialize($shift)], 201);
    }

    public function close(Request $request, int $shift): JsonResponse
    {
        $data = $request->validate([
            'closingCash' => ['required', 'numeric', 'min:0'],
            'note' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $row = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shift)->whereNull('deleted_at')->first();
        abort_if(! $row, 404, 'Shift not found.');

        $requiredTemplates = DB::table('bar_check_templates')->where('tenant_id', $tenantId)->where('branch_id', $row->branch_id)->where('is_active', true)->where('required_for_shift_close', true)->get();
        $barCheckPending = $requiredTemplates->contains(function (object $template) use ($tenantId, $row): bool {
            if (! $this->barCheckTemplates->isUsable($tenantId, $template)) return false;
            return ! DB::table('stock_counts')->where('tenant_id', $tenantId)->where('shift_id', $row->id)
                ->where('bar_check_template_id', $template->id)->where('warehouse_id', $template->warehouse_id)
                ->where('branch_id', $template->branch_id)->where('count_type', 'shift_check')->where('status', 'posted')->exists();
        });
        if ($barCheckPending) {
            abort(422, 'يجب إكمال فحص البار قبل إغلاق الشيفت.');
        }

        $summary = $this->cashSummary->summarize($tenantId, $row);
        $expectedCash = $summary['expectedCash'];
        $closingCashCents = Money::cents($data['closingCash']);
        $cashDifference = Money::decimal($closingCashCents - Money::cents($expectedCash));

        DB::table('shifts')->where('id', $shift)->update([
            'closing_cash' => $data['closingCash'],
            'expected_cash' => $expectedCash,
            'cash_difference' => $cashDifference,
            'status' => 'closed',
            'closed_at' => now(),
            'notes' => $data['note'] ?? $row->notes,
            'updated_at' => now(),
        ]);

        return response()->json(['data' => $this->serialize(DB::table('shifts')->where('id', $shift)->first())]);
    }

    private function serialize(object $shift): array
    {
        return [
            'id' => $shift->id,
            'branchId' => $shift->branch_id,
            'userId' => $shift->user_id,
            'status' => $shift->status,
            'openingCash' => (float) $shift->opening_cash,
            'closingCash' => $shift->closing_cash === null ? null : (float) $shift->closing_cash,
            'expectedCash' => (float) $shift->expected_cash,
            'cashDifference' => (float) $shift->cash_difference,
            'openedAt' => $shift->opened_at,
            'closedAt' => $shift->closed_at,
        ];
    }
}
