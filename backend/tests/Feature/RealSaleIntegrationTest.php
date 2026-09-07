<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RealSaleIntegrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_real_recipe_publish_order_payment_consumes_canonical_inventory_and_is_idempotent(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        $tenant = $scenario['tenant'];
        $orderId = $scenario['orderId'];
        $headers = $scenario['headers'];

        $order = DB::table('orders')->where('id', $orderId)->first();
        $this->assertSame($scenario['versionId'], (int) $order->published_menu_version_id);
        $this->assertSame($scenario['variantId'], (int) DB::table('order_items')->where('order_id', $orderId)->value('product_variant_id'));
        $this->assertSame($scenario['placementId'], (int) DB::table('order_items')->where('order_id', $orderId)->value('menu_item_placement_id'));
        $this->assertSame(0, DB::table('recipes')->where('tenant_id', $tenant)->where('product_id', $scenario['productId'])->count());
        $this->assertSame(0, DB::table('recipe_lines')->where('tenant_id', $tenant)->count());

        $payment = ['method' => 'cash', 'amount' => $scenario['total'], 'idempotencyKey' => 'phase-three-real-sale'];
        $this->postJson("/api/v1/orders/{$orderId}/pay", $payment, $headers)->assertOk()
            ->assertJsonPath('data.payment.status', 'completed');

        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $scenario['materialId'])->sole();
        $this->assertSame('250.000', $movement->quantity);
        $this->assertSame('gram', $movement->input_unit);
        $this->assertSame('5.00', $movement->total_cost);
        $this->assertSame('750.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $scenario['warehouseId'])->where('inventory_item_id', $scenario['materialId'])->value('quantity_on_hand'));
        $this->assertSame('5.00', DB::table('orders')->where('id', $orderId)->value('cogs_total'));

        $journal = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->where('source_event', 'POS_ORDER_PAID')->sole();
        $this->assertSame('posted', $journal->status);
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journal->id)->get()->keyBy('financial_account_id');
        $this->assertSame('5.00', $lines[(int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5000')->value('id')]->debit);
        $this->assertSame('5.00', $lines[(int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id')]->credit);

        $this->postJson("/api/v1/orders/{$orderId}/pay", $payment, $headers)->assertOk();
        $this->assertSame(1, DB::table('payments')->where('tenant_id', $tenant)->where('order_id', $orderId)->count());
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $scenario['materialId'])->count());
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
    }

    public function test_real_published_sale_rolls_back_payment_inventory_cogs_and_accounting_when_stock_is_insufficient(): void
    {
        $scenario = $this->publishedOrderScenario('100.000');
        $tenant = $scenario['tenant'];
        $orderId = $scenario['orderId'];

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $scenario['total'], 'idempotencyKey' => 'phase-three-insufficient-stock'], $scenario['headers'])
            ->assertUnprocessable()->assertJsonValidationErrors('quantity');

        $this->assertSame('unpaid', DB::table('orders')->where('id', $orderId)->value('payment_status'));
        $this->assertNull(DB::table('orders')->where('id', $orderId)->value('cogs_total'));
        $this->assertSame(0, DB::table('payments')->where('tenant_id', $tenant)->where('order_id', $orderId)->count());
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->count());
        $this->assertSame('100.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $scenario['warehouseId'])->where('inventory_item_id', $scenario['materialId'])->value('quantity_on_hand'));
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
    }

    public function test_owner_cafe_configuration_branch_creation_provisions_one_main_warehouse_and_existing_branches_can_be_repaired_idempotently(): void
    {
        $context = $this->tenantContext();
        $payload = ['name' => 'Airport', 'timezone' => 'Asia/Damascus'];
        $created = $this->postJson('/api/v1/cafe-configuration/branches', $payload, $context['headers'])->assertCreated()
            ->assertJsonPath('data.currency', 'SYP')
            ->assertJsonPath('data.isActive', true);
        $branchId = (int) $created->json('data.id');

        $this->assertSame($context['tenant'], (int) DB::table('branches')->where('id', $branchId)->value('tenant_id'));
        $this->assertSame(1, DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('branch_id', $branchId)->where('code', "BR-{$branchId}-MAIN")->where('type', 'branch_main')->where('is_active', true)->count());
        $this->postJson('/api/v1/cafe-configuration/branches', $payload, $this->headersForRole($context['tenant'], 'manager'))->assertForbidden();
        $this->postJson('/api/v1/cafe-configuration/branches', $payload, $this->headersForRole($context['tenant'], 'cashier'))->assertForbidden();

        $legacyBranch = DB::table('branches')->insertGetId(['tenant_id' => $context['tenant'], 'name' => 'Legacy Branch', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $setup = app(FinancialSetupService::class);
        $setup->ensureBranchMainWarehouse($context['tenant'], $legacyBranch, $context['owner']);
        $setup->ensureBranchMainWarehouse($context['tenant'], $legacyBranch, $context['owner']);

        $warehouse = DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('code', "BR-{$legacyBranch}-MAIN")->sole();
        $this->assertSame($legacyBranch, (int) $warehouse->branch_id);
        $this->assertSame('branch_main', $warehouse->type);
        $this->assertSame(1, DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('code', "BR-{$legacyBranch}-MAIN")->count());
    }

    /** @return array{tenant:int, owner:int, headers:array<string,string>} */
    private function tenantContext(): array
    {
        $suffix = (string) str()->uuid();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Phase Three Cafe', 'slug' => "phase-three-{$suffix}", 'status' => 'active', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'tax_rate' => '0.000000', 'created_at' => now(), 'updated_at' => now()]);
        $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Phase Three Owner', 'email' => "phase-three-{$suffix}@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, null, $owner);
        $token = "phase-three-token-{$suffix}";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'phase-three', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return compact('tenant', 'owner') + ['headers' => ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => (string) $tenant]];
    }

    /** @return array<string,string> */
    private function headersForRole(int $tenant, string $role): array
    {
        $suffix = (string) str()->uuid();
        $user = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => "Phase Three {$role}", 'email' => "phase-three-{$role}-{$suffix}@example.test", 'password' => bcrypt('password'), 'role' => $role, 'is_active' => true, 'must_change_password' => false, 'created_at' => now(), 'updated_at' => now()]);
        $token = "phase-three-{$role}-{$suffix}";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $user, 'name' => "phase-three-{$role}", 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => (string) $tenant];
    }

    /** @return array{tenant:int, headers:array<string,string>, materialId:int, warehouseId:int, productId:int, variantId:int, placementId:int, versionId:int, orderId:int, total:string} */
    private function publishedOrderScenario(string $openingStock): array
    {
        $context = $this->tenantContext();
        $tenant = $context['tenant'];
        $headers = $context['headers'];
        $branchId = (int) $this->postJson('/api/v1/cafe-configuration/branches', ['name' => 'Downtown', 'timezone' => 'Asia/Damascus'], $headers)->assertCreated()->json('data.id');
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('code', "BR-{$branchId}-MAIN")->value('id');

        $materialId = (int) $this->postJson('/api/v1/inventory/items', ['nameAr' => 'Phase Three Beans', 'nameEn' => 'Phase Three Beans', 'sku' => 'P3-BEANS', 'itemType' => 'raw_material', 'unit' => 'g', 'minimumStock' => '0.000', 'reorderLevel' => '0.000', 'latestUnitCost' => '0.0200', 'isActive' => true], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/inventory/items/{$materialId}/unit-conversions", ['sourceUnit' => 'kg', 'targetUnit' => 'g', 'factor' => '1000.000000', 'isActive' => true], $headers)->assertCreated();
        $this->postJson('/api/v1/inventory/movements', ['warehouseId' => $warehouseId, 'branchId' => $branchId, 'itemId' => $materialId, 'type' => 'stock_in', 'quantity' => $openingStock, 'unit' => 'g', 'unitCost' => '0.0200', 'idempotencyKey' => 'phase-three-opening-stock'], $headers)->assertCreated();

        $category = (int) $this->postJson('/api/v1/admin/catalog/categories', ['name' => 'Coffee'], $headers)->assertCreated()->json('data.id');
        $reportingCategory = (int) $this->postJson('/api/v1/admin/catalog/reporting-categories', ['name' => 'Beverages', 'nameAr' => 'Beverages', 'nameEn' => 'Beverages', 'code' => 'BEVERAGES'], $headers)->assertCreated()->json('data.id');
        $station = (int) $this->postJson('/api/v1/admin/catalog/kitchen-stations', ['name' => 'Coffee Bar', 'nameAr' => 'Coffee Bar', 'nameEn' => 'Coffee Bar', 'code' => 'COFFEE-BAR', 'branchId' => $branchId], $headers)->assertCreated()->json('data.id');
        $productId = (int) $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Canonical Latte', 'nameAr' => 'Canonical Latte', 'nameEn' => 'Canonical Latte', 'categoryId' => $category, 'reportingCategoryId' => $reportingCategory, 'kitchenStationId' => $station, 'productType' => 'standard', 'isStockTracked' => true, 'variants' => [['name' => 'Regular', 'basePrice' => '10.00', 'costPrice' => '0.00', 'isDefault' => true, 'isActive' => true, 'sortOrder' => 0]]], $headers)->assertCreated()->assertJsonPath('data.isStockTracked', true)->json('data.id');
        $variantId = (int) DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $productId)->value('id');
        $this->putJson("/api/v1/admin/catalog/product-variants/{$variantId}/recipe", ['components' => [['materialId' => $materialId, 'quantity' => '0.250', 'unitCode' => 'kg', 'sortOrder' => 0]]], $headers)->assertOk();

        $menuId = (int) $this->postJson('/api/v1/admin/menus', ['name' => 'Phase Three Menu', 'nameAr' => 'Phase Three Menu', 'nameEn' => 'Phase Three Menu', 'status' => 'draft'], $headers)->assertCreated()->json('data.id');
        $sectionId = (int) $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Coffee', 'nameAr' => 'Coffee', 'nameEn' => 'Coffee', 'sortOrder' => 0], $headers)->assertCreated()->json('data.id');
        $placementId = (int) $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $productId, 'sortOrder' => 0, 'isVisible' => true], $headers)->assertCreated()->json('data.id');
        $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branchId, 'channel' => 'pos', 'assignments' => [['menuId' => $menuId, 'priority' => 0, 'isActive' => true]]], $headers)->assertOk();
        $versionId = (int) $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $branchId, 'channel' => 'pos', 'menuIds' => [$menuId]], $headers)->assertOk()->assertJsonPath('data.published', true)->json('data.version.id');
        $component = json_decode((string) DB::table('published_menu_versions')->where('id', $versionId)->value('payload_json'), true, 512, JSON_THROW_ON_ERROR)['menus'][0]['sections'][0]['products'][0]['variants'][0]['baseRecipe'][0];
        $this->assertSame('250.000', $component['canonicalQuantity']);
        $this->assertSame('gram', $component['baseUnit']);

        $shiftId = (int) $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 0], $headers)->assertCreated()->json('data.id');
        $order = $this->postJson('/api/v1/orders', ['branchId' => $branchId, 'shiftId' => $shiftId, 'orderType' => 'takeaway', 'publishedMenuVersionId' => $versionId, 'items' => [['productId' => $productId, 'placementId' => $placementId, 'variantId' => $variantId, 'quantity' => 1]]], $headers)->assertCreated();

        return compact('tenant', 'headers', 'materialId', 'warehouseId', 'productId', 'variantId', 'placementId', 'versionId') + ['orderId' => (int) $order->json('data.id'), 'total' => (string) $order->json('data.totals.total')];
    }
}
