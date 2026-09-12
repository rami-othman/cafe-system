<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryPostingService;
use App\Models\User;
use App\Services\CustomerManagementService;
use App\Services\FinancialSetupService;
use App\Services\SaleConsumptionService;
use App\Services\SalesInvoicePostingService;
use App\Services\SalesInvoiceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Characterization: identical selected variant/recipe/WAC/branch rules for POS and manual invoice. */
final class SalesInvoicePosCrossPathCharacterizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_pos_and_manual_invoice_consume_the_same_18_grams_per_cappuccino_from_the_same_branch_main_warehouse(): void
    {
        $x = $this->scenario(); $request = Request::create('/sales', 'POST'); $request->attributes->set('tenant_id', $x['tenant']); $request->attributes->set('auth_user', $x['user']);
        $preview = app(SalesInvoicePostingService::class)->preview($x['tenant'], $x['invoice']->id);
        $this->assertSame('180.000', $preview['inventory'][0]['quantityToConsume']); $this->assertSame('gram', $preview['inventory'][0]['baseUnit']); $this->assertSame($x['warehouse'], $preview['inventory'][0]['warehouseId']); $this->assertSame('3.60', $preview['cogs']['totalEstimated']);
        $order = DB::table('orders')->where('id', $x['order'])->first(); app(SaleConsumptionService::class)->consumeForOrder($request, $x['tenant'], $order, null, $x['owner']);
        app(SalesInvoicePostingService::class)->post($request, $x['tenant'], $x['invoice']->id, $x['owner'], ['idempotencyKey' => 'cross-path-invoice-post']);
        $pos = DB::table('stock_movements')->where('reference_type', 'order_item')->sole(); $manual = DB::table('stock_movements')->where('reference_type', 'sales_invoice_line')->sole();
        foreach (['warehouse_id', 'inventory_item_id', 'type', 'quantity_out', 'input_unit', 'base_quantity', 'unit_cost', 'total_cost'] as $field) $this->assertSame((string) $pos->{$field}, (string) $manual->{$field}, "POS/manual mismatch: {$field}");
        $this->assertSame('180.000', $pos->quantity_out); $this->assertSame('gram', $pos->input_unit); $this->assertSame('3.60', $pos->total_cost);
    }

    private function scenario(): array
    {
        $s = (string) str()->uuid(); $now = now(); $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Cross path', 'slug' => "cross-{$s}", 'status' => 'active', 'tax_rate' => '0.080000', 'created_at' => $now, 'updated_at' => $now]); $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Downtown', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]); $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => "cross-{$s}@test", 'password' => bcrypt('x'), 'role' => 'owner', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]); $user = User::findOrFail($owner);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner); $warehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branch}-MAIN")->value('id');
        $material = (int) DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee Beans', 'name_ar' => 'Coffee Beans', 'name_en' => 'Coffee Beans', 'sku' => "BEANS-{$s}", 'catalog_identity' => "beans-{$s}", 'item_type' => 'raw_material', 'unit' => 'gram', 'minimum_stock' => '0.000', 'reorder_level' => '0.000', 'cost_per_unit' => '0.0200', 'latest_unit_cost' => '0.0200', 'is_active' => true, 'created_by' => $owner, 'updated_by' => $owner, 'created_at' => $now, 'updated_at' => $now]); DB::table('inventory_item_warehouses')->insert(['tenant_id' => $tenant, 'inventory_item_id' => $material, 'warehouse_id' => $warehouse, 'created_at' => $now, 'updated_at' => $now]); app(InventoryPostingService::class)->post(Request::create('/stock', 'POST'), $tenant, ['warehouseId' => $warehouse, 'branchId' => $branch, 'itemId' => $material, 'type' => 'stock_in', 'quantity' => '1000', 'unit' => 'gram', 'unitCost' => '0.0200'], $owner);
        $product = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Cappuccino', 'name_ar' => 'Cappuccino', 'sku' => "CAP-{$s}", 'price' => '10.00', 'is_active' => true, 'is_stock_tracked' => true, 'inventory_controlled' => true, 'created_at' => $now, 'updated_at' => $now]); $variant = (int) DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => '10.00', 'is_default' => true, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]); $recipe = (int) DB::table('variant_recipes')->insertGetId(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'created_at' => $now, 'updated_at' => $now]); DB::table('variant_recipe_components')->insert(['tenant_id' => $tenant, 'variant_recipe_id' => $recipe, 'inventory_item_id' => $material, 'quantity' => '18.000000', 'unit_code' => 'gram', 'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now]);
        $customer = app(CustomerManagementService::class)->create($tenant, $owner, ['name' => 'Damascus Tech Company']); $invoice = app(SalesInvoiceService::class)->create($tenant, $owner, ['branchId' => $branch, 'customerId' => $customer->id, 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $product, 'variantId' => $variant, 'quantity' => '10']]]);
        $menu = (int) DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'POS', 'status' => 'published', 'created_at' => $now, 'updated_at' => $now]); $section = (int) DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]); $placement = (int) DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'is_visible' => true, 'created_at' => $now, 'updated_at' => $now]); $pub = (int) DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_by' => $owner, 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]); $payload = ['context' => ['schemaVersion' => 3], 'menus' => [['sections' => [['products' => [['productId' => $product, 'placementId' => $placement, 'variants' => [['id' => $variant, 'baseRecipe' => [['materialId' => $material, 'quantity' => '18.000000', 'unitCode' => 'gram']], 'modifierRecipeAdjustments' => []]]]]]]]]]; $version = (int) DB::table('published_menu_versions')->insertGetId(['tenant_id' => $tenant, 'menu_publication_id' => $pub, 'branch_id' => $branch, 'channel' => 'pos', 'version_number' => 1, 'payload_json' => json_encode($payload), 'checksum' => hash('sha256', json_encode($payload)), 'status' => 'current', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]); $order = (int) DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'published_menu_version_id' => $version, 'order_number' => 'CROSS-1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'total' => '108.00', 'created_at' => $now, 'updated_at' => $now]); DB::table('order_items')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'product_variant_id' => $variant, 'menu_item_placement_id' => $placement, 'product_name' => 'Cappuccino', 'variant_name' => 'Regular', 'quantity' => '10.000', 'unit_price' => '10.00', 'total' => '108.00', 'created_at' => $now, 'updated_at' => $now]);
        return compact('tenant','branch','owner','user','warehouse','invoice','order');
    }
}
