<?php

namespace Tests\Feature;

use Database\Seeders\Cafe618InventoryOperationsDemoSeeder;
use Database\Seeders\FinancialInventoryFoundationSeeder;
use Database\Seeders\InventoryCenterSeeder;
use Database\Seeders\SuperAdminSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class Cafe618InventoryOperationsDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_seeds_operational_inventory_history_for_cafe_618_idempotently(): void
    {
        $this->travelTo('2026-09-06 12:00:00');
        try {
            $this->seed(SuperAdminSeeder::class);
            $this->seed(TenantAccessSeeder::class);
            $this->seed(FinancialInventoryFoundationSeeder::class);
            $this->seed(InventoryCenterSeeder::class);
            $this->seed(Cafe618InventoryOperationsDemoSeeder::class);

            $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
            $this->assertGreaterThanOrEqual(4, DB::table('warehouses')->where('tenant_id', $tenant)->where('is_active', true)->count());
            $this->assertGreaterThanOrEqual(4, DB::table('stock_movements')->where('tenant_id', $tenant)->whereIn('type', ['waste', 'stock_count_variance'])->count());
            $this->assertGreaterThanOrEqual(3, DB::table('stock_counts')->where('tenant_id', $tenant)->where('count_type', 'full')->where('status', 'posted')->count());
            $this->assertGreaterThanOrEqual(3, DB::table('stock_counts')->where('tenant_id', $tenant)->where('count_type', 'shift_check')->count());
            $this->assertDatabaseHas('warehouse_transfers', ['tenant_id' => $tenant, 'status' => 'received']);
            $this->assertDatabaseHas('warehouse_transfers', ['tenant_id' => $tenant, 'status' => 'partially_received']);
            $this->assertDatabaseHas('warehouse_transfers', ['tenant_id' => $tenant, 'status' => 'cancelled']);
            $this->assertGreaterThan(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'inventory_movement')->count());

            $before = collect(['stock_movements', 'stock_counts', 'warehouse_transfers', 'warehouse_transfer_receipts', 'journal_entries'])
                ->mapWithKeys(fn (string $table) => [$table => DB::table($table)->where('tenant_id', $tenant)->count()])
                ->all();

            $this->seed(Cafe618InventoryOperationsDemoSeeder::class);

            foreach ($before as $table => $count) {
                $this->assertSame($count, DB::table($table)->where('tenant_id', $tenant)->count(), $table.' must not duplicate on a same-day rerun.');
            }
            $this->assertSame(0, DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')->where('entries.tenant_id', $tenant)->where('entries.status', 'posted')->select('entries.id')->groupBy('entries.id')->havingRaw('SUM(lines.debit) <> SUM(lines.credit)')->count());
        } finally {
            $this->travelBack();
        }
    }
}
