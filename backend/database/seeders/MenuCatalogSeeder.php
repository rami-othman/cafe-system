<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class MenuCatalogSeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $now = now();

        $categoryIds = [];
        foreach (['Coffee', 'Tea', 'Cold Drinks', 'Desserts', 'Sandwiches', 'Add-ons'] as $sortOrder => $name) {
            $categoryIds[$name] = DB::table('categories')->insertGetId([
                'tenant_id' => $tenantId,
                'name' => $name,
                'sort_order' => $sortOrder,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        foreach ([
            ['name' => 'Espresso', 'category' => 'Coffee', 'price' => 3.50, 'description' => 'Rich single-origin espresso shot.'],
            ['name' => 'Cappuccino', 'category' => 'Coffee', 'price' => 4.50, 'description' => 'Classic espresso with steamed milk and micro-foam.'],
            ['name' => 'Pour Over V60', 'category' => 'Coffee', 'price' => 6.00, 'description' => 'Hand-poured filtered coffee.'],
            ['name' => 'Americano', 'category' => 'Coffee', 'price' => 3.75, 'description' => 'Espresso softened with hot water.'],
            ['name' => 'Iced Caramel Macchiato', 'category' => 'Cold Drinks', 'price' => 5.50, 'description' => 'Iced espresso, milk, vanilla, and caramel drizzle.'],
            ['name' => 'Cold Brew Reserve', 'category' => 'Cold Drinks', 'price' => 5.50, 'description' => 'Slow-steeped cold brew.', 'is_active' => false],
            ['name' => 'Almond Croissant', 'category' => 'Desserts', 'price' => 4.50, 'description' => 'Buttery croissant with almond filling.'],
            ['name' => 'Butter Croissant', 'category' => 'Desserts', 'price' => 3.50, 'description' => 'Classic flaky butter croissant.'],
            ['name' => 'Avocado Toast', 'category' => 'Sandwiches', 'price' => 9.00, 'description' => 'Sourdough toast with avocado and herbs.'],
        ] as $sortOrder => $product) {
            DB::table('products')->insert([
                'tenant_id' => $tenantId,
                'category_id' => $categoryIds[$product['category']],
                'name' => $product['name'],
                'description' => $product['description'],
                'price' => $product['price'],
                'is_active' => $product['is_active'] ?? true,
                'sort_order' => $sortOrder,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }
}
