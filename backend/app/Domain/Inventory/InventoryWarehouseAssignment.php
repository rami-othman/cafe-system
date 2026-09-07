<?php

namespace App\Domain\Inventory;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

final class InventoryWarehouseAssignment
{
    public function assertAssigned(int $tenantId, int $itemId, int $warehouseId, string $field = 'warehouseId'): void
    {
        if (! Schema::hasTable('inventory_item_warehouses')) {
            return;
        }

        if (! DB::table('inventory_item_warehouses')->where('tenant_id', $tenantId)->where('inventory_item_id', $itemId)->where('warehouse_id', $warehouseId)->exists()) {
            throw ValidationException::withMessages([$field => 'The inventory item is not assigned to the selected warehouse.']);
        }
    }
}
