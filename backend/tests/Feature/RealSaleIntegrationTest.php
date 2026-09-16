<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use App\Services\PosInventoryWarehouseResolver;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RealSaleIntegrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_payment_summary_blocks_an_inventory_sale_without_an_active_branch_main_warehouse(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        DB::table('warehouses')
            ->where('tenant_id', $scenario['tenant'])
            ->where('branch_id', DB::table('orders')->where('id', $scenario['orderId'])->value('branch_id'))
            ->update(['is_active' => false]);

        $summary = $this->getJson("/api/v1/orders/{$scenario['orderId']}/payment-summary", $scenario['headers'])
            ->assertOk()
            ->json('data');

        $this->assertFalse($summary['canPay']);
        $this->assertSame('WAREHOUSE_NOT_CONFIGURED', $summary['blockerCode']);
        $this->assertSame(
            'No active branch-main warehouse is configured. Configure one before paying.',
            $summary['blockedReason'],
        );
    }

    public function test_payment_summary_blocks_an_inventory_sale_with_ambiguous_branch_main_warehouses(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        $branchId = (int) DB::table('orders')->where('id', $scenario['orderId'])->value('branch_id');
        DB::table('warehouses')->insert([
            'tenant_id' => $scenario['tenant'],
            'branch_id' => $branchId,
            'name' => 'Duplicate Main Store',
            'code' => 'DUPLICATE-MAIN-'.str()->random(8),
            'type' => 'branch_main',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $summary = $this->getJson("/api/v1/orders/{$scenario['orderId']}/payment-summary", $scenario['headers'])
            ->assertOk()
            ->json('data');

        $this->assertFalse($summary['canPay']);
        $this->assertSame('WAREHOUSE_CONFIGURATION_AMBIGUOUS', $summary['blockerCode']);
        $this->assertSame(
            'Multiple active branch-main warehouses are configured. Keep exactly one active main warehouse for this branch before paying.',
            $summary['blockedReason'],
        );
    }

    public function test_payment_summary_does_not_require_a_warehouse_for_an_untracked_order(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        DB::table('products')->where('tenant_id', $scenario['tenant'])->where('id', $scenario['productId'])->update([
            'is_stock_tracked' => false,
        ]);
        DB::table('warehouses')
            ->where('tenant_id', $scenario['tenant'])
            ->where('branch_id', DB::table('orders')->where('id', $scenario['orderId'])->value('branch_id'))
            ->update(['is_active' => false]);

        $summary = $this->getJson("/api/v1/orders/{$scenario['orderId']}/payment-summary", $scenario['headers'])
            ->assertOk()
            ->json('data');

        $this->assertTrue($summary['canPay']);
        $this->assertNull($summary['blockerCode']);
        $this->assertNull($summary['blockedReason']);
    }

    public function test_payment_summary_remains_payable_with_one_configured_branch_main_warehouse_and_has_no_side_effects(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        $orderBefore = (array) DB::table('orders')->where('id', $scenario['orderId'])->first();
        $countsBefore = [
            'payments' => DB::table('payments')->where('tenant_id', $scenario['tenant'])->count(),
            'movements' => DB::table('stock_movements')->where('tenant_id', $scenario['tenant'])->count(),
            'consumptions' => DB::table('sale_consumptions')->where('tenant_id', $scenario['tenant'])->count(),
            'journals' => DB::table('journal_entries')->where('tenant_id', $scenario['tenant'])->count(),
        ];

        $summary = $this->getJson("/api/v1/orders/{$scenario['orderId']}/payment-summary", $scenario['headers'])
            ->assertOk()
            ->json('data');

        $this->assertTrue($summary['canPay']);
        $this->assertNull($summary['blockerCode']);
        $this->assertNull($summary['blockedReason']);
        $this->assertSame($orderBefore, (array) DB::table('orders')->where('id', $scenario['orderId'])->first());
        $this->assertSame($countsBefore, [
            'payments' => DB::table('payments')->where('tenant_id', $scenario['tenant'])->count(),
            'movements' => DB::table('stock_movements')->where('tenant_id', $scenario['tenant'])->count(),
            'consumptions' => DB::table('sale_consumptions')->where('tenant_id', $scenario['tenant'])->count(),
            'journals' => DB::table('journal_entries')->where('tenant_id', $scenario['tenant'])->count(),
        ]);
    }

    public function test_payment_still_rejects_an_invalid_warehouse_configuration_at_apply_time(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        DB::table('warehouses')
            ->where('tenant_id', $scenario['tenant'])
            ->where('branch_id', DB::table('orders')->where('id', $scenario['orderId'])->value('branch_id'))
            ->update(['is_active' => false]);

        $this->postJson("/api/v1/orders/{$scenario['orderId']}/pay", [
            'method' => 'cash',
            'amount' => $scenario['total'],
            'idempotencyKey' => 'preflight-apply-time',
        ], $scenario['headers'])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'WAREHOUSE_NOT_CONFIGURED');

        $this->assertSame('unpaid', DB::table('orders')->where('id', $scenario['orderId'])->value('payment_status'));
        $this->assertSame(0, DB::table('payments')->where('tenant_id', $scenario['tenant'])->where('order_id', $scenario['orderId'])->count());
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $scenario['tenant'])->where('type', 'sale_consumption')->count());
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $scenario['tenant'])->where('source_id', $scenario['orderId'])->count());
    }

    public function test_payment_preflight_is_scoped_to_the_order_tenant_and_branch(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        $branchId = (int) DB::table('orders')->where('id', $scenario['orderId'])->value('branch_id');
        $otherBranch = (int) $this->postJson('/api/v1/cafe-configuration/branches', [
            'name' => 'Other Branch',
            'timezone' => 'Asia/Damascus',
        ], $scenario['headers'])->assertCreated()->json('data.id');
        DB::table('warehouses')->insert([
            'tenant_id' => $scenario['tenant'],
            'branch_id' => $otherBranch,
            'name' => 'Other Branch Duplicate',
            'code' => 'OTHER-DUPLICATE-'.str()->random(8),
            'type' => 'branch_main',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $foreignTenant = $this->tenantContext();
        DB::table('warehouses')->insert([
            'tenant_id' => $foreignTenant['tenant'],
            'branch_id' => $branchId,
            'name' => 'Foreign Tenant Main Store',
            'code' => 'FOREIGN-MAIN-'.str()->random(8),
            'type' => 'branch_main',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $summary = $this->getJson("/api/v1/orders/{$scenario['orderId']}/payment-summary", $scenario['headers'])
            ->assertOk()
            ->json('data');

        $this->assertTrue($summary['canPay']);
        $this->assertNull($summary['blockerCode']);
    }

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

    /**
     * `allow_negative_stock_on_sale` defaults to true, so a POS sale must
     * complete even when it drives stock negative — the client's explicit
     * requirement. WAC/COGS must keep using the existing average_unit_cost
     * basis (never zeroed/fabricated), and the sale remains fully auditable
     * (movement + journal entries recorded as normal, just against a
     * negative resulting balance).
     */
    public function test_real_published_sale_completes_and_goes_negative_when_stock_is_insufficient(): void
    {
        $scenario = $this->publishedOrderScenario('100.000');
        $tenant = $scenario['tenant'];
        $orderId = $scenario['orderId'];

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $scenario['total'], 'idempotencyKey' => 'phase-three-insufficient-stock'], $scenario['headers'])
            ->assertOk()->assertJsonPath('data.payment.status', 'completed');

        $this->assertSame('paid', DB::table('orders')->where('id', $orderId)->value('payment_status'));
        $this->assertSame(1, DB::table('payments')->where('tenant_id', $tenant)->where('order_id', $orderId)->count());

        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $scenario['materialId'])->sole();
        $this->assertSame('250.000', $movement->quantity);
        $this->assertSame('100.000', $movement->quantity_before);
        $this->assertSame('-150.000', $movement->quantity_after);
        // Same 0.0200/g WAC the opening stock_in set — proves cost is read
        // from the existing average, never zeroed or fabricated for the
        // negative-stock sale.
        $this->assertSame('5.00', $movement->total_cost);
        $this->assertSame('-150.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $scenario['warehouseId'])->where('inventory_item_id', $scenario['materialId'])->value('quantity_on_hand'));
        $this->assertSame('5.00', DB::table('orders')->where('id', $orderId)->value('cogs_total'));

        $journal = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->where('source_event', 'POS_ORDER_PAID')->sole();
        $this->assertSame('posted', $journal->status);
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journal->id)->get()->keyBy('financial_account_id');
        $this->assertSame('5.00', $lines[(int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5000')->value('id')]->debit);
        $this->assertSame('5.00', $lines[(int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id')]->credit);
    }

    public function test_legacy_unpaid_order_is_bound_to_the_effective_main_warehouse_when_paid(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        DB::table('orders')->where('id', $scenario['orderId'])->update(['warehouse_id' => null]);

        $this->postJson("/api/v1/orders/{$scenario['orderId']}/pay", [
            'method' => 'cash',
            'amount' => $scenario['total'],
            'idempotencyKey' => 'legacy-order-warehouse-bind',
        ], $scenario['headers'])->assertOk();

        $this->assertSame(
            $scenario['warehouseId'],
            (int) DB::table('orders')->where('id', $scenario['orderId'])->value('warehouse_id'),
        );
        $this->assertSame(
            $scenario['warehouseId'],
            (int) DB::table('stock_movements')->where('tenant_id', $scenario['tenant'])->where('type', 'sale_consumption')->value('warehouse_id'),
        );
    }

    /**
     * The tenant off-switch for the policy above: with
     * allow_negative_stock_on_sale explicitly disabled, POS sale consumption
     * must still block on insufficient stock exactly like every other
     * outbound movement (transfers, manual sales-invoice consumption) always
     * has — proving the new flag is additive, not a blanket change to
     * InventoryPostingService::post().
     */
    public function test_real_published_sale_still_blocks_on_insufficient_stock_when_tenant_policy_disables_negative_stock(): void
    {
        $scenario = $this->publishedOrderScenario('100.000');
        $tenant = $scenario['tenant'];
        $orderId = $scenario['orderId'];
        DB::table('tenant_settings')->updateOrInsert(
            ['tenant_id' => $tenant],
            ['settings' => json_encode(['allow_negative_stock_on_sale' => false]), 'updated_at' => now(), 'created_at' => now()],
        );

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $scenario['total'], 'idempotencyKey' => 'phase-three-insufficient-stock-blocked'], $scenario['headers'])
            ->assertUnprocessable()->assertJsonValidationErrors('quantity');

        $this->assertSame('unpaid', DB::table('orders')->where('id', $orderId)->value('payment_status'));
        $this->assertNull(DB::table('orders')->where('id', $orderId)->value('cogs_total'));
        $this->assertSame(0, DB::table('payments')->where('tenant_id', $tenant)->where('order_id', $orderId)->count());
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->count());
        $this->assertSame('100.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $scenario['warehouseId'])->where('inventory_item_id', $scenario['materialId'])->value('quantity_on_hand'));
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
    }

    public function test_published_sale_rejects_a_material_not_assigned_to_its_branch_main_warehouse(): void
    {
        $scenario = $this->publishedOrderScenario('1000.000');
        DB::table('inventory_item_warehouses')
            ->where('tenant_id', $scenario['tenant'])
            ->where('inventory_item_id', $scenario['materialId'])
            ->where('warehouse_id', $scenario['warehouseId'])
            ->delete();

        $this->postJson("/api/v1/orders/{$scenario['orderId']}/pay", [
            'method' => 'cash',
            'amount' => $scenario['total'],
            'idempotencyKey' => 'phase-three-unassigned-material',
        ], $scenario['headers'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.warehouseId.0', 'The inventory item is not assigned to the selected warehouse.');

        $this->assertSame('unpaid', DB::table('orders')->where('id', $scenario['orderId'])->value('payment_status'));
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $scenario['tenant'])->where('type', 'sale_consumption')->count());
    }

    /**
     * Full client acceptance flow for Order → Warehouse binding combined with
     * negative-stock POS sales: a branch with a *second* warehouse besides
     * its auto-provisioned main one, the order explicitly pinned to that
     * second warehouse at creation time (not the branch-guess fallback), a
     * product with no required modifiers, stock left below the required
     * quantity, and payment must still succeed — proving the explicitly
     * selected warehouse (and never the branch's other warehouse) is the one
     * that receives consumption, and that shift/payment linkage survives the
     * whole flow.
     */
    public function test_real_sale_automatically_uses_configured_branch_bar_with_negative_stock_and_correct_linkage(): void
    {
        $context = $this->tenantContext();
        $tenant = $context['tenant'];
        $headers = $context['headers'];

        $branchId = (int) $this->postJson('/api/v1/cafe-configuration/branches', ['name' => 'Multi-Warehouse Branch', 'timezone' => 'Asia/Damascus'], $headers)->assertCreated()->json('data.id');
        app(FinancialSetupService::class)->ensureBranchPosWarehouse($tenant, $branchId, $context['owner']);
        $mainWarehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('code', "BR-{$branchId}-MAIN")->value('id');
        $secondWarehouseId = (int) DB::table('branches')->where('id', $branchId)->value('pos_inventory_warehouse_id');
        $this->assertSame('bar', DB::table('warehouses')->where('id', $secondWarehouseId)->value('type'));

        $materialId = (int) $this->postJson('/api/v1/inventory/items', ['nameAr' => 'E2E Beans', 'nameEn' => 'E2E Beans', 'sku' => 'E2E-BEANS', 'itemType' => 'raw_material', 'unit' => 'g', 'minimumStock' => '0.000', 'reorderLevel' => '0.000', 'latestUnitCost' => '0.0200', 'warehouseIds' => [$mainWarehouseId, $secondWarehouseId], 'isActive' => true], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/inventory/items/{$materialId}/unit-conversions", ['sourceUnit' => 'kg', 'targetUnit' => 'g', 'factor' => '1000.000000', 'isActive' => true], $headers)->assertCreated();
        // Below the recipe's required 250g — proves negative-stock sales work on an explicitly-selected non-default warehouse too.
        $this->postJson('/api/v1/inventory/movements', ['warehouseId' => $mainWarehouseId, 'branchId' => $branchId, 'itemId' => $materialId, 'type' => 'stock_in', 'quantity' => '100.000', 'unit' => 'g', 'unitCost' => '0.0200', 'idempotencyKey' => 'e2e-main-opening-stock'], $headers)->assertCreated();
        DB::table('stock_balances')->updateOrInsert(
            ['tenant_id' => $tenant, 'warehouse_id' => $secondWarehouseId, 'inventory_item_id' => $materialId],
            ['quantity_on_hand' => '0.000', 'reserved_quantity' => '0.000', 'average_unit_cost' => '0.0200', 'updated_at' => now(), 'created_at' => now()],
        );

        $category = (int) $this->postJson('/api/v1/admin/catalog/categories', ['name' => 'Coffee'], $headers)->assertCreated()->json('data.id');
        $reportingCategory = (int) $this->postJson('/api/v1/admin/catalog/reporting-categories', ['name' => 'Beverages', 'nameAr' => 'Beverages', 'nameEn' => 'Beverages', 'code' => 'BEVERAGES'], $headers)->assertCreated()->json('data.id');
        $station = (int) $this->postJson('/api/v1/admin/catalog/kitchen-stations', ['name' => 'Coffee Bar', 'nameAr' => 'Coffee Bar', 'nameEn' => 'Coffee Bar', 'code' => 'COFFEE-BAR', 'branchId' => $branchId], $headers)->assertCreated()->json('data.id');
        // No modifier groups attached: exercises the "product with no required modifiers" path.
        $productId = (int) $this->postJson('/api/v1/admin/catalog/products', ['name' => 'E2E Latte', 'nameAr' => 'E2E Latte', 'nameEn' => 'E2E Latte', 'categoryId' => $category, 'reportingCategoryId' => $reportingCategory, 'kitchenStationId' => $station, 'productType' => 'standard', 'isStockTracked' => true, 'variants' => [['name' => 'Regular', 'basePrice' => '10.00', 'costPrice' => '0.00', 'isDefault' => true, 'isActive' => true, 'sortOrder' => 0]]], $headers)->assertCreated()->json('data.id');
        $variantId = (int) DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $productId)->value('id');
        $this->putJson("/api/v1/admin/catalog/product-variants/{$variantId}/recipe", ['components' => [['materialId' => $materialId, 'quantity' => '0.020', 'unitCode' => 'kg', 'sortOrder' => 0]]], $headers)->assertOk();

        $menuId = (int) $this->postJson('/api/v1/admin/menus', ['name' => 'E2E Menu', 'nameAr' => 'E2E Menu', 'nameEn' => 'E2E Menu', 'status' => 'draft'], $headers)->assertCreated()->json('data.id');
        $sectionId = (int) $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Coffee', 'nameAr' => 'Coffee', 'nameEn' => 'Coffee', 'sortOrder' => 0], $headers)->assertCreated()->json('data.id');
        $placementId = (int) $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $productId, 'sortOrder' => 0, 'isVisible' => true], $headers)->assertCreated()->json('data.id');
        $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branchId, 'channel' => 'pos', 'assignments' => [['menuId' => $menuId, 'priority' => 0, 'isActive' => true]]], $headers)->assertOk();
        $versionId = (int) $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $branchId, 'channel' => 'pos', 'menuIds' => [$menuId]], $headers)->assertOk()->assertJsonPath('data.published', true)->json('data.version.id');

        $shiftId = (int) $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 0], $headers)->assertCreated()->json('data.id');
        $order = $this->postJson('/api/v1/orders', [
            'branchId' => $branchId,
            'shiftId' => $shiftId,
            'orderType' => 'takeaway',
            'publishedMenuVersionId' => $versionId,
            'items' => [['productId' => $productId, 'placementId' => $placementId, 'variantId' => $variantId, 'quantity' => 1]],
        ], $headers)->assertCreated();
        $orderId = (int) $order->json('data.id');
        $total = (string) $order->json('data.totals.total');

        $this->assertSame($secondWarehouseId, (int) DB::table('orders')->where('id', $orderId)->value('warehouse_id'));
        $this->assertSame($secondWarehouseId, $order->json('data.warehouseId'));

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $total, 'idempotencyKey' => 'e2e-explicit-warehouse-negative-stock'], $headers)
            ->assertOk()->assertJsonPath('data.payment.status', 'completed');

        $this->assertSame('paid', DB::table('orders')->where('id', $orderId)->value('payment_status'));
        $payment = DB::table('payments')->where('tenant_id', $tenant)->where('order_id', $orderId)->sole();
        $this->assertSame($shiftId, (int) $payment->shift_id);

        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $materialId)->sole();
        $this->assertSame($secondWarehouseId, (int) $movement->warehouse_id);
        $this->assertSame('20.000', $movement->quantity);
        $this->assertSame('0.000', $movement->quantity_before);
        $this->assertSame('-20.000', $movement->quantity_after);
        $this->assertSame('0.40', $movement->total_cost);

        // Consumption landed on the selected second warehouse only — the
        // branch's main warehouse (never referenced by this order) must be
        // untouched.
        $this->assertSame('-20.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $secondWarehouseId)->where('inventory_item_id', $materialId)->value('quantity_on_hand'));
        $this->assertSame('100.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $mainWarehouseId)->where('inventory_item_id', $materialId)->value('quantity_on_hand'));

        $this->assertSame('0.40', DB::table('orders')->where('id', $orderId)->value('cogs_total'));

        $journal = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->where('source_event', 'POS_ORDER_PAID')->sole();
        $this->assertSame('posted', $journal->status);
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journal->id)->get()->keyBy('financial_account_id');
        $this->assertSame('0.40', $lines[(int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5000')->value('id')]->debit);
        $this->assertSame('0.40', $lines[(int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id')]->credit);

        $transferId = (int) $this->postJson('/api/v1/inventory/transfers', [
            'sourceWarehouseId' => $mainWarehouseId,
            'destinationWarehouseId' => $secondWarehouseId,
            'idempotencyKey' => 'e2e-replenish-bar',
            'lines' => [['itemId' => $materialId, 'requestedQuantity' => '0.020', 'unit' => 'kg']],
        ], $headers)->assertCreated()->json('data.id');
        foreach (['submit', 'approve', 'dispatch'] as $action) {
            $this->postJson("/api/v1/inventory/transfers/{$transferId}/{$action}", ['idempotencyKey' => "e2e-replenish-bar-{$action}"], $headers)->assertOk();
        }
        $this->postJson("/api/v1/inventory/transfers/{$transferId}/receive", [
            'idempotencyKey' => 'e2e-replenish-bar-receive',
            'lines' => [['itemId' => $materialId, 'receivedQuantity' => '0.020', 'unit' => 'kg']],
        ], $headers)->assertOk()->assertJsonPath('data.status', 'received');

        $this->assertSame('80.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $mainWarehouseId)->where('inventory_item_id', $materialId)->value('quantity_on_hand'));
        $this->assertSame('0.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $secondWarehouseId)->where('inventory_item_id', $materialId)->value('quantity_on_hand'));
    }

    public function test_owner_branch_creation_provisions_only_main_and_uses_it_as_the_automatic_pos_warehouse(): void
    {
        $context = $this->tenantContext();
        $payload = ['name' => 'Airport', 'timezone' => 'Asia/Damascus'];
        $created = $this->postJson('/api/v1/cafe-configuration/branches', $payload, $context['headers'])->assertCreated()
            ->assertJsonPath('data.currency', 'SYP')
            ->assertJsonPath('data.isActive', true);
        $branchId = (int) $created->json('data.id');

        $this->assertSame($context['tenant'], (int) DB::table('branches')->where('id', $branchId)->value('tenant_id'));
        $this->assertSame(1, DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('branch_id', $branchId)->where('code', "BR-{$branchId}-MAIN")->where('type', 'branch_main')->where('is_active', true)->count());
        $this->assertSame(0, DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('branch_id', $branchId)->where('type', 'bar')->count());
        $this->assertNull(DB::table('branches')->where('id', $branchId)->value('pos_inventory_warehouse_id'));
        $this->assertSame(
            (int) DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('code', "BR-{$branchId}-MAIN")->value('id'),
            (int) app(PosInventoryWarehouseResolver::class)->forBranch($context['tenant'], $branchId)->id,
        );
        $this->postJson('/api/v1/cafe-configuration/branches', $payload, $this->headersForRole($context['tenant'], 'manager'))->assertForbidden();
        $this->postJson('/api/v1/cafe-configuration/branches', $payload, $this->headersForRole($context['tenant'], 'cashier'))->assertForbidden();

        $legacyBranch = DB::table('branches')->insertGetId(['tenant_id' => $context['tenant'], 'name' => 'Legacy Branch', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $setup = app(FinancialSetupService::class);
        $setup->ensureBranchMainWarehouse($context['tenant'], $legacyBranch, $context['owner']);
        $setup->ensureBranchMainWarehouse($context['tenant'], $legacyBranch, $context['owner']);
        $setup->ensureBranchPosWarehouse($context['tenant'], $legacyBranch, $context['owner']);
        $setup->ensureBranchPosWarehouse($context['tenant'], $legacyBranch, $context['owner']);

        $warehouse = DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('code', "BR-{$legacyBranch}-MAIN")->sole();
        $this->assertSame($legacyBranch, (int) $warehouse->branch_id);
        $this->assertSame('branch_main', $warehouse->type);
        $this->assertSame(1, DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('code', "BR-{$legacyBranch}-MAIN")->count());
        $this->assertSame(1, DB::table('warehouses')->where('tenant_id', $context['tenant'])->where('code', "BR-{$legacyBranch}-BAR")->count());
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
        $warehouseId = (int) app(PosInventoryWarehouseResolver::class)->forBranch($tenant, $branchId)->id;

        $materialId = (int) $this->postJson('/api/v1/inventory/items', ['nameAr' => 'Phase Three Beans', 'nameEn' => 'Phase Three Beans', 'sku' => 'P3-BEANS', 'itemType' => 'raw_material', 'unit' => 'g', 'minimumStock' => '0.000', 'reorderLevel' => '0.000', 'latestUnitCost' => '0.0200', 'warehouseIds' => [$warehouseId], 'isActive' => true], $headers)
            ->assertCreated()
            ->assertJsonPath('data.warehouseIds.0', $warehouseId)
            ->json('data.id');
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
