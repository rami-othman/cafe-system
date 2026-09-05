<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryPostingService;
use App\Services\FinancialSetupService;
use App\Support\Money;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class InventoryAccountingMapperTest extends TestCase
{
    use RefreshDatabase;

    public function test_waste_posts_one_balanced_journal_using_the_persisted_movement_cost_and_replays_safely(): void
    {
        [$tenant, $actor, $warehouse, $item] = $this->fixture(); $service = app(InventoryPostingService::class); $request = Request::create('/inventory-test', 'POST');
        $service->post($request, $tenant, $this->movement($warehouse, $item, 'stock_in', '10.000', '2.3456', 'open'), $actor);
        $waste = $service->post($request, $tenant, $this->movement($warehouse, $item, 'waste', '3.000', null, 'waste-1', 'Damaged beans'), $actor);
        $movement = DB::table('stock_movements')->where('id', $waste->movementId)->first();
        $this->assertMoney('7.04', $movement->total_cost);
        $journal = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'inventory_movement')->where('source_id', $movement->id)->where('source_event', 'INVENTORY_WASTE')->first();
        $this->assertNotNull($journal); $this->assertSame('posted', $journal->status);
        $lines = DB::table('journal_entry_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')->where('lines.journal_entry_id', $journal->id)->pluck('debit', 'accounts.code');
        $credits = DB::table('journal_entry_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')->where('lines.journal_entry_id', $journal->id)->pluck('credit', 'accounts.code');
        $this->assertMoney('7.04', $lines['5010']); $this->assertMoney('7.04', $credits['1100']);
        $replay = $service->post($request, $tenant, $this->movement($warehouse, $item, 'waste', '3.000', null, 'waste-1', 'Damaged beans'), $actor);
        $this->assertTrue($replay->replayed); $this->assertSame($waste->movementId, $replay->movementId); $this->assertSame(1, DB::table('journal_entries')->where('source_type', 'inventory_movement')->where('source_id', $movement->id)->count());
    }

    public function test_stock_count_shortage_and_surplus_use_final_movement_cost_with_opposite_balanced_lines(): void
    {
        [$tenant, $actor, $warehouse, $item] = $this->fixture(); $service = app(InventoryPostingService::class); $request = Request::create('/inventory-test', 'POST');
        $service->post($request, $tenant, $this->movement($warehouse, $item, 'stock_in', '10.000', '3.0000', 'open'), $actor);
        $shortage = $service->post($request, $tenant, $this->movement($warehouse, $item, 'stock_count_variance', '2.000', null, 'short', 'Count shortage', ['countDirection' => 'out']), $actor);
        $surplus = $service->post($request, $tenant, $this->movement($warehouse, $item, 'stock_count_variance', '1.000', '3.0000', 'surplus', 'Count surplus', ['countDirection' => 'in']), $actor);
        $this->assertJournal($tenant, $shortage->movementId, 'STOCK_COUNT_SHORTAGE', '5010', 'debit', '1100', 'credit', '6.00');
        $this->assertJournal($tenant, $surplus->movementId, 'STOCK_COUNT_SURPLUS', '1100', 'debit', '5010', 'credit', '3.00');
    }

    public function test_missing_mapping_and_ambiguous_adjustment_fail_before_inventory_state_commits(): void
    {
        [$tenant, $actor, $warehouse, $item] = $this->fixture(); $service = app(InventoryPostingService::class); $request = Request::create('/inventory-test', 'POST');
        $service->post($request, $tenant, $this->movement($warehouse, $item, 'stock_in', '5.000', '2.0000', 'open'), $actor);
        DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5010')->update(['is_active' => false]);
        try { $service->post($request, $tenant, $this->movement($warehouse, $item, 'waste', '1.000', null, 'missing-map', 'Waste'), $actor); $this->fail('Expected configuration validation failure.'); } catch (ValidationException) { $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('idempotency_key', 'open')->count()); }
        DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5010')->update(['is_active' => true]);
        $before = DB::table('stock_movements')->where('tenant_id', $tenant)->count();
        try { $service->post($request, $tenant, $this->movement($warehouse, $item, 'adjustment_out', '1.000', null, 'ambiguous', 'Unexplained adjustment'), $actor); $this->fail('Expected adjustment configuration failure.'); } catch (ValidationException) { $this->assertSame($before, DB::table('stock_movements')->where('tenant_id', $tenant)->count()); }
    }

    public function test_internal_transfer_and_sale_consumption_never_create_a_second_inventory_finance_journal(): void
    {
        [$tenant, $actor, $warehouse, $item] = $this->fixture(); $service = app(InventoryPostingService::class); $request = Request::create('/inventory-test', 'POST');
        $service->post($request, $tenant, $this->movement($warehouse, $item, 'stock_in', '6.000', '2.0000', 'open'), $actor);
        $transfer = $service->post($request, $tenant, $this->movement($warehouse, $item, 'transfer_out', '1.000', null, 'transfer', 'Internal transfer'), $actor);
        $sale = $service->post($request, $tenant, $this->movement($warehouse, $item, 'sale_consumption', '1.000', null, 'sale', null), $actor);
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->whereIn('source_id', [$transfer->movementId, $sale->movementId])->where('source_type', 'inventory_movement')->count());
    }

    private function fixture(): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Inventory Finance', 'slug' => 'inventory-finance', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $actor = DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => 'inventory-finance@example.test', 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, null, $actor);
        $warehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', 'CENTRAL')->value('id');
        $item = DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => 'Beans', 'name_ar' => 'Beans', 'name_en' => 'Beans', 'sku' => 'BEANS', 'catalog_identity' => 'beans', 'item_type' => 'raw_material', 'unit' => 'gram', 'minimum_stock' => '0.000', 'reorder_level' => '0.000', 'cost_per_unit' => '0.0000', 'latest_unit_cost' => '0.0000', 'is_active' => true, 'created_by' => $actor, 'updated_by' => $actor, 'created_at' => now(), 'updated_at' => now()]);
        return [(int) $tenant, (int) $actor, $warehouse, (int) $item];
    }
    private function movement(int $warehouse, int $item, string $type, string $quantity, ?string $unitCost, string $key, ?string $reason = null, array $extra = []): array { return [...$extra, 'warehouseId' => $warehouse, 'itemId' => $item, 'type' => $type, 'quantity' => $quantity, 'unit' => 'gram', 'unitCost' => $unitCost, 'reason' => $reason, 'idempotencyKey' => $key]; }
    private function assertJournal(int $tenant, int $movement, string $event, string $debitCode, string $debitField, string $creditCode, string $creditField, string $amount): void { $entry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'inventory_movement')->where('source_id', $movement)->where('source_event', $event)->first(); $this->assertNotNull($entry); $lines = DB::table('journal_entry_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')->where('lines.journal_entry_id', $entry->id)->get(['accounts.code', 'lines.debit', 'lines.credit'])->keyBy('code'); $this->assertMoney($amount, $lines[$debitCode]->{$debitField}); $this->assertMoney($amount, $lines[$creditCode]->{$creditField}); }
    private function assertMoney(string $expected, mixed $actual): void { $this->assertSame(Money::cents($expected, 'expected'), Money::cents($actual, 'actual')); }
}
