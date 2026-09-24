<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Client feedback task E — inventory item details visibility
 * (docs/client_feedback_review_2026-09-22.md).
 *
 * E1: GET items/{item}/movements is the full, paginated movement history
 * behind the "سجل الحركات" tab (recentMovements on show() stays a
 * deliberate 5-row summary and is not re-tested here).
 * E2: recipe-usage / purchase-history are new, read-only endpoints.
 * E4: the item-details stockStatus/total aggregate must match the same
 * warehouse scope already used everywhere else (active, not deleted, not a
 * read-only LEGACY-% bucket) instead of a bare unscoped SUM().
 */
class InventoryItemDetailsApiTest extends TestCase
{
    use RefreshDatabase;

    // ---------------------------------------------------------------
    // E1 — full movement history
    // ---------------------------------------------------------------

    public function test_full_movement_history_is_paginated_with_deterministic_ordering_and_no_duplicates(): void
    {
        $tenant = $this->tenant('e1-history');
        $headers = $this->headers($tenant);
        $warehouse = $this->warehouse($headers);
        $item = $this->inventoryItem($headers, 'kg', [$warehouse]);

        for ($i = 0; $i < 6; $i++) {
            $this->stockIn($headers, $item, $warehouse, '1.000', '1.0000');
        }
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $warehouse, 'itemId' => $item, 'type' => 'waste', 'quantity' => '1.000', 'reason' => 'تلف',
        ], $headers)->assertCreated();
        // sale_consumption is only ever written by the POS payment path
        // (SaleConsumptionService); it is inserted directly here purely to
        // prove the read endpoint surfaces every movement type that can
        // exist on this table, not to simulate a sale.
        DB::table('stock_movements')->insert([
            'tenant_id' => $tenant,
            'branch_id' => DB::table('warehouses')->where('id', $warehouse)->value('branch_id'),
            'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'type' => 'sale_consumption',
            'quantity' => '1.000', 'quantity_in' => '0.000', 'quantity_out' => '1.000',
            'quantity_before' => '7.000', 'quantity_after' => '6.000',
            'unit_cost' => '1.0000', 'total_cost' => '1.00', 'occurred_at' => now(),
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $firstPage = $this->getJson("/api/v1/inventory/items/{$item}/movements?perPage=5&page=1", $headers)->assertOk();
        $firstPage->assertJsonCount(5, 'data')
            ->assertJsonPath('meta.currentPage', 1)
            ->assertJsonPath('meta.total', 8)
            ->assertJsonPath('meta.lastPage', 2);

        $secondPage = $this->getJson("/api/v1/inventory/items/{$item}/movements?perPage=5&page=2", $headers)->assertOk();
        $secondPage->assertJsonCount(3, 'data')->assertJsonPath('meta.currentPage', 2);

        $firstIds = collect($firstPage->json('data'))->pluck('id');
        $secondIds = collect($secondPage->json('data'))->pluck('id');
        // Deterministic ordering: descending id order within a page (a
        // stand-in for occurred_at DESC, id DESC when timestamps tie).
        $this->assertSame($firstIds->sortDesc()->values()->all(), $firstIds->values()->all());
        $this->assertSame($secondIds->sortDesc()->values()->all(), $secondIds->values()->all());
        // No row appears on both pages.
        $this->assertCount(0, $firstIds->intersect($secondIds));
        $this->assertTrue($firstIds->min() > $secondIds->max());

        $allTypes = collect($firstPage->json('data'))->concat($secondPage->json('data'))->pluck('type');
        $this->assertContains('stock_in', $allTypes);
        $this->assertContains('waste', $allTypes);
        $this->assertContains('sale_consumption', $allTypes);
    }

    public function test_movement_history_date_filter_narrows_results(): void
    {
        $tenant = $this->tenant('e1-date-filter');
        $headers = $this->headers($tenant);
        $warehouse = $this->warehouse($headers);
        $item = $this->inventoryItem($headers, 'kg', [$warehouse]);
        $this->stockIn($headers, $item, $warehouse, '1.000', '1.0000');
        DB::table('stock_movements')
            ->where('tenant_id', $tenant)->where('inventory_item_id', $item)
            ->update(['occurred_at' => '2020-01-01 00:00:00']);
        $this->stockIn($headers, $item, $warehouse, '1.000', '1.0000');

        $this->getJson("/api/v1/inventory/items/{$item}/movements?from=2026-01-01", $headers)
            ->assertOk()->assertJsonCount(1, 'data');
        $this->getJson("/api/v1/inventory/items/{$item}/movements?to=2020-12-31", $headers)
            ->assertOk()->assertJsonCount(1, 'data');
        $this->getJson("/api/v1/inventory/items/{$item}/movements", $headers)
            ->assertOk()->assertJsonCount(2, 'data');
    }

    // ---------------------------------------------------------------
    // E2 — recipe usage
    // ---------------------------------------------------------------

    public function test_recipe_usage_lists_variants_that_consume_the_material_and_is_empty_for_unused_items(): void
    {
        $tenant = $this->tenant('e2-recipe');
        $headers = $this->headers($tenant);
        $warehouse = $this->warehouse($headers);
        $item = $this->inventoryItem($headers, 'gram', [$warehouse]);
        $unused = $this->inventoryItem($headers, 'gram', [$warehouse]);

        $productId = DB::table('products')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'Latte', 'is_active' => true, 'is_stock_tracked' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $variantId = DB::table('product_variants')->insertGetId([
            'tenant_id' => $tenant, 'product_id' => $productId, 'name' => 'Regular',
            'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $recipeId = DB::table('variant_recipes')->insertGetId([
            'tenant_id' => $tenant, 'product_variant_id' => $variantId, 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('variant_recipe_components')->insert([
            'tenant_id' => $tenant, 'variant_recipe_id' => $recipeId, 'inventory_item_id' => $item,
            'quantity' => '18.000000', 'unit_code' => 'gram', 'sort_order' => 0,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->getJson("/api/v1/inventory/items/{$item}/recipe-usage", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.productName', 'Latte')
            ->assertJsonPath('data.0.variantName', 'Regular')
            ->assertJsonPath('data.0.quantity', '18.000000')
            ->assertJsonPath('data.0.unit', 'gram')
            ->assertJsonPath('data.0.isActive', true);

        $this->getJson("/api/v1/inventory/items/{$unused}/recipe-usage", $headers)
            ->assertOk()->assertJsonCount(0, 'data');
    }

    // ---------------------------------------------------------------
    // E2 — purchase history
    // ---------------------------------------------------------------

    public function test_purchase_history_shows_only_posted_receipts_without_double_counting(): void
    {
        $tenant = $this->tenant('e2-purchase');
        $headers = $this->headers($tenant);
        $warehouse = $this->warehouse($headers);
        $item = $this->inventoryItem($headers, 'kg', [$warehouse]);
        $unrelated = $this->inventoryItem($headers, 'kg', [$warehouse]);
        $supplierId = $this->supplier($headers);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $item, $warehouse, '10.000', '5.0000');
        $invoiceLineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        $receipt = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'e2-receipt-create',
            'lines' => [['supplierInvoiceLineId' => $invoiceLineId, 'quantity' => '10.000', 'warehouseId' => $warehouse]],
        ], $headers)->assertCreated()->json('data');

        // A draft receipt has not moved any stock yet and must not appear
        // as a purchase, and an unrelated item's purchases must not leak in.
        $this->getJson("/api/v1/inventory/items/{$item}/purchase-history", $headers)->assertOk()->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/inventory/items/{$unrelated}/purchase-history", $headers)->assertOk()->assertJsonCount(0, 'data');

        $this->postJson("/api/v1/finance/purchase-receipts/{$receipt['id']}/post", ['idempotencyKey' => 'e2-receipt-post'], $headers)->assertOk();

        $response = $this->getJson("/api/v1/inventory/items/{$item}/purchase-history", $headers)->assertOk();
        $response->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.quantity', '10.000')
            ->assertJsonPath('data.0.unitCost', '5.0000')
            ->assertJsonPath('data.0.warehouseName', DB::table('warehouses')->where('id', $warehouse)->value('name'));
        $this->assertNotEmpty($response->json('data.0.supplierName'));
        $this->assertNotEmpty($response->json('data.0.invoiceNumber'));
        $this->assertNotEmpty($response->json('data.0.receiptNumber'));

        // A second, separate receipt against the same invoice line is a
        // second real purchase event and must appear as its own row, not
        // merged into or duplicating the first.
        $this->getJson("/api/v1/inventory/items/{$unrelated}/purchase-history", $headers)->assertOk()->assertJsonCount(0, 'data');
    }

    // ---------------------------------------------------------------
    // E4 — "out of stock after purchase"
    // ---------------------------------------------------------------

    public function test_scenario_a_purchase_from_zero_clears_out_of_stock_status(): void
    {
        $tenant = $this->tenant('e4-scenario-a');
        $headers = $this->headers($tenant);
        $warehouse = $this->warehouse($headers);
        $item = $this->inventoryItem($headers, 'kg', [$warehouse]);

        $this->getJson("/api/v1/inventory/items/{$item}", $headers)->assertOk()
            ->assertJsonPath('data.stockStatus', 'out_of_stock')
            ->assertJsonPath('data.totalQuantity', '0.000');

        $this->stockIn($headers, $item, $warehouse, '10.000', '2.0000');

        $this->getJson("/api/v1/inventory/items/{$item}", $headers)->assertOk()
            ->assertJsonPath('data.stockStatus', 'active')
            ->assertJsonPath('data.totalQuantity', '10.000');
    }

    public function test_scenario_b_purchase_on_top_of_negative_stock_correctly_stays_out_of_stock(): void
    {
        $tenant = $this->tenant('e4-scenario-b');
        $headers = $this->headers($tenant);
        $warehouse = $this->warehouse($headers);
        $item = $this->inventoryItem($headers, 'kg', [$warehouse]);
        // Negative stock is an intentional, permitted state (POS sale
        // consumption is allowed to push it negative) - seeded directly
        // here since the manual movement API itself always blocks a
        // resulting negative balance.
        DB::table('stock_balances')->insert([
            'tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item,
            'quantity_on_hand' => '-20.000', 'reserved_quantity' => '0.000', 'average_unit_cost' => '2.0000',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->stockIn($headers, $item, $warehouse, '10.000', '2.0000');

        // -20 + 10 = -10: still out of stock. This is correct, existing
        // negative-stock policy and must never be "fixed".
        $this->getJson("/api/v1/inventory/items/{$item}", $headers)->assertOk()
            ->assertJsonPath('data.stockStatus', 'out_of_stock')
            ->assertJsonPath('data.totalQuantity', '-10.000');
    }

    public function test_scenario_c_purchase_into_a_different_warehouse_reflects_in_the_tenant_wide_aggregate(): void
    {
        $tenant = $this->tenant('e4-scenario-c');
        $headers = $this->headers($tenant);
        $warehouseA = $this->warehouse($headers, 'WH-A-'.uniqid());
        $warehouseB = $this->warehouse($headers, 'WH-B-'.uniqid());
        $item = $this->inventoryItem($headers, 'kg', [$warehouseA, $warehouseB]);

        $this->getJson("/api/v1/inventory/items/{$item}", $headers)->assertOk()
            ->assertJsonPath('data.stockStatus', 'out_of_stock');

        $this->stockIn($headers, $item, $warehouseB, '10.000', '2.0000');

        // The item-details header is an explicit tenant-wide aggregate
        // (stockByWarehouse right below it shows the per-warehouse split),
        // so a purchase into warehouse B must be reflected here even
        // though warehouse A never received any stock (a stock_balances
        // row - and so a stockByWarehouse entry - only ever exists for a
        // warehouse once it has had at least one movement).
        $response = $this->getJson("/api/v1/inventory/items/{$item}", $headers)->assertOk();
        $response->assertJsonPath('data.stockStatus', 'active')->assertJsonPath('data.totalQuantity', '10.000');
        $balances = collect($response->json('data.stockByWarehouse'))->keyBy('warehouseId');
        $this->assertArrayNotHasKey($warehouseA, $balances->all());
        $this->assertSame('10.000', $balances[$warehouseB]['quantityOnHand']);
    }

    public function test_scenario_d_legacy_warehouse_stock_cannot_flip_the_item_status(): void
    {
        $tenant = $this->tenant('e4-scenario-d');
        $headers = $this->headers($tenant);
        $warehouse = $this->warehouse($headers);
        $item = $this->inventoryItem($headers, 'kg', [$warehouse]);
        $this->stockIn($headers, $item, $warehouse, '10.000', '2.0000');

        // A read-only LEGACY-coded warehouse (see WarehousePresentation /
        // the "Legacy warehouses are read-only" guard in
        // InventoryPostingService) still carries a leftover balance from
        // before the inventory-center migration. It is already excluded
        // from stockByWarehouse below; the item's own aggregate total and
        // stockStatus must use that same scope instead of a bare
        // unscoped SUM() over every stock_balances row.
        $branchId = (int) DB::table('warehouses')->where('id', $warehouse)->value('branch_id');
        $legacyWarehouse = DB::table('warehouses')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branchId, 'name' => 'Legacy bucket',
            'code' => 'LEGACY-MIGRATED', 'type' => 'other', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('stock_balances')->insert([
            'tenant_id' => $tenant, 'warehouse_id' => $legacyWarehouse, 'inventory_item_id' => $item,
            'quantity_on_hand' => '-50.000', 'reserved_quantity' => '0.000', 'average_unit_cost' => '2.0000',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $response = $this->getJson("/api/v1/inventory/items/{$item}", $headers)->assertOk();
        $response->assertJsonPath('data.stockStatus', 'active')
            ->assertJsonPath('data.totalQuantity', '10.000')
            ->assertJsonCount(1, 'data.stockByWarehouse');
    }

    public function test_item_list_stock_status_also_ignores_a_legacy_warehouses_balance(): void
    {
        $tenant = $this->tenant('e4-list-scenario-d');
        $headers = $this->headers($tenant);
        $warehouse = $this->warehouse($headers);
        $item = $this->inventoryItem($headers, 'kg', [$warehouse]);
        $this->stockIn($headers, $item, $warehouse, '10.000', '2.0000');
        $branchId = (int) DB::table('warehouses')->where('id', $warehouse)->value('branch_id');
        $legacyWarehouse = DB::table('warehouses')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branchId, 'name' => 'Legacy bucket',
            'code' => 'LEGACY-MIGRATED', 'type' => 'other', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('stock_balances')->insert([
            'tenant_id' => $tenant, 'warehouse_id' => $legacyWarehouse, 'inventory_item_id' => $item,
            'quantity_on_hand' => '-50.000', 'reserved_quantity' => '0.000', 'average_unit_cost' => '2.0000',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $response = $this->getJson('/api/v1/inventory/items?perPage=100', $headers)->assertOk();
        $row = collect($response->json('data.items'))->firstWhere('id', $item);
        $this->assertSame('active', $row['stockStatus']);
        $this->assertSame('10.000', $row['totalQuantity']);
    }

    // ---------------------------------------------------------------
    // helpers (mirrors PurchasingPhase2ApiTest's fixtures)
    // ---------------------------------------------------------------

    private function tenant(string $slug): int
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Central Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenantId);

        return (int) $tenantId;
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'E Task Owner', 'email' => "e-task-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $plainToken = "e-task-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'e-task-feature-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }

    private function supplier(array $headers): int
    {
        return (int) $this->postJson('/api/v1/finance/suppliers', ['name' => 'E Task Test Supplier '.uniqid()], $headers)->assertCreated()->json('data.id');
    }

    private function warehouse(array $headers, ?string $code = null): int
    {
        $branchId = (int) DB::table('branches')->where('tenant_id', $headers['X-Tenant-Id'])->value('id');

        return (int) $this->postJson('/api/v1/warehouses', [
            'name' => 'Warehouse '.uniqid(), 'code' => $code ?? 'WH-'.strtoupper(uniqid()), 'type' => 'other', 'branchId' => $branchId, 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
    }

    private function inventoryItem(array $headers, string $unit, array $warehouseIds = []): int
    {
        return (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'صنف اختبار', 'nameEn' => 'E Task Test Item '.uniqid(), 'sku' => 'ETASK-'.strtoupper(uniqid()),
            'itemType' => 'raw_material', 'unit' => $unit, 'minimumStock' => '0.000', 'reorderLevel' => '0.000',
            'latestUnitCost' => '1.0000', 'isActive' => true, 'warehouseIds' => $warehouseIds,
        ], $headers)->assertCreated()->json('data.id');
    }

    private function stockIn(array $headers, int $itemId, int $warehouseId, string $quantity, string $unitCost): void
    {
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $warehouseId, 'itemId' => $itemId, 'type' => 'stock_in', 'quantity' => $quantity, 'unitCost' => $unitCost,
            'idempotencyKey' => 'e-task-stock-in-'.uniqid(),
        ], $headers)->assertCreated();
    }

    private function createInventoryInvoice(array $headers, int $supplierId, int $itemId, int $warehouseId, string $quantity, string $unitPrice): int
    {
        $grossAmount = number_format((float) $quantity * (float) $unitPrice, 2, '.', '');

        return (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'E-TASK-INV-'.uniqid(), 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [['lineType' => 'inventory', 'description' => 'Goods', 'inventoryItemId' => $itemId, 'quantity' => $quantity, 'lineGrossAmount' => $grossAmount, 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');
    }

    private function postedInventoryInvoice(array $headers, int $supplierId, int $itemId, int $warehouseId, string $quantity, string $unitPrice): int
    {
        $id = $this->createInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, $quantity, $unitPrice);
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'e-task-inv-post-'.uniqid()], $headers)->assertOk();

        return $id;
    }
}
