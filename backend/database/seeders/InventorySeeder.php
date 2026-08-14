<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class InventorySeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('email', 'manager@cafe618.local')->value('id');
        $now = now();

        $warehouseId = DB::table('warehouses')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'name' => 'Main Warehouse',
            'type' => 'main',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        foreach ([
            ['name' => 'Coffee Beans', 'sku' => 'INV-COFFEE-BEANS', 'unit' => 'kilogram', 'stock' => 24.500, 'minimum' => 5.000, 'cost' => 9.50],
            ['name' => 'Regular Milk', 'sku' => 'INV-REGULAR-MILK', 'unit' => 'liter', 'stock' => 42.000, 'minimum' => 8.000, 'cost' => 1.25],
            ['name' => 'Oat Milk', 'sku' => 'INV-OAT-MILK', 'unit' => 'liter', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 1.80],
            ['name' => 'Almond Milk', 'sku' => 'INV-ALMOND-MILK', 'unit' => 'liter', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 1.90],
            ['name' => 'Sugar', 'sku' => 'INV-SUGAR', 'unit' => 'kilogram', 'stock' => 18.000, 'minimum' => 4.000, 'cost' => 0.80],
            ['name' => 'Vanilla Syrup', 'sku' => 'INV-VANILLA-SYRUP', 'unit' => 'liter', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 0],
            ['name' => 'Chocolate Syrup', 'sku' => 'INV-CHOCOLATE-SYRUP', 'unit' => 'liter', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 0],
            ['name' => 'Small Cup', 'sku' => 'INV-SMALL-CUP', 'unit' => 'piece', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 0.06],
            ['name' => 'Medium Cup', 'sku' => 'INV-MEDIUM-CUP', 'unit' => 'piece', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 0.06],
            ['name' => 'Large Cup', 'sku' => 'INV-LARGE-CUP', 'unit' => 'piece', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 0.06],
            ['name' => 'Small Lid', 'sku' => 'INV-SMALL-LID', 'unit' => 'piece', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 0.02],
            ['name' => 'Medium Lid', 'sku' => 'INV-MEDIUM-LID', 'unit' => 'piece', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 0.02],
            ['name' => 'Large Lid', 'sku' => 'INV-LARGE-LID', 'unit' => 'piece', 'stock' => 0.000, 'minimum' => 0.000, 'cost' => 0.02],
            ['name' => 'Croissants', 'sku' => 'INV-CROISSANTS', 'unit' => 'piece', 'stock' => 12.000, 'minimum' => 10.000, 'cost' => 1.10],
        ] as $item) {
            DB::table('inventory_items')->updateOrInsert(['tenant_id' => $tenantId, 'sku' => $item['sku']], [
                'tenant_id' => $tenantId,
                'name' => $item['name'],
                'sku' => $item['sku'],
                'unit' => $item['unit'],
                'current_stock' => $item['stock'],
                'minimum_stock' => $item['minimum'],
                'cost_per_unit' => $item['cost'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $itemId = (int) DB::table('inventory_items')->where('tenant_id', $tenantId)->where('sku', $item['sku'])->value('id');

            if ($item['stock'] <= 0) {
                continue;
            }
            DB::table('stock_movements')->updateOrInsert(['tenant_id' => $tenantId, 'inventory_item_id' => $itemId, 'type' => 'opening_balance'], [
                'tenant_id' => $tenantId,
                'branch_id' => $branchId,
                'warehouse_id' => $warehouseId,
                'inventory_item_id' => $itemId,
                'type' => 'opening_balance',
                'quantity' => $item['stock'],
                'unit_cost' => $item['cost'],
                'total_cost' => round($item['stock'] * $item['cost'], 2),
                'reason' => 'Demo opening stock',
                'created_by' => $userId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }
}
