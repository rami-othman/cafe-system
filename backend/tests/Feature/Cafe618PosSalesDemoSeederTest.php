<?php

namespace Tests\Feature;

use Database\Seeders\Cafe618InventoryOperationsDemoSeeder;
use Database\Seeders\Cafe618PosSalesDemoSeeder;
use Database\Seeders\FinancialInventoryFoundationSeeder;
use Database\Seeders\InventoryCenterSeeder;
use Database\Seeders\SuperAdminSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class Cafe618PosSalesDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_idempotent_paid_sales_with_real_inventory_consumption_cogs_and_refunds(): void
    {
        $this->travelTo('2026-09-06 12:00:00');
        try {
            $this->seed(SuperAdminSeeder::class);
            $this->seed(TenantAccessSeeder::class);
            $this->seed(FinancialInventoryFoundationSeeder::class);
            $this->seed(InventoryCenterSeeder::class);
            $this->seed(Cafe618InventoryOperationsDemoSeeder::class);
            $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
            $main = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('type', 'branch_main')->orderBy('id')->value('id');
            foreach (['INV-BEANS', 'INV-MILK-FRESH', 'INV-CUP-12OZ', 'INV-VANILLA', 'INV-CARAMEL'] as $sku) {
                $item = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', $sku)->value('id');
                $this->assertGreaterThan(0, (float) DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $main)->where('inventory_item_id', $item)->value('quantity_on_hand'), $sku.' must be available at the POS source warehouse.');
            }
            $this->seed(Cafe618PosSalesDemoSeeder::class);

            $this->assertGreaterThanOrEqual(22, DB::table('orders')->where('tenant_id', $tenant)->where('idempotency_key', 'like', 'cafe-618-pos-20260906-%')->count());
            $this->assertGreaterThanOrEqual(22, DB::table('payments')->where('tenant_id', $tenant)->where('idempotency_key', 'like', 'cafe-618-pos-20260906-%')->count());
            $this->assertGreaterThan(0, DB::table('sale_consumptions')->where('tenant_id', $tenant)->count());
            $this->assertGreaterThan(0, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->count());
            $this->assertGreaterThan(0, DB::table('orders')->where('tenant_id', $tenant)->where('cogs_total', '>', 0)->count());
            $this->assertGreaterThanOrEqual(2, DB::table('payment_refunds')->where('tenant_id', $tenant)->count());
            $this->assertGreaterThan(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_event', 'POS_ORDER_PAID')->count());

            $before = collect(['orders', 'payments', 'payment_refunds', 'sale_consumptions', 'stock_movements', 'journal_entries'])
                ->mapWithKeys(fn (string $table) => [$table => DB::table($table)->where('tenant_id', $tenant)->count()])
                ->all();
            $this->seed(Cafe618PosSalesDemoSeeder::class);
            foreach ($before as $table => $count) {
                $this->assertSame($count, DB::table($table)->where('tenant_id', $tenant)->count(), $table.' must not duplicate on a same-day rerun.');
            }
        } finally {
            $this->travelBack();
        }
    }
}
