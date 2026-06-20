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
            ['name' => 'Milk', 'sku' => 'INV-MILK', 'unit' => 'liter', 'stock' => 42.000, 'minimum' => 8.000, 'cost' => 1.25],
            ['name' => 'Sugar', 'sku' => 'INV-SUGAR', 'unit' => 'kilogram', 'stock' => 18.000, 'minimum' => 4.000, 'cost' => 0.80],
            ['name' => 'Cups', 'sku' => 'INV-CUPS', 'unit' => 'piece', 'stock' => 350.000, 'minimum' => 100.000, 'cost' => 0.06],
            ['name' => 'Croissants', 'sku' => 'INV-CROISSANTS', 'unit' => 'piece', 'stock' => 12.000, 'minimum' => 10.000, 'cost' => 1.10],
        ] as $item) {
            $itemId = DB::table('inventory_items')->insertGetId([
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

            DB::table('stock_movements')->insert([
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
