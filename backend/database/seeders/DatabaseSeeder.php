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
        ]);

        // Connected operational scenarios are development data only. They
        // use production posting flows and stable idempotency keys; the old
        // PosDemoSeeder wrote payments/refunds directly and is intentionally
        // not part of the runnable demo command.
        // Test cases opt into these richer scenarios explicitly.  Keeping the
        // base test seed deterministic prevents operational demo totals from
        // leaking into unrelated report assertions.
        if (app()->environment(['local', 'development'])) {
            $this->call(FinanceOperationsDemoSeeder::class);
            $this->call(Cafe618InventoryOperationsDemoSeeder::class);
            $this->call(Cafe618PosSalesDemoSeeder::class);
            $this->call(Cafe618FinanceOperationsDemoSeeder::class);
        }
    }
}
