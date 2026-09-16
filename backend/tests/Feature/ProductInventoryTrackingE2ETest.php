<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * P0 regression test: proves the real production path — product created
 * through the API with isStockTracked=true, a recipe configured through
 * RecipeConfigurationService's own endpoint, and a menu published through
 * MenuPublishingService — actually consumes inventory, costs at WAC, and
 * posts a balanced COGS journal on a real POS sale. No step here ever writes
 * to products.inventory_controlled directly; if CatalogProductService stopped
 * mirroring it from isStockTracked, this test fails.
 */
class ProductInventoryTrackingE2ETest extends TestCase
{
    use RefreshDatabase;

    public function test_real_product_create_recipe_publish_and_sale_consumes_inventory_and_posts_cogs(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $beans = $this->stockIn($tenant, $branchId, $headers, unitCost: '2.0000', quantity: '100.000');
        $category = $this->postJson('/api/v1/admin/catalog/categories', ['name' => 'E2E Coffee'], $headers)->assertCreated()->json('data.id');

        $product = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => 'E2E Tracked Latte',
            'productType' => 'standard',
            'categoryId' => $category,
            'isStockTracked' => true,
            'variants' => [
                ['name' => 'Regular', 'basePrice' => '10.00', 'costPrice' => '2.00', 'isDefault' => true, 'isActive' => true, 'sortOrder' => 0],
            ],
        ], $headers)->assertCreated()
            ->assertJsonPath('data.isStockTracked', true)
            ->json('data');
        $productId = (int) $product['id'];
        $variantId = (int) DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $productId)->value('id');

        // A2/A3: the canonical flag alone must be enough — no test code here
        // (and no application code path) ever touches inventory_controlled.
        $row = DB::table('products')->where('id', $productId)->first();
        $this->assertTrue((bool) $row->is_stock_tracked);
        $this->assertTrue((bool) $row->inventory_controlled, 'CatalogProductService must mirror inventory_controlled from isStockTracked.');

        $menu = $this->postJson('/api/v1/admin/menus', [
            'name' => 'E2E Menu', 'status' => 'draft',
        ], $headers)->assertCreated()->json('data.id');
        $section = $this->postJson("/api/v1/admin/menus/{$menu}/sections", [
            'name' => 'Coffee', 'sortOrder' => 0,
        ], $headers)->assertCreated()->json('data.id');
        $placement = $this->postJson("/api/v1/admin/menu-sections/{$section}/placements", [
            'productId' => $productId, 'sortOrder' => 0, 'isVisible' => true,
        ], $headers)->assertCreated()->json('data.id');
        $this->putJson('/api/v1/admin/menu-management/assignments', [
            'branchId' => $branchId, 'channel' => 'pos',
            'assignments' => [['menuId' => $menu, 'priority' => 0, 'isActive' => true]],
        ], $headers)->assertOk();
        $this->putJson("/api/v1/admin/menus/{$menu}/availability-rules", [
            'rules' => [['branchId' => $branchId, 'channel' => 'pos', 'startDate' => '2020-01-01', 'endDate' => '2099-12-31', 'priority' => 0, 'isActive' => true]],
        ], $headers)->assertOk();

        $context = ['branchId' => $branchId, 'channel' => 'pos', 'menuIds' => [$menu]];

        // A4: a stock-tracked variant with no recipe must block publishing.
        $this->postJson('/api/v1/admin/menu-management/publish', $context, $headers)
            ->assertUnprocessable();
        $this->assertDatabaseMissing('published_menu_versions', ['tenant_id' => $tenant, 'branch_id' => $branchId, 'channel' => 'pos', 'status' => 'current']);

        $this->putJson("/api/v1/admin/catalog/product-variants/{$variantId}/recipe", [
            'components' => [
                ['materialId' => $beans['itemId'], 'quantity' => '2.000', 'unitCode' => 'kg', 'sortOrder' => 0],
            ],
        ], $headers)->assertOk()->assertJsonCount(1, 'data.components');

        $this->postJson('/api/v1/admin/menu-management/validate', $context, $headers)
            ->assertOk()->assertJsonPath('data.isValid', true)->assertJsonPath('data.errorCount', 0);

        // A4: the same stock-tracked variant, now with a valid recipe, publishes.
        $published = $this->postJson('/api/v1/admin/menu-management/publish', $context, $headers)
            ->assertOk()->assertJsonPath('data.published', true)->json('data.version');

        $shiftId = $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 0], $headers)
            ->assertCreated()->json('data.id');
        $order = $this->postJson('/api/v1/orders', [
            'branchId' => $branchId, 'shiftId' => $shiftId, 'orderType' => 'takeaway',
            'publishedMenuVersionId' => $published['id'],
            'items' => [['productId' => $productId, 'placementId' => $placement, 'variantId' => $variantId, 'quantity' => 3]],
        ], $headers)->assertCreated();
        $orderId = $order->json('data.id');
        $total = $order->json('data.totals.total');

        $pay = $this->postJson("/api/v1/orders/{$orderId}/pay", [
            'method' => 'cash', 'amount' => $total, 'idempotencyKey' => 'e2e-tracking-pay-1',
        ], $headers)->assertOk()->assertJsonPath('data.payment.status', 'completed');

        // Inventory consumption: 2kg/unit * 3 units = 6kg, costed at the 2.00 WAC just stocked in.
        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $beans['itemId'])->first();
        $this->assertNotNull($movement, 'A real sale of a stock-tracked product must create a sale_consumption movement.');
        $this->assertSame(6.0, (float) $movement->quantity);
        $this->assertSame(2.0, (float) $movement->unit_cost);
        $this->assertSame(12.0, (float) $movement->total_cost);
        $balance = DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $beans['warehouseId'])->where('inventory_item_id', $beans['itemId'])->first();
        $this->assertSame(94.0, (float) $balance->quantity_on_hand);

        // WAC-costed COGS on the order.
        $orderRow = DB::table('orders')->where('id', $orderId)->first();
        $this->assertSame(12.0, (float) $orderRow->cogs_total);
        $this->assertGreaterThan(0.0, (float) $orderRow->cogs_total);

        // A single balanced journal entry with Dr COGS(5000) / Cr Inventory(1100) 12.00.
        $entries = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->where('source_event', 'POS_ORDER_PAID')->get();
        $this->assertCount(1, $entries, 'Exactly one journal entry must be posted for this sale.');
        $entry = $entries->first();
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $this->assertSame(round((float) $lines->sum('debit'), 2), round((float) $lines->sum('credit'), 2), 'Debit must equal credit.');
        $cogsAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5000')->value('id');
        $inventoryAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id');
        $this->assertSame(12.0, (float) $lines->firstWhere('financial_account_id', $cogsAccountId)?->debit);
        $this->assertSame(12.0, (float) $lines->firstWhere('financial_account_id', $inventoryAccountId)?->credit);

        // Idempotent replay: no duplicate consumption, no duplicate journal.
        $this->postJson("/api/v1/orders/{$orderId}/pay", [
            'method' => 'cash', 'amount' => $total, 'idempotencyKey' => 'e2e-tracking-pay-1',
        ], $headers)->assertOk();
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $beans['itemId'])->count());
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
    }

    private function stockIn(int $tenant, int $branchId, array $headers, string $unitCost, string $quantity): array
    {
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branchId}-MAIN")->value('id');
        $itemId = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'حبوب اختبار', 'nameEn' => 'E2E Test Beans '.uniqid(), 'sku' => 'E2E-TEST-'.uniqid(),
            'itemType' => 'raw_material', 'unit' => 'kg', 'minimumStock' => '1.000', 'reorderLevel' => '1.000', 'latestUnitCost' => $unitCost, 'warehouseIds' => [$warehouseId], 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');

        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $warehouseId, 'itemId' => $itemId, 'type' => 'stock_in', 'quantity' => $quantity, 'unitCost' => $unitCost, 'reason' => 'E2E test opening stock',
        ], $headers)->assertCreated();

        return ['itemId' => $itemId, 'warehouseId' => $warehouseId];
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function downtownBranchId(int $tenantId): int
    {
        return (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = 'e2e-tracking-test-token';
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'e2e-tracking-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
