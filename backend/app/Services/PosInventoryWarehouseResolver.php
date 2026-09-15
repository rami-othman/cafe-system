<?php

namespace App\Services;

use App\Exceptions\OrderLifecycleException;
use Illuminate\Support\Facades\DB;

final class PosInventoryWarehouseResolver
{
    public function forBranch(int $tenantId, int $branchId): object
    {
        $warehouse = DB::table('branches as b')
            ->join('warehouses as w', 'w.id', '=', 'b.pos_inventory_warehouse_id')
            ->where('b.id', $branchId)->where('b.tenant_id', $tenantId)
            ->where('b.is_active', true)->whereNull('b.deleted_at')
            ->whereColumn('w.tenant_id', 'b.tenant_id')->whereColumn('w.branch_id', 'b.id')
            ->where('w.type', 'bar')->where('w.is_active', true)->whereNull('w.deleted_at')
            ->select('w.*')->first();

        if ($warehouse === null) {
            throw new OrderLifecycleException('POS_WAREHOUSE_NOT_CONFIGURED', 'لم يتم تحديد مخزن البار لهذا الفرع. يرجى ضبط مخزن نقطة البيع من إعدادات الفرع.');
        }

        return $warehouse;
    }

    public function assertEligible(int $tenantId, int $branchId, ?int $warehouseId): void
    {
        if ($warehouseId === null) {
            return;
        }
        $valid = DB::table('warehouses')->where('id', $warehouseId)->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)->where('type', 'bar')->where('is_active', true)
            ->whereNull('deleted_at')->exists();
        if (! $valid) {
            throw new OrderLifecycleException('POS_WAREHOUSE_INVALID', 'The POS inventory warehouse must be an active Bar warehouse belonging to this branch.');
        }
    }
}
