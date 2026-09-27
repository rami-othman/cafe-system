<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class FactorySalesPolicy
{
    public static function assertLines(int $tenantId, int $branchId, iterable $lines): void
    {
        $factory = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->value('branch_type') === 'factory';
        foreach ($lines as $line) {
            $id = is_array($line) ? ($line['inventoryItemId'] ?? $line['inventory_item_id'] ?? null) : ($line->inventory_item_id ?? null);
            if ($id) {
                $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at')->first();
                if (! $item) throw ValidationException::withMessages(['lines' => 'المادة غير موجودة.']);
                InventoryItemScope::assertForBranch($tenantId, $item, $branchId);
            }
        }
        if (! $factory) return;
        $warehouse = app(\App\Services\FactoryInventoryWarehouseResolver::class)->forBranch($tenantId, $branchId);
        foreach ($lines as $line) {
            $itemId = is_array($line) ? ($line['inventoryItemId'] ?? $line['inventory_item_id'] ?? null) : ($line->inventory_item_id ?? null);
            if (! $itemId) {
                throw ValidationException::withMessages(['lines' => 'بيع المعمل يستخدم صنف المخزون الجاهز مباشرة. اختر المنتج من أصناف مخزن المعمل بدلاً من منتج قائمة المقهى.']);
            }
            app(\App\Domain\Inventory\InventoryWarehouseAssignment::class)->assertAssigned($tenantId, (int) $itemId, (int) $warehouse->id, 'lines');
        }
    }
}
