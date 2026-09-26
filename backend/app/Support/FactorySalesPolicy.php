<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class FactorySalesPolicy
{
    public static function assertLines(int $tenantId, int $branchId, iterable $lines): void
    {
        if (DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->value('branch_type') !== 'factory') {
            return;
        }
        $warehouse = app(\App\Services\PosInventoryWarehouseResolver::class)->forBranch($tenantId, $branchId);
        foreach ($lines as $line) {
            $itemId = is_array($line) ? ($line['inventoryItemId'] ?? $line['inventory_item_id'] ?? null) : ($line->inventory_item_id ?? null);
            if (! $itemId) {
                throw ValidationException::withMessages(['lines' => 'بيع المعمل يستخدم صنف المخزون الجاهز مباشرة. اختر المنتج من أصناف مخزن المعمل بدلاً من منتج قائمة المقهى.']);
            }
            app(\App\Domain\Inventory\InventoryWarehouseAssignment::class)->assertAssigned($tenantId, (int) $itemId, (int) $warehouse->id, 'lines');
        }
    }
}
