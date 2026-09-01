<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Support\TenantContext;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ShiftController extends Controller
{
    public function current(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $request->validate([
            'branchId' => ['nullable', 'integer', $this->tenantExists('branches', $tenantId)],
        ]);
        $branchId = (int) $request->query('branchId');

        $shift = DB::table('shifts')
            ->where('tenant_id', $tenantId)
            ->whereIn('branch_id', app(BranchAccessService::class)->accessibleBranchIds($request->attributes->get('auth_user')))
            ->when($branchId > 0, fn ($query) => $query->where('branch_id', $branchId))
            ->where('status', 'open')
            ->whereNull('deleted_at')
            ->latest('opened_at')
            ->first();

        return response()->json(['data' => $shift ? $this->serialize($shift) : null]);
    }

    public function open(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validate([
            'branchId' => ['required', 'integer', $this->tenantExists('branches', $tenantId)],
            'userId' => ['prohibited'],
            'openingCash' => ['required', 'numeric', 'min:0'],
        ]);

        $now = now();

        $id = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $data['branchId'],
            'user_id' => $request->attributes->get('auth_user')->id,
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
        app(BranchAccessService::class)->authorizeRequestBranch($request, (int) $row->branch_id);

        $cashPayments = (float) DB::table('payments')
            ->where('tenant_id', $tenantId)
            ->where('shift_id', $shift)
            ->where('method', 'cash')
            ->where('status', 'completed')
            ->whereNull('deleted_at')
            ->sum('amount');

        $expectedCash = (float) $row->opening_cash + $cashPayments;
        $cashDifference = round((float) $data['closingCash'] - $expectedCash, 2);

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

    private function tenantExists(string $table, int $tenantId)
    {
        return Rule::exists($table, 'id')->where(
            fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at'),
        );
    }
}
