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

        // The connected Finance scenario is development data only. It uses
        // the same posting services as the application, so it is kept after
        // the core catalog and POS seeders it depends on.
        if (app()->environment(['local', 'development', 'testing'])) {
            $this->call(FinanceOperationsDemoSeeder::class);
        }
    }
}
