<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class FactoryWarehouseScope
{
    public static function assertDestination(int $tenantId, ?int $branchId, ?int $warehouseId): void
    {
        if (! $branchId || ! $warehouseId) {
            return;
        }
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->first();
        if (($branch->branch_type ?? 'cafe') !== 'factory') {
            return;
        }
        if (! DB::table('warehouses')->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('id', $warehouseId)->where('is_active', true)->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages(['warehouseId' => 'العملية يجب أن تستخدم مخزناً نشطاً تابعاً للمعمل نفسه.']);
        }
    }
}
