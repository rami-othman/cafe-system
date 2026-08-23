<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            SuperAdminSeeder::class,
            TenantAccessSeeder::class,
            FinancialInventoryFoundationSeeder::class,
            MenuCatalogSeeder::class,
            ProductModifierSeeder::class,
            CustomerAndTableSeeder::class,
            InventorySeeder::class,
            DiscountSeeder::class,
            LoyaltySeeder::class,
            PosDemoSeeder::class,
        ]);
    }
}
