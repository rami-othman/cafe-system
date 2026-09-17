<?php

namespace App\Services;

use App\Exceptions\OrderLifecycleException;
use Illuminate\Support\Facades\DB;

final class PosInventoryWarehouseResolver
{
    public function forBranch(int $tenantId, int $branchId): object
    {
        return $this->resolutionForBranch($tenantId, $branchId)->warehouse;
    }

    /** @return object{warehouse:object,source:string} */
    public function resolutionForBranch(int $tenantId, int $branchId): object
    {
        $branch = DB::table('branches')->where('id', $branchId)->where('tenant_id', $tenantId)
            ->where('is_active', true)->whereNull('deleted_at')->first(['id', 'tenant_id', 'pos_inventory_warehouse_id']);

        if ($branch === null) {
            throw new OrderLifecycleException('POS_WAREHOUSE_NOT_CONFIGURED', 'لا يوجد مخزن تشغيلي صالح لنقطة البيع في هذا الفرع.');
        }

        if ($branch->pos_inventory_warehouse_id !== null) {
            $warehouse = $this->eligibleWarehouse($tenantId, $branchId, (int) $branch->pos_inventory_warehouse_id);
            if ($warehouse === null) {
                throw new OrderLifecycleException('POS_WAREHOUSE_INVALID', 'مخزن نقطة البيع المحدد غير صالح أو لا يتبع لهذا الفرع.');
            }

            return (object) ['warehouse' => $warehouse, 'source' => 'configured'];
        }

        $bars = $this->fallbackCandidates($tenantId, $branchId, 'bar');
        if ($bars->count() === 1) {
            return (object) ['warehouse' => $bars->first(), 'source' => 'bar_fallback'];
        }
        if ($bars->count() > 1) {
            throw new OrderLifecycleException('POS_WAREHOUSE_AMBIGUOUS', 'يوجد أكثر من مخزن بار لهذا الفرع. يرجى تحديد مخزن نقطة البيع من إعدادات الفرع.');
        }

        $mainStores = $this->fallbackCandidates($tenantId, $branchId, 'branch_main');
        if ($mainStores->count() === 1) {
            return (object) ['warehouse' => $mainStores->first(), 'source' => 'main_fallback'];
        }
        if ($mainStores->count() > 1) {
            throw new OrderLifecycleException('POS_WAREHOUSE_AMBIGUOUS', 'يوجد أكثر من مخزن رئيسي صالح لهذا الفرع. يرجى تحديد مخزن نقطة البيع من إعدادات الفرع.');
        }

        throw new OrderLifecycleException('POS_WAREHOUSE_NOT_CONFIGURED', 'لا يوجد مخزن تشغيلي صالح لنقطة البيع في هذا الفرع.');
    }

    /**
     * Never throws: a dashboard must render a configuration fault as an
     * operational alert instead of failing the whole read.
     *
     * @return array{id:int|null,row:object|null,ambiguous:bool}
     */
    public function resolveForDashboard(int $tenantId, int $branchId): array
    {
        try {
            $resolution = $this->resolutionForBranch($tenantId, $branchId);
        } catch (OrderLifecycleException $exception) {
            return ['id' => null, 'row' => null, 'ambiguous' => $exception->domainCode === 'POS_WAREHOUSE_AMBIGUOUS'];
        }

        return ['id' => (int) $resolution->warehouse->id, 'row' => $resolution->warehouse, 'ambiguous' => false];
    }

    public function assertEligible(int $tenantId, int $branchId, ?int $warehouseId): void
    {
        if ($warehouseId === null) {
            return;
        }
        if ($this->eligibleWarehouse($tenantId, $branchId, $warehouseId) === null) {
            throw new OrderLifecycleException('POS_WAREHOUSE_INVALID', 'مخزن نقطة البيع المحدد غير صالح أو لا يتبع لهذا الفرع.');
        }
    }

    private function eligibleWarehouse(int $tenantId, int $branchId, int $warehouseId): ?object
    {
        return DB::table('warehouses')->where('id', $warehouseId)->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)->whereIn('type', ['bar', 'branch_main'])->where('is_active', true)
            ->whereNull('deleted_at')->first();
    }

    private function fallbackCandidates(int $tenantId, int $branchId, string $type): \Illuminate\Support\Collection
    {
        return DB::table('warehouses')->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('type', $type)->where('is_active', true)->whereNull('deleted_at')->orderBy('id')->get();
    }
}
