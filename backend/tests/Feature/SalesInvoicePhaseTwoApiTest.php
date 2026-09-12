<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryPostingService;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SalesInvoicePhaseTwoApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_posting_preview_is_read_only_and_matches_the_following_post(): void
    {
        $s = $this->scenario(true, '100.000'); $invoice = $this->invoice($s, $s['product'], '10');
        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}/posting-preview", $s['headers'])->assertOk()
            ->assertJsonPath('data.invoice.total', '108.00')->assertJsonPath('data.accounting.accountsReceivableDebit', '108.00')->assertJsonPath('data.accounting.revenueCredit', '100.00')->assertJsonPath('data.accounting.taxCredit', '8.00')->assertJsonPath('data.cogs.totalEstimated', '20.00')->assertJsonPath('data.inventory.0.quantityToConsume', '10.000')->assertJsonPath('data.inventory.0.baseUnit', 'piece')->assertJsonPath('data.inventory.0.warehouseId', $s['warehouse']);
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count()); $this->assertSame(0, DB::table('customer_receivables')->where('tenant_id', $s['tenant'])->count()); $this->assertSame(0, DB::table('sales_invoice_costs')->where('tenant_id', $s['tenant'])->count()); $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $s['tenant'])->where('type', 'sale_consumption')->count());
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'preview-then-post'], $s['headers'])->assertOk();
        $movement = DB::table('stock_movements')->where('tenant_id', $s['tenant'])->where('reference_type', 'sales_invoice_line')->sole();
        $this->assertSame('10.000', $movement->quantity_out); $this->assertSame('2.00', $movement->unit_cost); $this->assertSame('20.00', $movement->total_cost);
    }

    public function test_posting_a_recipe_product_creates_one_ar_revenue_tax_cogs_journal_and_consumes_inventory_once(): void
    {
        $s = $this->scenario(true, '100.000');
        $invoice = $this->invoice($s, $s['product'], '10');
        $posted = $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'post-recipe-1'], $s['headers'])->assertOk()
            ->assertJsonPath('data.status', 'posted')->assertJsonPath('data.accountingStatus', 'posted')->assertJsonPath('data.paymentStatus', 'unpaid')->assertJsonPath('data.receivableAmount', '108.00')->assertJsonPath('data.allowedActions.canEdit', false)->assertJsonPath('data.allowedActions.canPost', false);
        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->where('source_id', $invoice)->where('source_event', 'SALES_INVOICE_POSTED')->sole();
        $lines = DB::table('journal_entry_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')->where('lines.journal_entry_id', $journal->id)->select('accounts.code', 'lines.debit', 'lines.credit')->get()->keyBy('code');
        $this->assertSame('108.00', $lines['1200']->debit); $this->assertSame('100.00', $lines['4000']->credit); $this->assertSame('8.00', $lines['2010']->credit); $this->assertSame('20.00', $lines['5000']->debit); $this->assertSame('20.00', $lines['1100']->credit);
        $this->assertSame('90.000', DB::table('stock_balances')->where('tenant_id', $s['tenant'])->where('warehouse_id', $s['warehouse'])->where('inventory_item_id', $s['material'])->value('quantity_on_hand'));
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $s['tenant'])->where('reference_type', 'sales_invoice_line')->count());
        $this->assertSame(1, DB::table('customer_receivables')->where('tenant_id', $s['tenant'])->where('sales_invoice_id', $invoice)->count());
        $this->assertSame(1, DB::table('sales_invoice_costs')->where('tenant_id', $s['tenant'])->where('sales_invoice_id', $invoice)->count());
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'post-recipe-1'], $s['headers'])->assertOk();
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->where('source_id', $invoice)->count());
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $s['tenant'])->where('reference_type', 'sales_invoice_line')->count());
    }

    public function test_service_sale_posts_ar_revenue_and_tax_without_inventory_or_cogs(): void
    {
        $s = $this->scenario(false, '0.000'); $invoice = $this->invoice($s, $s['product'], '2');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'post-service-1'], $s['headers'])->assertOk()->assertJsonPath('data.status', 'posted')->assertJsonPath('data.inventoryStatus', 'not_applicable');
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $s['tenant'])->where('reference_type', 'sales_invoice_line')->count());
        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->where('source_id', $invoice)->sole();
        $this->assertSame(0, DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->whereIn('a.code', ['5000', '1100'])->count());
    }

    public function test_insufficient_stock_rolls_back_invoice_posting_ar_and_inventory_and_posted_invoice_is_immutable(): void
    {
        $s = $this->scenario(true, '1.000'); $invoice = $this->invoice($s, $s['product'], '10');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'post-no-stock'], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('quantity');
        $this->assertSame('draft', DB::table('sales_invoices')->where('id', $invoice)->value('status')); $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_id', $invoice)->count()); $this->assertSame(0, DB::table('customer_receivables')->where('sales_invoice_id', $invoice)->count());
        $good = $this->scenario(false, '0.000'); $posted = $this->invoice($good, $good['product'], '1'); $this->postJson("/api/v1/finance/sales-invoices/{$posted}/post", ['idempotencyKey' => 'post-immutable'], $good['headers'])->assertOk();
        $this->patchJson("/api/v1/finance/sales-invoices/{$posted}", ['reference' => 'mutate'], $good['headers'])->assertUnprocessable();
        $this->postJson("/api/v1/finance/sales-invoices/{$posted}/cancel", [], $good['headers'])->assertUnprocessable();
    }

    public function test_missing_finance_mapping_rolls_back_before_any_sales_effect_and_replay_never_creates_pos_or_payment_rows(): void
    {
        $s = $this->scenario(true, '100.000'); $invoice = $this->invoice($s, $s['product'], '1');
        DB::table('sales_account_mappings')->where('tenant_id', $s['tenant'])->where('mapping_key', 'sales.revenue')->delete();
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'missing-map'], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('finance');
        $this->assertSame('draft', DB::table('sales_invoices')->where('id', $invoice)->value('status')); $this->assertSame(0, DB::table('customer_receivables')->where('sales_invoice_id', $invoice)->count()); $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_id', $invoice)->count()); $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $s['tenant'])->where('reference_type', 'sales_invoice_line')->count()); $this->assertSame(0, DB::table('sales_invoice_costs')->where('sales_invoice_id', $invoice)->count()); $this->assertSame(0, DB::table('orders')->where('tenant_id', $s['tenant'])->count()); $this->assertSame(0, DB::table('payments')->where('tenant_id', $s['tenant'])->count());
    }

    private function scenario(bool $tracked, string $opening): array
    {
        $suffix = (string) str()->uuid(); $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Sales P2', 'slug' => "sales-p2-{$suffix}", 'status' => 'active', 'tax_rate' => '0.080000', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Downtown', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => "sales-p2-{$suffix}@test.local", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner); $warehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branch}-MAIN")->value('id');
        $token = "sales-p2-{$suffix}"; DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'sales-p2', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]); $headers = ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
        $material = null;
        if ($tracked) { $material = (int) DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee Beans', 'name_ar' => 'Coffee Beans', 'name_en' => 'Coffee Beans', 'sku' => "MAT-{$suffix}", 'catalog_identity' => "mat-{$suffix}", 'item_type' => 'raw_material', 'unit' => 'piece', 'minimum_stock' => '0.000', 'reorder_level' => '0.000', 'cost_per_unit' => '2.0000', 'latest_unit_cost' => '2.0000', 'is_active' => true, 'created_by' => $owner, 'updated_by' => $owner, 'created_at' => now(), 'updated_at' => now()]); DB::table('inventory_item_warehouses')->insert(['tenant_id' => $tenant, 'inventory_item_id' => $material, 'warehouse_id' => $warehouse, 'created_at' => now(), 'updated_at' => now()]); app(InventoryPostingService::class)->post(Request::create('/stock-in', 'POST'), $tenant, ['warehouseId' => $warehouse, 'branchId' => $branch, 'itemId' => $material, 'type' => 'stock_in', 'quantity' => $opening, 'unit' => 'piece', 'unitCost' => '2.0000', 'idempotencyKey' => "opening-{$suffix}"], $owner); }
        $product = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => $tracked ? 'Cappuccino' : 'Meeting Room', 'name_ar' => $tracked ? 'Cappuccino' : 'Meeting Room', 'sku' => "PROD-{$suffix}", 'price' => '10.00', 'is_active' => true, 'is_stock_tracked' => $tracked, 'inventory_controlled' => $tracked, 'created_at' => now(), 'updated_at' => now()]);
        if ($tracked) { $variant = (int) DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => '10.00', 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); $recipe = (int) DB::table('variant_recipes')->insertGetId(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'created_at' => now(), 'updated_at' => now()]); DB::table('variant_recipe_components')->insert(['tenant_id' => $tenant, 'variant_recipe_id' => $recipe, 'inventory_item_id' => $material, 'quantity' => '1.000000', 'unit_code' => 'piece', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]); }
        return compact('tenant','branch','owner','headers','warehouse','material','product');
    }
    private function invoice(array $s, int $product, string $quantity): int { $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'Damascus Tech Company'], $s['headers'])->assertCreated()->json('data.id'); return (int) $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $customer, 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $product, 'quantity' => $quantity]]], $s['headers'])->assertCreated()->json('data.id'); }
}
