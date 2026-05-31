<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $now = now();

        $tenantId = DB::table('tenants')->insertGetId([
            'name' => 'Cafe 6:18',
            'slug' => 'cafe-618',
            'status' => 'active',
            'plan' => 'starter',
            'currency' => 'SYP',
            'timezone' => 'Asia/Damascus',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $branchId = DB::table('branches')->insertGetId([
            'tenant_id' => $tenantId,
            'name' => 'Main Branch',
            'currency' => 'SYP',
            'timezone' => 'Asia/Damascus',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $ownerId = DB::table('users')->insertGetId([
            'tenant_id' => $tenantId,
            'name' => 'Cafe Owner',
            'email' => 'owner@cafe618.local',
            'password' => Hash::make('password'),
            'role' => 'owner',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $cashierId = DB::table('users')->insertGetId([
            'tenant_id' => $tenantId,
            'name' => 'Cashier User',
            'email' => 'cashier@cafe618.local',
            'password' => Hash::make('password'),
            'role' => 'cashier',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('user_branches')->insert([
            [
                'tenant_id' => $tenantId,
                'user_id' => $ownerId,
                'branch_id' => $branchId,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'tenant_id' => $tenantId,
                'user_id' => $cashierId,
                'branch_id' => $branchId,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ]);

        $categoryIds = [];
        foreach (['Hot Drinks', 'Cold Drinks', 'Desserts', 'Food'] as $sortOrder => $name) {
            $categoryIds[$name] = DB::table('categories')->insertGetId([
                'tenant_id' => $tenantId,
                'name' => $name,
                'sort_order' => $sortOrder,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        foreach ([
            ['name' => 'Espresso', 'category' => 'Hot Drinks', 'price' => 15000],
            ['name' => 'Cappuccino', 'category' => 'Hot Drinks', 'price' => 20000],
            ['name' => 'Latte', 'category' => 'Hot Drinks', 'price' => 22000],
            ['name' => 'Iced Coffee', 'category' => 'Cold Drinks', 'price' => 25000],
            ['name' => 'Cheesecake', 'category' => 'Desserts', 'price' => 30000],
        ] as $product) {
            DB::table('products')->insert([
                'tenant_id' => $tenantId,
                'category_id' => $categoryIds[$product['category']],
                'name' => $product['name'],
                'price' => $product['price'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        foreach (range(1, 4) as $number) {
            DB::table('cafe_tables')->insert([
                'tenant_id' => $tenantId,
                'branch_id' => $branchId,
                'name' => "Table {$number}",
                'code' => "T{$number}",
                'sort_order' => $number,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        DB::table('warehouses')->insert([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'name' => 'Main Warehouse',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        foreach ([
            ['name' => 'Coffee Beans', 'unit' => 'kilogram'],
            ['name' => 'Milk', 'unit' => 'liter'],
            ['name' => 'Sugar', 'unit' => 'kilogram'],
            ['name' => 'Cups', 'unit' => 'piece'],
        ] as $item) {
            DB::table('inventory_items')->insert([
                'tenant_id' => $tenantId,
                'name' => $item['name'],
                'unit' => $item['unit'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        DB::table('discounts')->insert([
            'tenant_id' => $tenantId,
            'name' => 'Opening Discount',
            'code' => 'OPEN10',
            'type' => 'percentage',
            'value' => 10,
            'scope' => 'order',
            'is_active' => true,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }
}
