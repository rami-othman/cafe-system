<?php

namespace Tests\Feature;

use App\Models\Branch;
use App\Models\ModifierOption;
use App\Models\ProductVariant;
use App\Services\Catalog\RecipeConfigurationService;
use App\Services\Menu\PublishedMenuSnapshotBuilder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Phase 4 — POS sale -> Inventory consumption -> Finance posting.
 *
 * Inventory stays authoritative for consumed quantity/WAC/movement cost
 * (SaleConsumptionService never computes a cost itself, only decides what to
 * consume and where from); AccountingPostingService.postSale() then posts
 * exactly what Inventory and the order snapshot produced. These tests prove
 * payment through the real POS API using Menu snapshot-builder fixtures.
 * Full Publish-to-Payment integration coverage is deferred to Phase 3.
 */
class SaleAccountingApiTest extends TestCase
{
    use RefreshDatabase;

    public static function stockFlags(): array
    {
        return [
            'tracked, legacy disabled' => [true, false],
            'tracked, legacy enabled' => [true, true],
            'untracked, legacy disabled' => [false, false],
            'untracked, legacy enabled' => [false, true],
        ];
    }

    #[DataProvider('stockFlags')]
    public function test_only_menu_stock_flag_controls_consumption(bool $tracked, bool $legacy): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branch = $this->downtownBranchId($tenant);
        $beans = $this->stockIn($tenant, $branch, $headers, '2.0000', '100.000');
        $product = $this->stockTrackedProduct($tenant, 'Flag contract', '10.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '2.000']]);
        DB::table('products')->where('id', $product)->update(['is_stock_tracked' => $tracked, 'inventory_controlled' => $legacy]);
        $order = $this->createOrder($tenant, $branch, $headers, $product, 1);
        $orderId = $order->json('data.id');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $order->json('data.totals.total'), 'idempotencyKey' => 'flag-contract'], $headers)->assertOk();

        $this->assertSame($tracked ? 1 : 0, DB::table('sale_consumptions')->where('order_id', $orderId)->count());
        $this->assertSame($tracked ? 1 : 0, DB::table('stock_movements')->where('inventory_item_id', $beans['itemId'])->where('type', 'sale_consumption')->count());
        $this->assertSame($tracked ? 98.0 : 100.0, (float) DB::table('stock_balances')->where('inventory_item_id', $beans['itemId'])->value('quantity_on_hand'));
        $this->assertSame($tracked ? 4.0 : 0.0, (float) DB::table('orders')->where('id', $orderId)->value('cogs_total'));
    }

    public function test_pinned_menu_recipe_ignores_live_edits_and_conflicting_legacy_recipes(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branch = $this->downtownBranchId($tenant);
        $beans = $this->stockIn($tenant, $branch, $headers, '2.0000', '100.000');
        $product = $this->stockTrackedProduct($tenant, 'Frozen recipe', '10.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '2.000']]);
        $order = $this->createOrder($tenant, $branch, $headers, $product, 1);
        $orderId = $order->json('data.id');
        $versionId = DB::table('orders')->where('id', $orderId)->value('published_menu_version_id');
        $before = DB::table('published_menu_versions')->where('id', $versionId)->first();

        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '7.000']]);
        // Deliberately conflicting deprecated data: never a publication fixture.
        $legacy = DB::table('recipes')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Ignored legacy recipe', 'version' => 99, 'is_active' => true, 'yield_quantity' => '999.000', 'yield_unit' => 'batch', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('recipe_lines')->insert(['tenant_id' => $tenant, 'recipe_id' => $legacy, 'inventory_item_id' => $beans['itemId'], 'quantity' => '50.000', 'unit' => 'kg', 'wastage_percentage' => '99.999', 'line_number' => 1, 'created_at' => now(), 'updated_at' => now()]);
        $new = $this->publishedSnapshot($tenant, $branch, [$product]);
        $this->assertNotSame((int) $versionId, $new['versionId']);

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $order->json('data.totals.total'), 'idempotencyKey' => 'frozen-recipe'], $headers)->assertOk();

        $this->assertSame(2.0, (float) DB::table('stock_movements')->where('inventory_item_id', $beans['itemId'])->where('type', 'sale_consumption')->value('quantity'));
        $this->assertSame(4.0, (float) DB::table('orders')->where('id', $orderId)->value('cogs_total'));
        $this->assertNull(DB::table('sale_consumptions')->where('order_id', $orderId)->value('recipe_id'));
        $after = DB::table('published_menu_versions')->where('id', $versionId)->first();
        $this->assertSame($before->payload_json, $after->payload_json);
        $this->assertSame($before->checksum, $after->checksum);
        $this->assertSame((int) $versionId, (int) DB::table('orders')->where('id', $orderId)->value('published_menu_version_id'));
    }

    public function test_recipe_based_sale_consumes_inventory_at_wac_and_posts_a_balanced_sale_and_cogs_journal(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $beans = $this->stockIn($tenant, $branchId, headers: $headers, unitCost: '2.0000', quantity: '100.000');
        $product = $this->stockTrackedProduct($tenant, name: 'Test Latte', price: '10.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '2.000']]);
        DB::table('products')->where('id', $product)->update(['cost_price' => '999.00']);
        DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $product)->update(['cost_price' => '777.00']);

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
        $this->assertFalse((bool) $product->is_stock_tracked);

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
        $product = $this->stockTrackedProduct($tenant, 'Snapshot Latte', '10.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '1.000']]);
        $now = now();
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Milk', 'selection_type' => 'single', 'group_type' => 'choice', 'is_required' => false, 'min_selections' => 0, 'max_selections' => 1, 'allow_quantity' => false, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $option = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Oat', 'price_delta' => 0, 'cost_delta' => 0, 'is_active' => true, 'is_available' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'created_at' => $now, 'updated_at' => $now]);
        app(RecipeConfigurationService::class)->replaceProfile(
            ModifierOption::findOrFail($option),
            [['materialId' => $milk['itemId'], 'quantity' => '0.500', 'unitCode' => 'kg', 'operation' => 'add']],
        );
        $large = ProductVariant::create(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Large', 'base_price' => '11.00', 'is_default' => false, 'is_active' => true, 'sort_order' => 1]);
        app(RecipeConfigurationService::class)->replaceRecipe($large,
            [['materialId' => $beans['itemId'], 'quantity' => '2.000', 'unitCode' => 'kg']]);
        $largeVariant = $large->id;
        $snapshot = $this->publishedSnapshot($tenant, $branchId, [$product]);
        $baseVariant = $snapshot['variants'][$product];

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

    public function test_canonical_base_unit_aggregation_posts_once_is_idempotent_and_costs_the_actual_consumption(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $milk = $this->stockIn($tenant, $branchId, $headers, '1.0000', '1000.000', unit: 'ml');
        DB::table('inventory_item_unit_conversions')->insert(['tenant_id' => $tenant, 'inventory_item_id' => $milk['itemId'], 'source_unit' => 'liter', 'target_unit' => 'milliliter', 'factor' => '1000.000000', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = $this->stockTrackedProduct($tenant, 'Canonical Milk', '10.00');
        $variant = $this->recipeWithComponents($tenant, $product, [['materialId' => $milk['itemId'], 'quantity' => '200', 'unitCode' => 'ml']]);
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Extra Milk', 'selection_type' => 'single', 'max_selections' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $option = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Splash', 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'created_at' => now(), 'updated_at' => now()]);
        app(RecipeConfigurationService::class)->replaceProfile(ModifierOption::findOrFail($option), [['materialId' => $milk['itemId'], 'quantity' => '0.1', 'unitCode' => 'l', 'operation' => 'add']]);

        $snapshot = $this->publishedSnapshot($tenant, $branchId, [$product]);
        $shiftId = $this->openShift($tenant, $branchId, $headers);
        $order = $this->postJson('/api/v1/orders', ['branchId' => $branchId, 'shiftId' => $shiftId, 'orderType' => 'takeaway', 'publishedMenuVersionId' => $snapshot['versionId'], 'items' => [['productId' => $product, 'placementId' => $snapshot['placements'][$product], 'variantId' => $variant, 'quantity' => 1, 'modifierOptionIds' => [$option]]]], $headers)->assertCreated();
        $orderId = $order->json('data.id');
        $payment = ['method' => 'cash', 'amount' => $order->json('data.totals.total'), 'idempotencyKey' => 'canonical-milk'];

        $this->postJson("/api/v1/orders/{$orderId}/pay", $payment, $headers)->assertOk();
        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $milk['itemId'])->first();
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $milk['itemId'])->count());
        $this->assertSame('300.000', $movement->quantity);
        $this->assertSame('milliliter', $movement->input_unit);
        $this->assertSame('300.00', $movement->total_cost);
        $this->assertSame('300.00', DB::table('orders')->where('id', $orderId)->value('cogs_total'));

        $this->postJson("/api/v1/orders/{$orderId}/pay", $payment, $headers)->assertOk();
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $milk['itemId'])->count());
    }

    public function test_pre_phase_two_published_snapshot_resolves_legacy_recipe_units_without_rewrite(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $milk = $this->stockIn($tenant, $branchId, $headers, '1.0000', '1000.000', unit: 'ml');
        DB::table('inventory_item_unit_conversions')->insert(['tenant_id' => $tenant, 'inventory_item_id' => $milk['itemId'], 'source_unit' => 'liter', 'target_unit' => 'milliliter', 'factor' => '1000.000000', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = $this->stockTrackedProduct($tenant, 'Legacy Snapshot Milk', '10.00');
        $variant = $this->recipeWithComponents($tenant, $product, [['materialId' => $milk['itemId'], 'quantity' => '0.250', 'unitCode' => 'l']]);

        // This is serialized in its pre-Phase-2 shape at publication time;
        // payment must neither upgrade nor rewrite the immutable payload.
        $snapshot = $this->publishedSnapshot($tenant, $branchId, [$product], legacyRecipeQuantities: true);
        $payloadBefore = DB::table('published_menu_versions')->where('id', $snapshot['versionId'])->value('payload_json');
        $payload = json_decode($payloadBefore, true, 512, JSON_THROW_ON_ERROR);
        $component = $payload['menus'][0]['sections'][0]['products'][0]['variants'][0]['baseRecipe'][0];
        $this->assertSame(3, $payload['context']['schemaVersion']);
        $this->assertSame('0.25', $component['quantity']);
        $this->assertSame('l', $component['unitCode']);
        $this->assertArrayNotHasKey('canonicalQuantity', $component);
        $this->assertArrayNotHasKey('baseUnit', $component);

        $shiftId = $this->openShift($tenant, $branchId, $headers);
        $order = $this->postJson('/api/v1/orders', ['branchId' => $branchId, 'shiftId' => $shiftId, 'orderType' => 'takeaway', 'publishedMenuVersionId' => $snapshot['versionId'], 'items' => [['productId' => $product, 'placementId' => $snapshot['placements'][$product], 'variantId' => $variant, 'quantity' => 1]]], $headers)->assertCreated();
        $orderId = $order->json('data.id');

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $order->json('data.totals.total'), 'idempotencyKey' => 'legacy-snapshot-milk'], $headers)->assertOk();

        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $milk['itemId'])->first();
        $this->assertSame('250.000', $movement->quantity);
        $this->assertSame('milliliter', $movement->input_unit);
        $this->assertSame($payloadBefore, DB::table('published_menu_versions')->where('id', $snapshot['versionId'])->value('payload_json'));
    }

    public function test_same_and_convertible_mass_recipe_units_consume_the_inventory_base_unit(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $beans = $this->stockIn($tenant, $branchId, $headers, '1.0000', '1000.000', unit: 'g');
        DB::table('inventory_item_unit_conversions')->insert(['tenant_id' => $tenant, 'inventory_item_id' => $beans['itemId'], 'source_unit' => 'kilogram', 'target_unit' => 'gram', 'factor' => '1000.000000', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        foreach ([['Same gram', '2', 'g', '2.000'], ['Kilogram to gram', '0.5', 'kg', '500.000']] as [$name, $quantity, $unit, $expected]) {
            $product = $this->stockTrackedProduct($tenant, $name, '10.00');
            $this->recipeWithComponents($tenant, $product, [['materialId' => $beans['itemId'], 'quantity' => $quantity, 'unitCode' => $unit]]);
            $order = $this->createOrder($tenant, $branchId, $headers, $product, 1);
            $this->postJson('/api/v1/orders/'.$order->json('data.id').'/pay', ['method' => 'cash', 'amount' => $order->json('data.totals.total'), 'idempotencyKey' => 'mass-unit-'.$unit], $headers)->assertOk();
            $this->assertSame($expected, DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->latest('id')->value('quantity'));
            $this->assertSame('gram', DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->latest('id')->value('input_unit'));
        }
    }

    public function test_missing_recipe_configuration_blocks_the_payment_and_rolls_back_completely(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $product = $this->stockTrackedProduct($tenant, name: 'No Recipe Item', price: '5.00');
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
        $product = $this->stockTrackedProduct($tenant, name: 'Short Stock Item', price: '10.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '2.000']]);

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
        $goodProduct = $this->stockTrackedProduct($tenant, name: 'Good Item', price: '8.00');
        $this->recipe($tenant, $goodProduct, [$beans['itemId'] => ['quantity' => '1.000']]);
        $badProduct = $this->stockTrackedProduct($tenant, name: 'Bad Item No Recipe', price: '6.00');

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

    public function test_branch_main_is_the_v1_sale_route_even_when_a_legacy_product_setting_exists(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $barWarehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branchId}-BAR")->value('id');

        $mainWarehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branchId}-MAIN")->value('id');
        $beans = $this->stockIn($tenant, $branchId, headers: $headers, unitCost: '2.0000', quantity: '20.000', warehouseId: $mainWarehouseId);
        $product = $this->stockTrackedProduct($tenant, name: 'Bar Routed Item', price: '9.00');
        $this->recipe($tenant, $product, [$beans['itemId'] => ['quantity' => '1.000']]);
        DB::table('product_inventory_settings')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'branch_id' => $branchId, 'warehouse_id' => $barWarehouseId, 'created_at' => now(), 'updated_at' => now()]);

        $order = $this->createOrder($tenant, $branchId, $headers, $product, quantity: 1);
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');
        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'sale-warehouse-override-1'], $headers)->assertOk();

        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $beans['itemId'])->first();
        $this->assertSame($mainWarehouseId, (int) $movement->warehouse_id);
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

    private function stockIn(int $tenant, int $branchId, array $headers, string $unitCost, string $quantity, ?int $warehouseId = null, string $unit = 'kg'): array
    {
        $warehouseId ??= (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branchId}-MAIN")->value('id');
        $itemId = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'حبوب اختبار', 'nameEn' => 'Test Beans '.uniqid(), 'sku' => 'SALE-TEST-'.uniqid(),
            'itemType' => 'raw_material', 'unit' => $unit, 'minimumStock' => '1.000', 'reorderLevel' => '1.000', 'latestUnitCost' => $unitCost, 'warehouseIds' => [$warehouseId], 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');

        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $warehouseId, 'itemId' => $itemId, 'type' => 'stock_in', 'quantity' => $quantity, 'unitCost' => $unitCost, 'reason' => 'Test opening stock',
        ], $headers)->assertCreated();

        return ['itemId' => $itemId, 'warehouseId' => $warehouseId];
    }

    private function stockTrackedProduct(int $tenant, string $name, string $price): int
    {
        return (int) DB::table('products')->insertGetId([
            'tenant_id' => $tenant, 'name' => $name, 'price' => $price, 'cost_price' => 0,
            'is_active' => true, 'is_stock_tracked' => true, 'inventory_controlled' => false, 'consumption_type' => 'bar',
            'sort_order' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    /** @param array<int, array{quantity:string}> $lines keyed by inventory_item_id */
    private function recipe(int $tenant, int $productId, array $lines): int
    {
        $product = DB::table('products')->where('id', $productId)->firstOrFail();
        $variant = ProductVariant::firstOrCreate(
            ['tenant_id' => $tenant, 'product_id' => $productId, 'is_default' => true],
            ['name' => 'Regular', 'base_price' => $product->price, 'is_active' => true],
        );
        app(RecipeConfigurationService::class)->replaceRecipe($variant,
            collect($lines)->map(fn (array $line, int $itemId) => ['materialId' => $itemId, 'quantity' => $line['quantity'], 'unitCode' => 'kg'])->values()->all());

        return (int) $variant->recipe()->value('id');
    }

    private function recipeWithComponents(int $tenant, int $productId, array $components): int
    {
        $product = DB::table('products')->where('id', $productId)->firstOrFail();
        $variant = ProductVariant::firstOrCreate(['tenant_id' => $tenant, 'product_id' => $productId, 'is_default' => true], ['name' => 'Regular', 'base_price' => $product->price, 'is_active' => true]);
        app(RecipeConfigurationService::class)->replaceRecipe($variant, $components);

        return (int) $variant->id;
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

        $snapshot = $this->publishedSnapshot($tenant, $branchId, [$productId]);
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
     * Uses the production Menu snapshot builder with canonical variant recipes.
     * Intentionally bypasses publication validation for malformed-snapshot tests;
     * this fixture does not prove Publish-to-Payment integration.
     *
     * @param  list<int>  $productIds
     * @return array{versionId:int, placements:array<int,int>, variants:array<int,int>}
     */
    private function publishedSnapshot(int $tenant, int $branchId, array $productIds, bool $legacyRecipeQuantities = false): array
    {
        $now = now();
        DB::table('published_menu_versions')
            ->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->where('status', 'current')
            ->update(['status' => 'superseded', 'updated_at' => $now]);

        $menuId = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Sale accounting '.uniqid(), 'status' => 'published', 'created_at' => $now, 'updated_at' => $now]);
        $sectionId = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menuId, 'name' => 'Published sales', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
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

        }

        $publicationId = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $payload = app(PublishedMenuSnapshotBuilder::class)->build($tenant, Branch::findOrFail($branchId), 'pos', [$menuId]);
        if ($legacyRecipeQuantities) {
            foreach ($payload['menus'] as &$menu) {
                foreach ($menu['sections'] as &$section) {
                    foreach ($section['products'] as &$product) {
                        foreach ($product['variants'] as &$variant) {
                            foreach ($variant['baseRecipe'] as &$component) {
                                unset($component['canonicalQuantity'], $component['baseUnit']);
                            }
                            unset($component);
                        }
                        unset($variant);
                    }
                    unset($product);
                }
                unset($section);
            }
            unset($menu);
        }

        $versionId = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $tenant, 'menu_publication_id' => $publicationId, 'branch_id' => $branchId, 'channel' => 'pos',
            'version_number' => (int) DB::table('published_menu_versions')->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->max('version_number') + 1,
            'payload_json' => json_encode($payload),
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
