<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ProductModifierSeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $now = now();

        $groups = [
            'temperature' => [
                'name' => 'Temperature',
                'selection_type' => 'single',
                'is_required' => true,
                'min_selections' => 1,
                'max_selections' => 1,
                'options' => [
                    ['name' => 'Hot', 'price_delta' => 0, 'is_default' => true],
                    ['name' => 'Iced', 'price_delta' => 0, 'is_default' => false],
                ],
            ],
            'size' => [
                'name' => 'Size',
                'selection_type' => 'single',
                'is_required' => true,
                'min_selections' => 1,
                'max_selections' => 1,
                'options' => [
                    ['name' => 'Small (8oz)', 'price_delta' => -0.50, 'is_default' => false],
                    ['name' => 'Medium (12oz)', 'price_delta' => 0, 'is_default' => true],
                    ['name' => 'Large (16oz)', 'price_delta' => 0.75, 'is_default' => false],
                ],
            ],
            'milk_base' => [
                'name' => 'Milk Base',
                'selection_type' => 'single',
                'is_required' => false,
                'min_selections' => 0,
                'max_selections' => 1,
                'options' => [
                    ['name' => 'Whole Milk', 'price_delta' => 0, 'is_default' => true],
                    ['name' => 'Oat Milk', 'price_delta' => 0.75, 'is_default' => false],
                    ['name' => 'Almond Milk', 'price_delta' => 0.75, 'is_default' => false],
                ],
            ],
            'add_ons' => [
                'name' => 'Add-ons',
                'selection_type' => 'multiple',
                'is_required' => false,
                'min_selections' => 0,
                'max_selections' => 5,
                'options' => [
                    ['name' => 'Extra Espresso Shot', 'price_delta' => 1.00, 'is_default' => false],
                    ['name' => 'Vanilla Syrup', 'price_delta' => 0.50, 'is_default' => false],
                    ['name' => 'Caramel Drizzle', 'price_delta' => 0.50, 'is_default' => false],
                ],
            ],
        ];

        $groupIds = [];
        foreach ($groups as $code => $group) {
            DB::table('modifier_groups')->updateOrInsert([
                'tenant_id' => $tenantId,
                'code' => $code,
            ], [
                'name' => $group['name'],
                'selection_type' => $group['selection_type'],
                'is_required' => $group['is_required'],
                'min_selections' => $group['min_selections'],
                'max_selections' => $group['max_selections'],
                'sort_order' => count($groupIds),
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $groupIds[$code] = (int) DB::table('modifier_groups')
                ->where('tenant_id', $tenantId)
                ->where('code', $code)
                ->value('id');

            foreach ($group['options'] as $sortOrder => $option) {
                DB::table('modifier_options')->updateOrInsert([
                    'tenant_id' => $tenantId,
                    'modifier_group_id' => $groupIds[$code],
                    'name' => $option['name'],
                ], [
                    'price_delta' => $option['price_delta'],
                    'is_default' => $option['is_default'],
                    'sort_order' => $sortOrder,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        foreach (['Cappuccino', 'Espresso', 'Americano', 'Pour Over V60', 'Iced Caramel Macchiato'] as $productName) {
            $productId = (int) DB::table('products')->where('tenant_id', $tenantId)->where('name', $productName)->value('id');

            foreach (array_values($groupIds) as $sortOrder => $groupId) {
                DB::table('product_modifier_group')->updateOrInsert([
                    'tenant_id' => $tenantId,
                    'product_id' => $productId,
                    'modifier_group_id' => $groupId,
                ], [
                    'sort_order' => $sortOrder,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }
}
