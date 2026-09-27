<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class FactoryWarehouseScope
{
    public static function assertDestination(int $tenantId, ?int $branchId, ?int $warehouseId): void
    {
        self::assertWarehouseForBranch($tenantId, $branchId, $warehouseId);
    }

    public static function assertFactoryBranch(int $tenantId, ?int $branchId): void
    {
        if (! $branchId || DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->value('branch_type') !== 'factory') {
            throw ValidationException::withMessages(['branchId' => 'التصنيع متاح في فروع المعمل فقط.']);
        }
    }

    public static function assertWarehouseForBranch(int $tenantId, ?int $branchId, ?int $warehouseId): void
    {
        if (! $warehouseId) throw ValidationException::withMessages(['warehouseId' => 'المخزن مطلوب.']);
        $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $warehouse) throw ValidationException::withMessages(['warehouseId' => 'المخزن غير متاح.']);
        $branchId ??= $warehouse->branch_id ? (int) $warehouse->branch_id : null;
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->first();
        $warehouseFactory = $warehouse->branch_id && DB::table('branches')->where('tenant_id', $tenantId)->where('id', $warehouse->branch_id)->value('branch_type') === 'factory';
        if (($warehouseFactory || ($branch->branch_type ?? 'cafe') === 'factory') && (int) $warehouse->branch_id !== (int) $branchId) {
            throw ValidationException::withMessages(['warehouseId' => 'العملية يجب أن تستخدم مخزناً نشطاً تابعاً للمعمل نفسه.']);
        }
    }
}
