<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryPostingService;
use App\Services\FinancialSetupService;
use App\Services\SalesReportingQueryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Manual Sales Invoice line pricing: default price source, manual override,
 * variant pricing priority, master-data isolation, and reporting/audit
 * fidelity of the actual invoiced price.
 */
class SalesInvoiceLinePricingTest extends TestCase
{
    use RefreshDatabase;

    public function test_default_unit_price_is_the_product_price_when_not_overridden(): void
    {
        $s = $this->scenario(); $product = $this->product($s['tenant'], 'Almond Croissant', '4.50');
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', $this->payload($s, [['productId' => $product, 'quantity' => '2']]), $s['headers'])->assertCreated();
        $invoice->assertJsonPath('data.lines.0.baseUnitPrice', '4.50')->assertJsonPath('data.lines.0.unitPrice', '4.50')->assertJsonPath('data.lines.0.lineSubtotal', '9.00');
    }

    public function test_manual_unit_price_override_is_used_for_the_line_and_totals_but_master_price_is_untouched(): void
    {
        $s = $this->scenario(); $product = $this->product($s['tenant'], 'Almond Croissant', '4.50');
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', $this->payload($s, [['productId' => $product, 'quantity' => '2', 'unitPrice' => '4.00']]), $s['headers'])->assertCreated();
        $invoice->assertJsonPath('data.lines.0.baseUnitPrice', '4.50')->assertJsonPath('data.lines.0.unitPrice', '4.00')->assertJsonPath('data.lines.0.lineSubtotal', '8.00')->assertJsonPath('data.subtotal', '8.00');
        $this->assertSame('4.50', (string) DB::table('products')->where('id', $product)->value('price'));
    }

    public function test_variant_base_price_is_authoritative_over_parent_product_price_when_a_variant_is_selected(): void
    {
        $s = $this->scenario(); $product = $this->product($s['tenant'], 'Iced Latte', '4.50');
        $variant = (int) DB::table('product_variants')->insertGetId(['tenant_id' => $s['tenant'], 'product_id' => $product, 'name' => 'Large', 'base_price' => '6.00', 'is_default' => false, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', $this->payload($s, [['productId' => $product, 'variantId' => $variant, 'quantity' => '1']]), $s['headers'])->assertCreated();
        $invoice->assertJsonPath('data.lines.0.baseUnitPrice', '6.00')->assertJsonPath('data.lines.0.unitPrice', '6.00');
    }

    public function test_price_override_emits_a_dedicated_audit_event_and_a_matching_price_does_not(): void
    {
        $s = $this->scenario(); $product = $this->product($s['tenant'], 'Almond Croissant', '4.50');
        $overridden = $this->postJson('/api/v1/finance/sales-invoices', $this->payload($s, [['productId' => $product, 'quantity' => '1', 'unitPrice' => '3.75']]), $s['headers'])->assertCreated()->json('data.id');
        $this->assertSame(1, DB::table('activity_logs')->where('tenant_id', $s['tenant'])->where('action', 'sales.invoice.price_overridden')->count());

        $matching = $this->postJson('/api/v1/finance/sales-invoices', $this->payload($s, [['productId' => $product, 'quantity' => '1', 'unitPrice' => '4.50']]), $s['headers'])->assertCreated()->json('data.id');
        $this->assertSame(1, DB::table('activity_logs')->where('tenant_id', $s['tenant'])->where('action', 'sales.invoice.price_overridden')->count());
        $this->assertNotSame($overridden, $matching);
    }

    public function test_line_discount_reduces_total_correctly_on_top_of_the_overridden_price(): void
    {
        $s = $this->scenario(); $product = $this->product($s['tenant'], 'Almond Croissant', '4.50');
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', $this->payload($s, [['productId' => $product, 'quantity' => '2', 'unitPrice' => '4.00', 'discountType' => 'fixed', 'discountValue' => '1.00']]), $s['headers'])->assertCreated();
        $invoice->assertJsonPath('data.lines.0.lineSubtotal', '8.00')->assertJsonPath('data.lines.0.discountAmount', '1.00')->assertJsonPath('data.lines.0.subtotal', '7.00')->assertJsonPath('data.subtotal', '7.00');
    }

    public function test_cogs_is_independent_of_the_manual_sales_price_override(): void
    {
        $s = $this->trackedScenario();
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', $this->payload($s, [['productId' => $s['product'], 'quantity' => '5', 'unitPrice' => '1.00']]), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'cogs-independent'], $s['headers'])->assertOk()->assertJsonPath('data.total', '5.00');
        // Material cost is 2.00/unit regardless of the 1.00 sales override — COGS reflects WAC, never the invoiced revenue price.
        $this->assertSame('10.00', (string) DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice)->value('cogs_total'));
    }

    public function test_reporting_uses_the_actual_invoiced_price_not_the_products_default_price(): void
    {
        $s = $this->scenario(); $product = $this->product($s['tenant'], 'Almond Croissant', '4.50');
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', $this->payload($s, [['productId' => $product, 'quantity' => '2', 'unitPrice' => '4.00']]), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'reporting-override'], $s['headers'])->assertOk();
        $report = app(SalesReportingQueryService::class)->manualInvoiceNetOfCreditNotes($s['tenant'], [$s['branch']], '2026-09-01', '2026-09-30');
        // 2 x 4.00 override = 800 cents net, NOT 2 x 4.50 = 900 cents.
        $this->assertSame(800, $report['grossCents']);
    }

    private function scenario(): array
    {
        $suffix = (string) str()->uuid(); $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Sales Pricing', 'slug' => "sales-pricing-{$suffix}", 'status' => 'active', 'tax_rate' => '0.000000', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => "sales-pricing-{$suffix}@test.local", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner);
        $token = "sales-pricing-{$suffix}"; DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'sales-pricing', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
        $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'Damascus Tech Team'], $headers)->assertCreated()->json('data.id');
        return compact('tenant', 'branch', 'owner', 'headers', 'customer');
    }

    private function trackedScenario(): array
    {
        $s = $this->scenario();
        $warehouse = (int) DB::table('branches')->where('id', $s['branch'])->value('pos_inventory_warehouse_id');
        $material = (int) DB::table('inventory_items')->insertGetId(['tenant_id' => $s['tenant'], 'name' => 'Milk', 'name_ar' => 'Milk', 'name_en' => 'Milk', 'sku' => 'MAT-'.uniqid(), 'catalog_identity' => 'mat-'.uniqid(), 'item_type' => 'raw_material', 'unit' => 'piece', 'minimum_stock' => '0.000', 'reorder_level' => '0.000', 'cost_per_unit' => '2.0000', 'latest_unit_cost' => '2.0000', 'is_active' => true, 'created_by' => $s['owner'], 'updated_by' => $s['owner'], 'created_at' => now(), 'updated_at' => now()]);
        DB::table('inventory_item_warehouses')->insert(['tenant_id' => $s['tenant'], 'inventory_item_id' => $material, 'warehouse_id' => $warehouse, 'created_at' => now(), 'updated_at' => now()]);
        app(InventoryPostingService::class)->post(Request::create('/stock-in', 'POST'), $s['tenant'], ['warehouseId' => $warehouse, 'branchId' => $s['branch'], 'itemId' => $material, 'type' => 'stock_in', 'quantity' => '100.000', 'unit' => 'piece', 'unitCost' => '2.0000', 'idempotencyKey' => 'opening-'.uniqid()], $s['owner']);
        $product = (int) DB::table('products')->insertGetId(['tenant_id' => $s['tenant'], 'name' => 'Cappuccino', 'name_ar' => 'Cappuccino', 'sku' => 'PROD-'.uniqid(), 'price' => '5.00', 'is_active' => true, 'is_stock_tracked' => true, 'inventory_controlled' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = (int) DB::table('product_variants')->insertGetId(['tenant_id' => $s['tenant'], 'product_id' => $product, 'name' => 'Regular', 'base_price' => '5.00', 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $recipe = (int) DB::table('variant_recipes')->insertGetId(['tenant_id' => $s['tenant'], 'product_variant_id' => $variant, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('variant_recipe_components')->insert(['tenant_id' => $s['tenant'], 'variant_recipe_id' => $recipe, 'inventory_item_id' => $material, 'quantity' => '1.000000', 'unit_code' => 'piece', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);
        return $s + compact('product', 'variant', 'warehouse', 'material');
    }

    private function payload(array $s, array $lines): array
    {
        return ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-09-12', 'dueDate' => now()->addYear()->toDateString(), 'lines' => $lines];
    }

    private function product(int $tenant, string $name, string $price): int
    {
        return (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'name_ar' => $name, 'sku' => 'S-'.uniqid(), 'price' => $price, 'is_active' => true, 'is_stock_tracked' => false, 'created_at' => now(), 'updated_at' => now()]);
    }
}
