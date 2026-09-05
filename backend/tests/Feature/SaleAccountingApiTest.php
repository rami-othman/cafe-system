<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Phase 4 — POS sale -> Inventory consumption -> Finance posting.
 *
 * Inventory stays authoritative for consumed quantity/WAC/movement cost
 * (SaleConsumptionService never computes a cost itself, only decides what to
 * consume and where from); AccountingPostingService.postSale() then posts
 * exactly what Inventory and the order snapshot produced. These tests prove
 * the whole chain end to end through the real POS API, the same way
 * PosApiSmokeTest exercises the base checkout flow.
 */
class SaleAccountingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_recipe_based_sale_consumes_inventory_at_wac_and_posts_a_balanced_sale_and_cogs_journal(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $beans = $this->stockIn($tenant, $branchId, headers: $headers, unitCost: '2.0000', quantity: '100.000');
        $product = $this->inventoryControlledProduct($tenant, name: 'Test Latte', price: '10.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '2.000', 'wastage' => '0']]);

        $order = $this->createOrder($tenant, $branchId, $headers, $product, quantity: 3);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $pay = $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-cogs-1'], $headers)
            ->assertOk()->assertJsonPath('data.payment.status', 'completed');

        // Inventory: 2kg/unit * 3 units = 6kg consumed at the 2.00 WAC just stocked in.
        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $beans['itemId'])->first();
        $this->assertNotNull($movement);
        $this->assertSame(6.0, (float) $movement->quantity);
        $this->assertSame(2.0, (float) $movement->unit_cost);
        $this->assertSame(12.0, (float) $movement->total_cost);
        $balance = DB::table('stock_balances')->where('tenant_id', $tenant)->where('inventory_item_id', $beans['itemId'])->first();
        $this->assertSame(94.0, (float) $balance->quantity_on_hand);

        // Order/order_item COGS snapshot.
        $orderItem = DB::table('order_items')->where('tenant_id', $tenant)->where('order_id', $orderId)->first();
        $this->assertSame(12.0, (float) $orderItem->cogs_total);
        $this->assertSame(4.0, (float) $orderItem->cogs_unit);
        $orderRow = DB::table('orders')->where('id', $orderId)->first();
        $this->assertSame(12.0, (float) $orderRow->cogs_total);
        $this->assertSame(round((float) $totals['total'] - 12.0, 2), round((float) $orderRow->gross_profit, 2));

        // One balanced journal: cash DR total, sales revenue CR subtotal
        // (+tax CR if any), COGS DR 12 / Inventory Asset CR 12.
        $entry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->where('source_event', 'POS_ORDER_PAID')->first();
        $this->assertNotNull($entry);
        $this->assertSame('posted', $entry->status);
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $expectedLineTotal = round((float) $totals['total'] + 12.0, 2);
        $this->assertSame($expectedLineTotal, round((float) $lines->sum('debit'), 2));
        $this->assertSame($expectedLineTotal, round((float) $lines->sum('credit'), 2));

        $cashAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $cogsAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5000')->value('id');
        $inventoryAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id');
        $this->assertSame(round((float) $totals['total'], 2), round((float) $lines->firstWhere('financial_account_id', $cashAccountId)->debit, 2));
        $this->assertSame(12.0, (float) $lines->firstWhere('financial_account_id', $cogsAccountId)->debit);
        $this->assertSame(12.0, (float) $lines->firstWhere('financial_account_id', $inventoryAccountId)->credit);

        // Payment retry (same key) must not consume stock or post a journal twice.
        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-cogs-1'], $headers)->assertOk();
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->count());
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
    }

    public function test_non_inventory_product_sale_creates_no_stock_movement_and_a_valid_zero_cogs_snapshot(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $product = DB::table('products')->where('tenant_id', $tenant)->where('name', 'Cappuccino')->first();
        $this->assertFalse((bool) $product->inventory_controlled);

        $order = $this->createOrder($tenant, $branchId, $headers, $product->id, quantity: 1, withDefaultModifiers: true);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-zero-cogs-1'], $headers)->assertOk();

        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->where('reference_type', 'order_item')->count());
        $this->assertSame(0, DB::table('sale_consumptions')->where('tenant_id', $tenant)->where('order_id', $orderId)->count());
        $orderRow = DB::table('orders')->where('id', $orderId)->first();
        $this->assertNotNull($orderRow->cogs_total);
        $this->assertSame(0.0, (float) $orderRow->cogs_total);
        $this->assertSame(round((float) $totals['total'], 2), round((float) $orderRow->gross_profit, 2));
    }

    public function test_published_variants_and_selected_modifier_adjustments_control_consumption_and_quantity(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $beans = $this->stockIn($tenant, $branchId, $headers, '2.0000', '30.000');
        $milk = $this->stockIn($tenant, $branchId, $headers, '1.0000', '30.000');
        $product = $this->inventoryControlledProduct($tenant, 'Snapshot Latte', '10.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '1.000', 'wastage' => '0']]);
        $now = now();
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Milk', 'selection_type' => 'single', 'group_type' => 'choice', 'is_required' => false, 'min_selections' => 0, 'max_selections' => 1, 'allow_quantity' => false, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $option = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Oat', 'price_delta' => 0, 'cost_delta' => 0, 'is_active' => true, 'is_available' => true, 'created_at' => $now, 'updated_at' => $now]);
        $snapshot = $this->publishedSnapshot($tenant, $branchId, [$product], [['groupId' => $group, 'optionId' => $option]]);
        $payload = json_decode((string) DB::table('published_menu_versions')->where('id', $snapshot['versionId'])->value('payload_json'), true);
        $baseVariant = $snapshot['variants'][$product];
        $largeVariant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Large', 'base_price' => '11.00', 'cost_price' => 0, 'is_default' => false, 'is_active' => true, 'sort_order' => 1, 'created_at' => $now, 'updated_at' => $now]);
        $payload['menus'][0]['sections'][0]['products'][0]['variants'][0]['modifierRecipeAdjustments'] = [['optionId' => $option, 'components' => [['materialId' => $milk['itemId'], 'quantity' => '0.500', 'unitCode' => 'kg', 'operation' => 'add']]]];
        $payload['menus'][0]['sections'][0]['products'][0]['variants'][] = ['id' => $largeVariant, 'name' => ['default' => 'Large'], 'effectivePrice' => '11.00', 'baseRecipe' => [['materialId' => $beans['itemId'], 'quantity' => '2.000', 'unitCode' => 'kg']], 'modifierRecipeAdjustments' => []];
        DB::table('published_menu_versions')->where('id', $snapshot['versionId'])->update(['payload_json' => json_encode($payload)]);

        $shiftId = $this->openShift($tenant, $branchId, $headers);
        $regular = $this->postJson('/api/v1/orders', ['branchId' => $branchId, 'shiftId' => $shiftId, 'orderType' => 'takeaway', 'publishedMenuVersionId' => $snapshot['versionId'], 'items' => [['productId' => $product, 'placementId' => $snapshot['placements'][$product], 'variantId' => $baseVariant, 'quantity' => 2, 'modifierOptionIds' => [$option]]]], $headers)->assertCreated();
        $large = $this->postJson('/api/v1/orders', ['branchId' => $branchId, 'shiftId' => $shiftId, 'orderType' => 'takeaway', 'publishedMenuVersionId' => $snapshot['versionId'], 'items' => [['productId' => $product, 'placementId' => $snapshot['placements'][$product], 'variantId' => $largeVariant, 'quantity' => 1]]], $headers)->assertCreated();
        foreach ([$regular, $large] as $index => $order) {
            $this->postJson('/api/v1/orders/'.$order->json('data.id').'/pay', ['method' => 'cash', 'amount' => $order->json('data.totals.total'), 'idempotencyKey' => 'snapshot-components-'.$index], $headers)->assertOk();
        }

        $consumed = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->selectRaw('inventory_item_id, SUM(quantity) as quantity')->groupBy('inventory_item_id')->pluck('quantity', 'inventory_item_id');
        // Regular: 1 bean + 0.5 milk, multiplied by 2. Large: 2 beans.
        $this->assertSame(4.0, (float) $consumed[$beans['itemId']]);
        $this->assertSame(1.0, (float) $consumed[$milk['itemId']]);
    }

    public function test_missing_recipe_configuration_blocks_the_payment_and_rolls_back_completely(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $product = $this->inventoryControlledProduct($tenant, name: 'No Recipe Item', price: '5.00');
        // Deliberately no recipe configured for this product.

        $order = $this->createOrder($tenant, $branchId, $headers, $product, quantity: 1);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-no-recipe-1'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('productId');

        $orderRow = DB::table('orders')->where('id', $orderId)->first();
        $this->assertSame('unpaid', $orderRow->payment_status);
        $this->assertNull($orderRow->cogs_total);
        $this->assertSame(0, DB::table('payments')->where('order_id', $orderId)->count());
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
    }

    public function test_insufficient_stock_rolls_back_the_entire_payment_no_journal_no_partial_consumption(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $beans = $this->stockIn($tenant, $branchId, headers: $headers, unitCost: '2.0000', quantity: '4.000');
        $product = $this->inventoryControlledProduct($tenant, name: 'Short Stock Item', price: '10.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '2.000', 'wastage' => '0']]);

        // 3 units * 2kg each = 6kg needed, but only 4kg on hand.
        $order = $this->createOrder($tenant, $branchId, $headers, $product, quantity: 3);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-short-stock-1'], $headers)
            ->assertUnprocessable();

        $orderRow = DB::table('orders')->where('id', $orderId)->first();
        $this->assertSame('unpaid', $orderRow->payment_status);
        $this->assertSame(0, DB::table('payments')->where('order_id', $orderId)->count());
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->count());
        $balance = DB::table('stock_balances')->where('tenant_id', $tenant)->where('inventory_item_id', $beans['itemId'])->first();
        $this->assertSame(4.0, (float) $balance->quantity_on_hand);
    }

    public function test_multi_item_sale_is_atomic_one_bad_item_rolls_back_the_whole_order(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $beans = $this->stockIn($tenant, $branchId, headers: $headers, unitCost: '3.0000', quantity: '50.000');
        $goodProduct = $this->inventoryControlledProduct($tenant, name: 'Good Item', price: '8.00');
        $this->recipe($tenant, $goodProduct, [$beans['itemId'] => ['quantity' => '1.000', 'wastage' => '0']]);
        $badProduct = $this->inventoryControlledProduct($tenant, name: 'Bad Item No Recipe', price: '6.00');

        $snapshot = $this->publishedSnapshot($tenant, $branchId, [$goodProduct, $badProduct]);
        $shiftId = $this->openShift($tenant, $branchId, $headers);
        $order = $this->postJson('/api/v1/orders', [
            'branchId' => $branchId,
            'shiftId' => $shiftId,
            'orderType' => 'takeaway',
            'publishedMenuVersionId' => $snapshot['versionId'],
            'items' => [
                ['productId' => $goodProduct, 'placementId' => $snapshot['placements'][$goodProduct], 'variantId' => $snapshot['variants'][$goodProduct], 'quantity' => 2],
                ['productId' => $badProduct, 'placementId' => $snapshot['placements'][$badProduct], 'variantId' => $snapshot['variants'][$badProduct], 'quantity' => 1],
            ],
        ], $headers)->assertCreated();
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-multi-atomic-1'], $headers)
            ->assertUnprocessable();

        // The good item's consumption must not have survived the rollback.
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->count());
        $balance = DB::table('stock_balances')->where('tenant_id', $tenant)->where('inventory_item_id', $beans['itemId'])->first();
        $this->assertSame(50.0, (float) $balance->quantity_on_hand);
        $this->assertSame('unpaid', DB::table('orders')->where('id', $orderId)->value('payment_status'));
    }

    public function test_product_inventory_settings_warehouse_override_takes_precedence_over_the_branch_main_fallback(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $barWarehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branchId}-BAR")->value('id');

        $beans = $this->stockIn($tenant, $branchId, headers: $headers, unitCost: '2.0000', quantity: '20.000', warehouseId: $barWarehouseId);
        $product = $this->inventoryControlledProduct($tenant, name: 'Bar Routed Item', price: '9.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '1.000', 'wastage' => '0']]);
        DB::table('product_inventory_settings')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'branch_id' => $branchId, 'warehouse_id' => $barWarehouseId, 'created_at' => now(), 'updated_at' => now()]);

        $order = $this->createOrder($tenant, $branchId, $headers, $product, quantity: 1);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');
        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-warehouse-override-1'], $headers)->assertOk();

        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $beans['itemId'])->first();
        $this->assertSame($barWarehouseId, (int) $movement->warehouse_id);
    }

    public function test_card_payment_method_debits_its_own_configured_account_not_cash(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $bankAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1030')->value('id');
        $cardMethod = $this->postJson('/api/v1/finance/payment-methods', ['code' => 'CARD', 'name' => 'Card', 'type' => 'card', 'financialAccountId' => $bankAccountId, 'isActive' => true], $headers)
            ->assertCreated()->json('data.id');

        $product = DB::table('products')->where('tenant_id', $tenant)->where('name', 'Cappuccino')->first();
        $order = $this->createOrder($tenant, $branchId, $headers, $product->id, quantity: 1, withDefaultModifiers: true);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'card', 'paymentMethodId' => $cardMethod, 'amount' => $totals['total'], 'idempotencyKey' => 'sale-card-1'], $headers)
            ->assertOk();

        $entry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->first();
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $this->assertSame(round((float) $totals['total'], 2), round((float) $lines->firstWhere('financial_account_id', $bankAccountId)->debit, 2));
        $cashAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->assertNull($lines->firstWhere('financial_account_id', $cashAccountId));
    }

    public function test_an_invalid_explicit_payment_method_id_is_rejected_before_any_posting(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $product = DB::table('products')->where('tenant_id', $tenant)->where('name', 'Cappuccino')->first();
        $order = $this->createOrder($tenant, $branchId, $headers, $product->id, quantity: 1, withDefaultModifiers: true);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'card', 'paymentMethodId' => 999999, 'amount' => $totals['total'], 'idempotencyKey' => 'sale-bad-method-1'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('paymentMethodId');
        $this->assertSame('unpaid', DB::table('orders')->where('id', $orderId)->value('payment_status'));
    }

    public function test_an_unconfigured_legacy_payment_method_still_completes_the_sale_without_posting(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        // 'wallet' has no seeded payment_methods row for this tenant.
        $product = DB::table('products')->where('tenant_id', $tenant)->where('name', 'Cappuccino')->first();
        $order = $this->createOrder($tenant, $branchId, $headers, $product->id, quantity: 1, withDefaultModifiers: true);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'wallet', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-unmapped-1'], $headers)
            ->assertOk()->assertJsonPath('data.payment.status', 'completed');

        $this->assertSame('paid', DB::table('orders')->where('id', $orderId)->value('payment_status'));
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
        $this->assertDatabaseHas('activity_logs', ['tenant_id' => $tenant, 'action' => 'pos_order.finance_posting_skipped', 'entity_id' => $orderId]);
    }

    public function test_cash_sale_moves_the_cash_drawer_ledger_balance(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $drawerId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $before = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->json('data.location.balance');

        $product = DB::table('products')->where('tenant_id', $tenant)->where('name', 'Cappuccino')->first();
        $order = $this->createOrder($tenant, $branchId, $headers, $product->id, quantity: 1, withDefaultModifiers: true);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');
        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-ledger-balance-1'], $headers)->assertOk();

        $after = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->json('data.location.balance');
        $this->assertSame(round($before + (float) $totals['total'], 2), round($after, 2));
    }

    private function stockIn(int $tenant, int $branchId, array $headers, string $unitCost, string $quantity, ?int $warehouseId = null): array
    {
        $warehouseId ??= (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branchId}-MAIN")->value('id');
        $itemId = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'حبوب اختبار', 'nameEn' => 'Test Beans '.uniqid(), 'sku' => 'SALE-TEST-'.uniqid(),
            'itemType' => 'raw_material', 'unit' => 'kg', 'minimumStock' => '1.000', 'reorderLevel' => '1.000', 'latestUnitCost' => $unitCost, 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');

        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $warehouseId, 'itemId' => $itemId, 'type' => 'stock_in', 'quantity' => $quantity, 'unitCost' => $unitCost, 'reason' => 'Test opening stock',
        ], $headers)->assertCreated();

        return ['itemId' => $itemId, 'warehouseId' => $warehouseId];
    }

    private function inventoryControlledProduct(int $tenant, string $name, string $price): int
    {
        return (int) DB::table('products')->insertGetId([
            'tenant_id' => $tenant, 'name' => $name, 'price' => $price, 'cost_price' => 0,
            'is_active' => true, 'is_stock_tracked' => false, 'inventory_controlled' => true, 'consumption_type' => 'bar',
            'sort_order' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    /** @param array<int, array{quantity:string, wastage:string}> $lines keyed by inventory_item_id */
    private function recipe(int $tenant, int $productId, array $lines): int
    {
        $recipeId = (int) DB::table('recipes')->insertGetId([
            'tenant_id' => $tenant, 'product_id' => $productId, 'name' => 'Test Recipe', 'version' => 1,
            'is_active' => true, 'yield_quantity' => 1, 'yield_unit' => 'piece', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $lineNumber = 1;
        foreach ($lines as $itemId => $line) {
            DB::table('recipe_lines')->insert([
                'tenant_id' => $tenant, 'recipe_id' => $recipeId, 'inventory_item_id' => $itemId,
                'quantity' => $line['quantity'], 'unit' => 'kg', 'wastage_percentage' => $line['wastage'],
                'line_number' => $lineNumber++, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }

        return $recipeId;
    }

    private function createOrder(int $tenant, int $branchId, array $headers, int $productId, int $quantity, bool $withDefaultModifiers = false)
    {
        $modifiers = $withDefaultModifiers ? DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->join('modifier_options', 'modifier_options.modifier_group_id', '=', 'modifier_groups.id')
            ->where('product_modifier_group.product_id', $productId)
            ->where('modifier_groups.is_required', true)
            ->where('modifier_options.is_default', true)
            ->select(['modifier_groups.id as groupId', 'modifier_options.id as optionId'])
            ->get()
            ->map(fn ($modifier) => ['groupId' => $modifier->groupId, 'optionId' => $modifier->optionId])
            ->all() : [];

        $snapshot = $this->publishedSnapshot($tenant, $branchId, [$productId], $modifiers);
        $shiftId = $this->openShift($tenant, $branchId, $headers);

        return $this->postJson('/api/v1/orders', [
            'branchId' => $branchId,
            'shiftId' => $shiftId,
            'orderType' => 'takeaway',
            'publishedMenuVersionId' => $snapshot['versionId'],
            'items' => [[
                'productId' => $productId,
                'placementId' => $snapshot['placements'][$productId],
                'variantId' => $snapshot['variants'][$productId],
                'quantity' => $quantity,
                'modifierOptionIds' => array_column($modifiers, 'optionId'),
            ]],
        ], $headers)->assertCreated();
    }

    private function openShift(int $tenant, int $branchId, array $headers): int
    {
        return (int) $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 0], $headers)
            ->assertCreated()->json('data.id');
    }

    /**
     * Builds the minimal schema-v3 snapshot needed by these legacy-sale tests.
     * The generic recipe fixtures are copied into the publication at order
     * creation; payment subsequently reads only this frozen payload.
     *
     * @param list<int> $productIds
     * @param list<array{groupId:int, optionId:int}> $selectedModifiers
     * @return array{versionId:int, placements:array<int,int>, variants:array<int,int>}
     */
    private function publishedSnapshot(int $tenant, int $branchId, array $productIds, array $selectedModifiers = []): array
    {
        $now = now();
        DB::table('published_menu_versions')
            ->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->where('status', 'current')
            ->update(['status' => 'superseded', 'updated_at' => $now]);

        $menuId = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Sale accounting '.uniqid(), 'status' => 'published', 'created_at' => $now, 'updated_at' => $now]);
        $sectionId = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menuId, 'name' => 'Published sales', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $products = [];
        $placements = [];
        $variants = [];
        foreach ($productIds as $productId) {
            $product = DB::table('products')->where('tenant_id', $tenant)->where('id', $productId)->firstOrFail();
            $variant = DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $productId)->where('is_active', true)->orderByDesc('is_default')->orderBy('id')->first();
            if ($variant === null) {
                $variantId = DB::table('product_variants')->insertGetId([
                    'tenant_id' => $tenant, 'product_id' => $productId, 'name' => 'Regular',
                    'base_price' => $product->price, 'cost_price' => $product->cost_price,
                    'is_default' => true, 'is_active' => true, 'sort_order' => 0,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
                $variant = DB::table('product_variants')->where('id', $variantId)->firstOrFail();
            }

            $placementId = DB::table('menu_item_placements')->insertGetId([
                'tenant_id' => $tenant, 'menu_section_id' => $sectionId, 'product_id' => $productId,
                'is_visible' => true, 'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $placements[$productId] = $placementId;
            $variants[$productId] = (int) $variant->id;
            $baseRecipe = DB::table('recipes')->where('tenant_id', $tenant)->where('product_id', $productId)->where('is_active', true)->orderByDesc('version')->first();
            $components = $baseRecipe === null ? [] : DB::table('recipe_lines')->where('recipe_id', $baseRecipe->id)->orderBy('line_number')->get()
                ->map(fn (object $line) => ['materialId' => (int) $line->inventory_item_id, 'quantity' => (string) $line->quantity, 'unitCode' => (string) $line->unit, 'sortOrder' => (int) $line->line_number])->all();
            $groups = collect($selectedModifiers)->map(function (array $selection): array {
                $group = DB::table('modifier_groups')->where('id', $selection['groupId'])->firstOrFail();
                $option = DB::table('modifier_options')->where('id', $selection['optionId'])->firstOrFail();

                return ['id' => $group->id, 'name' => ['default' => $group->name], 'selectionType' => $group->selection_type,
                    'isRequired' => (bool) $group->is_required, 'minSelections' => (int) $group->min_selections, 'maxSelections' => (int) $group->max_selections,
                    'options' => [['id' => $option->id, 'name' => ['default' => $option->name], 'priceDelta' => (string) $option->price_delta, 'isAvailable' => true]]];
            })->values()->all();
            $products[] = ['placementId' => $placementId, 'productId' => $productId, 'name' => ['default' => $product->name], 'isVisible' => true,
                'productAvailabilityRules' => [], 'variants' => [['id' => $variant->id, 'name' => ['default' => $variant->name], 'effectivePrice' => (string) $product->price,
                    'baseRecipe' => $components, 'modifierRecipeAdjustments' => []]], 'modifierGroups' => $groups];
        }

        $publicationId = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $versionId = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $tenant, 'menu_publication_id' => $publicationId, 'branch_id' => $branchId, 'channel' => 'pos',
            'version_number' => (int) DB::table('published_menu_versions')->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->max('version_number') + 1,
            'payload_json' => json_encode(['context' => ['schemaVersion' => 3], 'menus' => [['id' => 1, 'availabilityRules' => [], 'sections' => [['id' => 1, 'products' => $products]]]]]),
            'checksum' => hash('sha256', uniqid('sale-accounting-', true)), 'status' => 'current', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now,
        ]);

        return compact('versionId', 'placements', 'variants');
    }

    private function downtownBranchId(int $tenant): int
    {
        return (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id');
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = "sale-accounting-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'sale-accounting-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
