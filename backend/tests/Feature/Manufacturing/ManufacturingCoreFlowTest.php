<?php

namespace Tests\Feature\Manufacturing;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * P0 regression suite for the Manufacturing backend: recipe validation,
 * production preview/draft/completion against the real WAC engine, the
 * semi-finished chain (Pastry Cream -> Eclair), the critical POS
 * double-consumption regression, reversal (full + partial-block), and
 * conversion. Runs against the real HTTP API + real services — no mocking
 * of InventoryPostingService/WAC.
 */
class ManufacturingCoreFlowTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private int $branchId;

    private int $warehouseId;

    private array $headers;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
        $this->tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $this->branchId = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Factory test', 'branch_type' => 'factory', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(\App\Services\FinancialSetupService::class)->ensureForTenant($this->tenant, $this->branchId);
        $this->artisan('factory:setup-catalogs', ['--apply' => true])->assertSuccessful();
        $this->warehouseId = (int) DB::table('branches')->where('id', $this->branchId)->value('default_warehouse_id');
        $userId = (int) DB::table('users')->where('tenant_id', $this->tenant)->where('role', 'owner')->value('id');
        $token = 'mfg-test-token-'.uniqid();
        DB::table('api_tokens')->insert(['tenant_id' => $this->tenant, 'user_id' => $userId, 'name' => 'mfg-test', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $this->headers = ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $this->tenant];
    }

    public function test_recipe_validation_rejects_zero_quantity_duplicate_ingredient_self_reference_and_circular_dependency(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $cake = $this->createItem('finished_good', 'piece');

        // zero output quantity
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '0', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '1', 'unit' => 'kilogram']],
        ], $this->headers)->assertStatus(422)->assertJsonPath('code', 'MANUFACTURING_VALIDATION_FAILED');

        // no ingredients
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece', 'lines' => [],
        ], $this->headers)->assertStatus(422);

        // zero ingredient quantity
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '0', 'unit' => 'kilogram']],
        ], $this->headers)->assertStatus(422)->assertJsonPath('code', 'MANUFACTURING_VALIDATION_FAILED');

        // duplicate ingredient
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '1', 'unit' => 'kilogram'], ['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertStatus(422)->assertJsonPath('code', 'DUPLICATE_INGREDIENT');

        // direct self-reference
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $cake, 'quantity' => '1', 'unit' => 'piece']],
        ], $this->headers)->assertStatus(422)->assertJsonPath('code', 'CIRCULAR_RECIPE');

        // inactive ingredient
        $inactive = $this->createItem('raw_material', 'kilogram', active: false);
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $inactive, 'quantity' => '1', 'unit' => 'kilogram']],
        ], $this->headers)->assertStatus(422)->assertJsonPath('code', 'ITEM_INACTIVE');

        // A -> B, then B -> A must be blocked (circular manufactured-product dependency)
        $productA = $this->createItem('semi_finished_good', 'kilogram');
        $productB = $this->createItem('semi_finished_good', 'kilogram');
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $productA, 'outputQuantity' => '1', 'outputUnit' => 'kilogram',
            'lines' => [['inventoryItemId' => $productB, 'quantity' => '1', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated();
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $productB, 'outputQuantity' => '1', 'outputUnit' => 'kilogram',
            'lines' => [['inventoryItemId' => $productA, 'quantity' => '1', 'unit' => 'kilogram']],
        ], $this->headers)->assertStatus(422)->assertJsonPath('code', 'CIRCULAR_RECIPE');
    }

    public function test_recipe_editing_creates_a_new_immutable_version_and_old_production_is_unaffected(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '10');
        $cake = $this->createItem('finished_good', 'piece');

        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');
        $this->assertSame(1, $recipe['version']);

        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk()->json('data');
        $this->assertSame('v1', $completed['recipeVersion']);

        // edit: flour requirement doubles
        $updated = $this->putJson("/api/v1/manufacturing/recipes/{$recipe['id']}", [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '4', 'unit' => 'kilogram']],
        ], $this->headers)->assertOk()->json('data');
        $this->assertSame(2, $updated['version']);

        // the already-completed production record must still say v1, unaffected by the edit
        $reloaded = $this->getJson("/api/v1/manufacturing/production/{$completed['id']}", $this->headers)->assertOk()->json('data');
        $this->assertSame('v1', $reloaded['recipeVersion']);
        $this->assertSame(200.0, (float) $reloaded['actualCost']); // 2kg flour @ 100/kg, from v1 — unaffected by the v2 edit
    }

    public function test_semi_finished_chain_pastry_cream_feeds_eclair_without_double_consuming_raw_materials(): void
    {
        $milk = $this->createItem('raw_material', 'liter');
        $sugar = $this->createItem('raw_material', 'kilogram');
        $starch = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($milk, '8000', '50');
        $this->stockIn($sugar, '15833', '30');
        $this->stockIn($starch, '4500', '10');

        $pastryCream = $this->createItem('semi_finished_good', 'kilogram');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $pastryCream, 'outputQuantity' => '8', 'outputUnit' => 'kilogram',
            'lines' => [
                ['inventoryItemId' => $milk, 'quantity' => '5', 'unit' => 'liter'],
                ['inventoryItemId' => $sugar, 'quantity' => '3', 'unit' => 'kilogram'],
                ['inventoryItemId' => $starch, 'quantity' => '0.8', 'unit' => 'kilogram'],
            ],
        ], $this->headers)->assertCreated()->json('data');

        $preview = $this->getJson('/api/v1/manufacturing/production/preview?recipeId='.$recipe['id'].'&qty=8&warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertFalse($preview['hasConversionIssue']);
        $this->assertFalse($preview['hasInsufficient']);

        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '8', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '7.6'], $this->headers)->assertOk()->json('data');

        $milkBalance = DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $milk)->first();
        $this->assertSame(45.0, (float) $milkBalance->quantity_on_hand); // 50 - 5
        $pastryCreamBalance = DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $pastryCream)->first();
        $this->assertSame(7.6, (float) $pastryCreamBalance->quantity_on_hand);
        $this->assertGreaterThan(0.0, (float) $pastryCreamBalance->average_unit_cost);

        $milkMovementCountAfterPastryCream = DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('inventory_item_id', $milk)->count();

        // Eclair recipe consumes Pastry Cream, not milk/sugar/starch again
        $eclair = $this->createItem('finished_good', 'piece');
        $eclairRecipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $eclair, 'outputQuantity' => '10', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $pastryCream, 'quantity' => '1.5', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');

        $eclairDraft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $eclairRecipe['id'], 'qty' => '10', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $this->postJson("/api/v1/manufacturing/production/drafts/{$eclairDraft['id']}/complete", ['actualQty' => '10'], $this->headers)->assertOk();

        $pastryCreamAfterEclair = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $pastryCream)->value('quantity_on_hand');
        $this->assertSame(6.1, round($pastryCreamAfterEclair, 3)); // 7.6 - 1.5
        $eclairBalance = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $eclair)->value('quantity_on_hand');
        $this->assertSame(10.0, $eclairBalance);

        // The critical assertion: producing Eclair must NOT create any new milk stock_movements.
        $milkMovementCountAfterEclair = DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('inventory_item_id', $milk)->count();
        $this->assertSame($milkMovementCountAfterPastryCream, $milkMovementCountAfterEclair, 'Producing Eclair must not re-consume Milk — only Pastry Cream stock should move.');
        $milkBalanceFinal = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $milk)->value('quantity_on_hand');
        $this->assertSame(45.0, $milkBalanceFinal);
    }

    public function test_completed_production_sold_directly_decrements_only_finished_stock_never_raw_ingredients_again(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $sugar = $this->createItem('raw_material', 'kilogram');
        $eggs = $this->createItem('raw_material', 'piece');
        $chocolate = $this->createItem('raw_material', 'gram');
        $cream = $this->createItem('raw_material', 'kilogram');
        $box = $this->createItem('packaging', 'piece');
        $this->stockIn($flour, '18333', '20');
        $this->stockIn($sugar, '15833', '20');
        $this->stockIn($eggs, '2500', '100');
        $this->stockIn($chocolate, '78.75', '10000');
        $this->stockIn($cream, '35000', '20');
        $this->stockIn($box, '5000', '20');

        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [
                ['inventoryItemId' => $flour, 'quantity' => '2.4', 'unit' => 'kilogram'],
                ['inventoryItemId' => $sugar, 'quantity' => '1.2', 'unit' => 'kilogram'],
                ['inventoryItemId' => $eggs, 'quantity' => '16', 'unit' => 'piece'],
                ['inventoryItemId' => $chocolate, 'quantity' => '800', 'unit' => 'gram'],
                ['inventoryItemId' => $cream, 'quantity' => '2', 'unit' => 'kilogram'],
                ['inventoryItemId' => $box, 'quantity' => '4', 'unit' => 'piece'],
            ],
            'shelfLifeValue' => 3, 'shelfLifeUnit' => 'days',
        ], $this->headers)->assertCreated()->json('data');

        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '8', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", [
            'actualQty' => '7', 'waste' => ['qty' => '1', 'unit' => 'piece', 'reason' => 'كسر', 'notes' => 'test'],
        ], $this->headers)->assertOk()->json('data');

        $this->assertSame(7.0, (float) $completed['actual']);
        $this->assertNotNull($completed['actualCost']);
        $this->assertNotNull($completed['batch']);
        $this->assertSame(3.0, (float) \Carbon\Carbon::parse($completed['batch']['mfgDate'])->diffInDays(\Carbon\Carbon::parse($completed['batch']['expiry'])));

        $flourMovementCountAfterProduction = DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('inventory_item_id', $flour)->count();
        $cakeBalanceAfterProduction = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame(7.0, $cakeBalanceAfterProduction);

        // Factory finished stock is sold directly without a POS shift.
        $customer = $this->postJson('/api/v1/finance/customers', ['branchId' => $this->branchId, 'name' => 'Factory buyer'], $this->headers)->assertCreated()->json('data.id');
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $this->branchId, 'customerId' => $customer, 'invoiceDate' => now()->toDateString(), 'lines' => [['inventoryItemId' => $cake, 'quantity' => '1', 'unitPrice' => '150000.00']]], $this->headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/finance/sales-invoices/'.$invoice.'/post', ['idempotencyKey' => 'mfg-direct-sale'], $this->headers)->assertOk();
        // THE critical regression assertions:
        $cakeBalanceAfterSale = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame(6.0, $cakeBalanceAfterSale, 'Selling one cake must decrement finished Cake stock by exactly 1.');
        $flourMovementCountAfterSale = DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('inventory_item_id', $flour)->count();
        $this->assertSame($flourMovementCountAfterProduction, $flourMovementCountAfterSale, 'Selling the manufactured Cake must NOT create another Flour stock movement — no double consumption.');
        $saleConsumptionOnCake = DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $cake)->first();
        $this->assertNotNull($saleConsumptionOnCake);
        $saleConsumptionOnFlour = DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('type', 'sale_consumption')->where('inventory_item_id', $flour)->exists();
        $this->assertFalse($saleConsumptionOnFlour, 'Flour must never receive a sale_consumption movement — it was already consumed at production time.');

        // COGS must come from the Cake's own inventory cost (its manufacturing unit cost), once.
        $this->assertGreaterThan(0.0, (float) DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice)->value('cogs_total'));
    }

    public function test_production_manufacturing_movements_never_post_a_finance_journal(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '10');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk();

        $movementIds = DB::table('stock_movements')->where('tenant_id', $this->tenant)->whereIn('type', ['production_consumption', 'production_output'])->pluck('id');
        $this->assertGreaterThan(0, $movementIds->count());
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $this->tenant)->where('source_type', 'inventory_movement')->whereIn('source_id', $movementIds)->count(), 'Manufacturing consumption/output must never post a Finance journal.');
    }

    public function test_reversal_allows_full_reversal_when_untouched_and_blocks_when_already_reversed(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '10');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk()->json('data');

        $this->stockIn($flour, '150', '1');
        $flourBeforeReverse = (float) DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $flour)->value('quantity_on_hand');

        $reversed = $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'test reversal'], $this->headers)->assertOk()->json('data');
        $this->assertSame('reversed', $reversed['status']);

        $cakeAfterReverse = (float) DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame(0.0, $cakeAfterReverse);
        $flourAfterReverse = (float) DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $flour)->value('quantity_on_hand');
        $this->assertSame($flourBeforeReverse + 2.0, $flourAfterReverse); // 2kg restored (4 pieces * 0.5kg/piece)
        $this->assertSame(150.0, (float) DB::table('inventory_items')->where('id', $flour)->value('last_purchase_cost'));

        // second reversal must be blocked
        $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'again'], $this->headers)
            ->assertStatus(409)->assertJsonPath('code', 'PRODUCTION_ALREADY_REVERSED');
    }

    public function test_reversing_an_untouched_batch_restores_remaining_finished_good_wac(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '20');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');

        $firstDraft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $this->postJson("/api/v1/manufacturing/production/drafts/{$firstDraft['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk();
        $firstWac = (float) DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('average_unit_cost');

        $this->stockIn($flour, '200', '1');
        $secondDraft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '2', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $second = $this->postJson("/api/v1/manufacturing/production/drafts/{$secondDraft['id']}/complete", ['actualQty' => '2'], $this->headers)->assertOk()->json('data');
        $mixedWac = (float) DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('average_unit_cost');
        $this->assertGreaterThan($firstWac, $mixedWac);

        $this->postJson("/api/v1/manufacturing/production/{$second['id']}/reverse", ['reason' => 'remove untouched second batch'], $this->headers)->assertOk();
        $balance = DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->first();
        $this->assertSame(4.0, (float) $balance->quantity_on_hand);
        $this->assertEqualsWithDelta($firstWac, (float) $balance->average_unit_cost, 0.01);
        $reversalMovement = DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('inventory_item_id', $cake)->where('reference_type', 'manufacturing_order_reversal')->first();
        $this->assertEqualsWithDelta((float) $second['actualCost'], (float) $reversalMovement->total_cost, 0.01);
    }

    public function test_reversal_is_blocked_when_output_has_been_fully_consumed(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '10');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk()->json('data');

        // fully consume the produced cake stock via a manual stock_out (simulating it being sold/used elsewhere)
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $this->warehouseId, 'itemId' => $cake, 'type' => 'stock_out', 'quantity' => '4', 'reason' => 'simulated full consumption',
        ], $this->headers)->assertCreated();

        $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'too late'], $this->headers)
            ->assertStatus(409)->assertJsonPath('code', 'PRODUCTION_NOT_REVERSIBLE');
    }

    public function test_reversal_is_blocked_after_partial_consumption_no_stock_is_touched_and_status_stays_completed(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '10');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '7', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '3.5', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '7', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '7'], $this->headers)->assertOk()->json('data');

        // sell/consume 5 of the 7 produced cakes, leaving 2 remaining
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $this->warehouseId, 'itemId' => $cake, 'type' => 'stock_out', 'quantity' => '5', 'reason' => 'simulated partial consumption',
        ], $this->headers)->assertCreated();

        $flourBefore = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $flour)->value('quantity_on_hand');
        $cakeBefore = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame(2.0, $cakeBefore);

        // Full reversal must be blocked entirely — no silent partial reversal.
        $response = $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'attempt after partial sale'], $this->headers)
            ->assertStatus(409)->assertJsonPath('code', 'PRODUCTION_NOT_REVERSIBLE');
        $this->assertSame(7000, $response->json('meta.producedQty'));
        $this->assertSame(2000, $response->json('meta.remainingQty'));
        $this->assertSame(5000, $response->json('meta.consumedQty'));

        // No component stock restored, no finished stock removed.
        $flourAfter = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $flour)->value('quantity_on_hand');
        $cakeAfter = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame($flourBefore, $flourAfter);
        $this->assertSame($cakeBefore, $cakeAfter);

        // Original production remains completed, not reversed.
        $this->assertSame('completed', DB::table('manufacturing_orders')->where('id', $completed['recordId'])->value('status'));
    }

    public function test_manufacturing_batch_is_created_on_completion_tracks_expiry_and_decrements_as_consumed(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '20');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
            'shelfLifeValue' => 3, 'shelfLifeUnit' => 'days',
        ], $this->headers)->assertCreated()->json('data');
        $today = now()->toDateString();
        $expectedExpiry = now()->addDays(3)->toDateString();
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '7', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '7'], $this->headers)->assertOk()->json('data');

        // A batch row was created for this completion, with expiry = production_date + shelf life.
        $batch = DB::table('manufacturing_batches')->where('tenant_id', $this->tenant)->where('manufacturing_order_id', $completed['recordId'])->first();
        $this->assertNotNull($batch, 'A manufacturing_batches row must be created on production completion.');
        $this->assertEquals(7.0, (float) $batch->produced_quantity);
        $this->assertEquals(7.0, (float) $batch->remaining_quantity);
        $this->assertSame($today, $batch->production_date);
        $this->assertSame($expectedExpiry, $batch->expiry_date);

        // Consuming 2 of 7 produced cakes must leave 5 available in Overview.
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $this->warehouseId, 'itemId' => $cake, 'type' => 'stock_out', 'quantity' => '2', 'reason' => 'simulated sale',
        ], $this->headers)->assertCreated();
        $batchAfterSale = DB::table('manufacturing_batches')->where('id', $batch->id)->first();
        $this->assertEquals(5.0, (float) $batchAfterSale->remaining_quantity);

        // An expiring-batch query (as used by the overview report) finds this batch.
        $expiringBatches = DB::table('manufacturing_batches')->where('tenant_id', $this->tenant)->where('inventory_item_id', $cake)->whereDate('expiry_date', $expectedExpiry)->get();
        $this->assertCount(1, $expiringBatches);
        $overview = $this->getJson('/api/v1/manufacturing/overview?warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertNotEmpty(array_filter($overview['expiring'], fn ($e) => $e['id'] === $completed['id']));
        $remaining = collect($overview['expiring'])->firstWhere('id', $completed['id']);
        $this->assertSame(5.0, (float) $remaining['remaining']);

        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $this->warehouseId, 'itemId' => $cake, 'type' => 'stock_out', 'quantity' => '5', 'reason' => 'consume remaining batch',
        ], $this->headers)->assertCreated();
        $empty = $this->getJson('/api/v1/manufacturing/overview?warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertNull(collect($empty['expiring'])->firstWhere('id', $completed['id']));
    }

    public function test_reversal_checks_this_orders_own_batch_not_item_level_on_hand_across_multiple_batches(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '20');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');

        // Two separate production runs of the same item, oldest first (FEFO consumes production 1's batch first).
        $draft1 = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId, 'date' => '2026-01-01'], $this->headers)->assertCreated()->json('data');
        $completed1 = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft1['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk()->json('data');
        $draft2 = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId, 'date' => '2026-02-01'], $this->headers)->assertCreated()->json('data');
        $completed2 = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft2['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk()->json('data');

        // 8 cakes on hand total. Sell 4 — FEFO drains production 1's batch entirely, production 2's batch is untouched.
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $this->warehouseId, 'itemId' => $cake, 'type' => 'stock_out', 'quantity' => '4', 'reason' => 'simulated sale',
        ], $this->headers)->assertCreated();

        $batch1 = DB::table('manufacturing_batches')->where('manufacturing_order_id', $completed1['recordId'])->first();
        $batch2 = DB::table('manufacturing_batches')->where('manufacturing_order_id', $completed2['recordId'])->first();
        $this->assertSame(0.0, (float) $batch1->remaining_quantity);
        $this->assertSame(4.0, (float) $batch2->remaining_quantity);
        $itemLevelOnHand = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame(4.0, $itemLevelOnHand); // if reversal used item-level on-hand only, it could not tell batch 1 and 2 apart
        $this->getJson("/api/v1/manufacturing/production/{$completed1['id']}", $this->headers)->assertOk()->assertJsonPath('data.soldQty', 4);
        $this->getJson("/api/v1/manufacturing/production/{$completed2['id']}", $this->headers)->assertOk()->assertJsonPath('data.soldQty', 0);

        // Production 1 must be blocked (its own batch is fully consumed) even though item-level on-hand (4) would otherwise look "reversible".
        $this->postJson("/api/v1/manufacturing/production/{$completed1['id']}/reverse", ['reason' => 'batch 1 attempt'], $this->headers)
            ->assertStatus(409)->assertJsonPath('code', 'PRODUCTION_NOT_REVERSIBLE');

        // Production 2 must be allowed — its own batch is fully untouched.
        $reversed2 = $this->postJson("/api/v1/manufacturing/production/{$completed2['id']}/reverse", ['reason' => 'batch 2 attempt'], $this->headers)->assertOk()->json('data');
        $this->assertSame('reversed', $reversed2['status']);
        $onHandAfter = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame(0.0, $onHandAfter); // production 2's 4 remaining units removed
    }

    public function test_conversion_splits_a_whole_cake_into_slices_preserving_value_and_can_be_blocked_by_insufficient_stock(): void
    {
        $whole = $this->createItem('finished_good', 'piece');
        $slice = $this->createItem('finished_good', 'piece');
        $this->stockIn($whole, '80000', '1');

        $conversion = $this->postJson('/api/v1/manufacturing/conversions', [
            'warehouseId' => $this->warehouseId, 'sourceItemId' => $whole, 'sourceQty' => '1', 'targetItemId' => $slice, 'resultQty' => '8', 'idempotencyKey' => 'conversion-once',
        ], $this->headers)->assertCreated()->json('data');
        $this->assertSame(80000.0, (float) $conversion['totalCost']);
        $this->assertSame(10000.0, (float) $conversion['resultUnitCost']);

        $wholeBalance = (float) DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $whole)->value('quantity_on_hand');
        $this->assertSame(0.0, $wholeBalance);
        $sliceBalance = (float) DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $slice)->value('quantity_on_hand');
        $this->assertSame(8.0, $sliceBalance);
        $this->postJson('/api/v1/manufacturing/conversions', [
            'warehouseId' => $this->warehouseId, 'sourceItemId' => $whole, 'sourceQty' => '1', 'targetItemId' => $slice, 'resultQty' => '8', 'idempotencyKey' => 'conversion-once',
        ], $this->headers)->assertCreated()->assertJsonPath('data.id', $conversion['id']);
        $this->postJson('/api/v1/manufacturing/conversions', [
            'warehouseId' => $this->warehouseId, 'sourceItemId' => $whole, 'sourceQty' => '1', 'targetItemId' => $slice, 'resultQty' => '9', 'idempotencyKey' => 'conversion-once',
        ], $this->headers)->assertStatus(409)->assertJsonPath('code', 'MANUFACTURING_IDEMPOTENCY_CONFLICT');
        $this->assertSame(8.0, (float) DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $slice)->value('quantity_on_hand'));

        // same source and target rejected
        $this->postJson('/api/v1/manufacturing/conversions', [
            'warehouseId' => $this->warehouseId, 'sourceItemId' => $slice, 'sourceQty' => '1', 'targetItemId' => $slice, 'resultQty' => '1',
        ], $this->headers)->assertStatus(422)->assertJsonPath('code', 'CONVERSION_SAME_ITEM');

        // insufficient source stock rejected (whole cake is now at 0)
        $this->postJson('/api/v1/manufacturing/conversions', [
            'warehouseId' => $this->warehouseId, 'sourceItemId' => $whole, 'sourceQty' => '1', 'targetItemId' => $slice, 'resultQty' => '8',
        ], $this->headers)->assertStatus(422)->assertJsonPath('code', 'INSUFFICIENT_STOCK');
    }

    public function test_duplicate_draft_completion_and_reversal_requests_are_idempotent_and_never_double_post(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '10');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');

        // duplicate draft creation with the same idempotencyKey must return the SAME draft, not create a second one
        $draftPayload = ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId, 'idempotencyKey' => 'mfg-idem-draft-1'];
        $draft1 = $this->postJson('/api/v1/manufacturing/production/drafts', $draftPayload, $this->headers)->assertCreated()->json('data');
        $draft2 = $this->postJson('/api/v1/manufacturing/production/drafts', $draftPayload, $this->headers)->assertCreated()->json('data');
        $this->assertSame($draft1['id'], $draft2['id']);
        $this->assertSame(1, DB::table('manufacturing_orders')->where('tenant_id', $this->tenant)->where('manufacturing_recipe_id', $recipe['id'])->count());

        // duplicate completion with the same idempotencyKey must return the SAME completed record and post consumption/output exactly once
        $completePayload = ['actualQty' => '4', 'idempotencyKey' => 'mfg-idem-complete-1'];
        $completed1 = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft1['id']}/complete", $completePayload, $this->headers)->assertOk()->json('data');
        $completed2 = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft1['id']}/complete", $completePayload, $this->headers)->assertOk()->json('data');
        $this->assertSame($completed1['recordId'], $completed2['recordId']);
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('type', 'production_consumption')->where('inventory_item_id', $flour)->count());
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('type', 'production_output')->where('inventory_item_id', $cake)->count());
        $flourAfterComplete = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $flour)->value('quantity_on_hand');
        $this->assertSame(8.0, $flourAfterComplete); // 10 - 2, consumed exactly once despite two HTTP calls
        $cakeAfterComplete = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame(4.0, $cakeAfterComplete);

        // duplicate reversal with the same idempotencyKey must return the SAME reversed record and restore stock exactly once
        $reversePayload = ['reason' => 'idempotency test', 'idempotencyKey' => 'mfg-idem-reverse-1'];
        $reversed1 = $this->postJson("/api/v1/manufacturing/production/{$completed1['recordId']}/reverse", $reversePayload, $this->headers)->assertOk()->json('data');
        $reversed2 = $this->postJson("/api/v1/manufacturing/production/{$completed1['recordId']}/reverse", $reversePayload, $this->headers)->assertOk()->json('data');
        $this->assertSame('reversed', $reversed1['status']);
        $this->assertSame($reversed1['recordId'], $reversed2['recordId']);
        $flourAfterReverse = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $flour)->value('quantity_on_hand');
        $this->assertSame(10.0, $flourAfterReverse); // restored exactly once, back to the original 10
        $cakeAfterReverse = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $cake)->value('quantity_on_hand');
        $this->assertSame(0.0, $cakeAfterReverse);
    }

    public function test_tenant_cannot_read_or_reference_another_tenants_manufacturing_recipes_or_production(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '10');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk()->json('data');

        // a second, unrelated tenant with its own owner + warehouse
        $tenantB = (int) DB::table('tenants')->insertGetId(['name' => 'mfg-isolation-b', 'slug' => 'mfg-isolation-b-'.uniqid(), 'status' => 'active', 'plan' => 'starter', 'currency' => 'SYP', 'timezone' => 'Asia/Damascus', 'created_at' => now(), 'updated_at' => now()]);
        $branchB = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenantB, 'name' => 'Branch B', 'branch_type' => 'factory', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $warehouseB = (int) DB::table('warehouses')->insertGetId(['tenant_id' => $tenantB, 'branch_id' => $branchB, 'name' => 'Warehouse B', 'code' => "MFG-ISO-B-$tenantB", 'type' => 'other', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $userB = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantB, 'name' => 'Owner B', 'email' => 'owner-b-'.uniqid().'@example.test', 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $tokenB = 'mfg-isolation-token-'.uniqid();
        DB::table('api_tokens')->insert(['tenant_id' => $tenantB, 'user_id' => $userB, 'name' => 'mfg-isolation-b', 'token_hash' => hash('sha256', $tokenB), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $headersB = ['Authorization' => "Bearer $tokenB", 'X-Tenant-Id' => $tenantB];

        // tenant B cannot read tenant A's recipe, production record, or list them by scanning tenant A's ids
        $this->getJson("/api/v1/manufacturing/recipes/{$recipe['id']}", $headersB)->assertNotFound();
        $this->getJson("/api/v1/manufacturing/production/{$completed['recordId']}", $headersB)->assertNotFound();
        $this->assertEmpty($this->getJson('/api/v1/manufacturing/recipes', $headersB)->assertOk()->json('data'));
        $this->assertEmpty($this->getJson('/api/v1/manufacturing/production', $headersB)->assertOk()->json('data'));

        // tenant B cannot start production against tenant A's recipe, even scoped to its own warehouse
        $this->postJson('/api/v1/manufacturing/production/drafts', ['branchId' => $branchB, 'recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $warehouseB], $headersB)
            ->assertStatus(404);

        // tenant B cannot reverse tenant A's completed production
        $this->postJson("/api/v1/manufacturing/production/{$completed['recordId']}/reverse", ['reason' => 'cross tenant attempt'], $headersB)
            ->assertStatus(404);

        // tenant A's stock must be completely untouched by tenant B's rejected attempts
        $flourFinal = (float) DB::table('stock_balances')->where('tenant_id', $this->tenant)->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $flour)->value('quantity_on_hand');
        $this->assertSame(8.0, $flourFinal);
    }

    public function test_permissions_enforce_role_based_access_server_side_not_just_frontend_button_hiding(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '10');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk()->json('data');

        $employeeHeaders = $this->headersForRole('employee');
        $managerHeaders = $this->headersForRole('manager');
        // Decision 1 (26/09/2026): manufacturing moved off the cafe manager
        // role entirely and onto the independent factory_manager role — see
        // FactoryManagerRoleTest for the role's own coverage. This header set
        // is assigned to a *factory*-type branch, matching that decision.
        $factoryManagerHeaders = $this->headersForRole('factory_manager', factoryBranch: true);
        $cake2 = $this->createItem('finished_good', 'piece');

        // employee (per ManufacturingAccess::ROLE_PERMISSIONS): no manufacturing ability at all.
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake2, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $employeeHeaders)->assertStatus(403);
        $this->putJson("/api/v1/manufacturing/recipes/{$recipe['id']}", [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2.5', 'unit' => 'kilogram']],
        ], $employeeHeaders)->assertStatus(403);
        $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'employee attempt'], $employeeHeaders)->assertStatus(403);
        $this->getJson('/api/v1/manufacturing/reports', $employeeHeaders)->assertStatus(403);

        // manager (per Decision 1: the cafe does not manufacture): no manufacturing ability either, same as employee.
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake2, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $managerHeaders)->assertStatus(403);
        $this->putJson("/api/v1/manufacturing/recipes/{$recipe['id']}", [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2.5', 'unit' => 'kilogram']],
        ], $managerHeaders)->assertStatus(403);
        $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'manager attempt'], $managerHeaders)->assertStatus(403);
        $this->getJson('/api/v1/manufacturing/reports', $managerHeaders)->assertStatus(403);

        // the rejected employee/manager attempts must not have changed anything
        $this->assertSame(0, DB::table('manufacturing_recipes')->where('tenant_id', $this->tenant)->where('product_item_id', $cake2)->count());
        $this->assertSame(1, DB::table('manufacturing_recipe_versions')->where('tenant_id', $this->tenant)->where('manufacturing_recipe_id', $recipe['id'])->count());
        $this->assertSame('completed', DB::table('manufacturing_orders')->where('id', $completed['recordId'])->value('status'));

        // factory_manager: allowed to create/edit recipes, reverse, and view reports on the SAME endpoints.
        $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake2, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $factoryManagerHeaders)->assertCreated();
        $this->putJson("/api/v1/manufacturing/recipes/{$recipe['id']}", [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2.5', 'unit' => 'kilogram']],
        ], $factoryManagerHeaders)->assertOk();
        $this->getJson('/api/v1/manufacturing/reports', $factoryManagerHeaders)->assertOk();
        $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'factory manager attempt'], $factoryManagerHeaders)->assertOk()->assertJsonPath('data.status', 'reversed');
    }

    public function test_overview_report_empty_state_then_kpis_low_stock_expiring_recent_and_excludes_reversed(): void
    {
        // empty state before any production exists: sane zeros, not an error
        $emptyOverview = $this->getJson('/api/v1/manufacturing/overview?warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertEquals(0.0, $emptyOverview['kpis']['producedToday']);
        $this->assertEquals(0.0, $emptyOverview['kpis']['productionCostToday']);
        $this->assertNull($emptyOverview['kpis']['avgEfficiency']);
        $this->assertSame(0, $emptyOverview['kpis']['wasteToday']);
        $this->assertSame([], $emptyOverview['recent']);
        $this->assertSame([], $emptyOverview['expiring']);

        $flour = $this->createItem('raw_material', 'kilogram');
        // set a reorder level above what will remain on hand after production consumes 2kg, so it appears in "materials needing attention"
        DB::table('inventory_items')->where('id', $flour)->update(['reorder_level' => '5.000']);
        $this->stockIn($flour, '100', '6');
        $cake = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cake, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
            'shelfLifeValue' => 2, 'shelfLifeUnit' => 'days',
        ], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", [
            'actualQty' => '3', 'waste' => ['qty' => '1', 'unit' => 'piece', 'reason' => 'كسر', 'notes' => 'overview test'],
        ], $this->headers)->assertOk()->json('data');

        $overview = $this->getJson('/api/v1/manufacturing/overview?warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertEquals(3.0, $overview['kpis']['producedToday']);
        $this->assertGreaterThan(0.0, $overview['kpis']['productionCostToday']);
        $this->assertEquals(75.0, $overview['kpis']['avgEfficiency']); // 3 actual / 4 planned * 100
        $this->assertSame(1, $overview['kpis']['wasteToday']);
        $this->assertNotEmpty(array_filter($overview['attention'], fn ($a) => str_contains($a['need'], '5'))); // flour below its 5kg reorder level
        $this->assertNotEmpty(array_filter($overview['expiring'], fn ($e) => $e['id'] === $completed['id']));
        $this->assertNotEmpty(array_filter($overview['recent'], fn ($r) => $r['id'] === $completed['id']));
        $this->assertNotEmpty($overview['topCost']);

        // reverse the production — it must drop out of the ACTIVE kpi totals (producedToday/productionCostToday)
        $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'overview reversal test'], $this->headers)->assertOk();
        $afterReverse = $this->getJson('/api/v1/manufacturing/overview?warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertEquals(0.0, $afterReverse['kpis']['producedToday']);
        $this->assertEquals(0.0, $afterReverse['kpis']['productionCostToday']);

        // tenant scope: a second tenant sees none of this
        $tenantB = (int) DB::table('tenants')->insertGetId(['name' => 'mfg-overview-b', 'slug' => 'mfg-overview-b-'.uniqid(), 'status' => 'active', 'plan' => 'starter', 'currency' => 'SYP', 'timezone' => 'Asia/Damascus', 'created_at' => now(), 'updated_at' => now()]);
        $userB = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantB, 'name' => 'Owner B', 'email' => 'overview-b-'.uniqid().'@example.test', 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $tokenB = 'mfg-overview-token-'.uniqid();
        DB::table('api_tokens')->insert(['tenant_id' => $tenantB, 'user_id' => $userB, 'name' => 'mfg-overview-b', 'token_hash' => hash('sha256', $tokenB), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $overviewB = $this->getJson('/api/v1/manufacturing/overview', ['Authorization' => "Bearer $tokenB", 'X-Tenant-Id' => $tenantB])->assertOk()->json('data');
        $this->assertEquals(0.0, $overviewB['kpis']['producedToday']);
        $this->assertSame([], $overviewB['recent']);
    }

    public function test_reports_endpoint_filters_by_date_product_warehouse_totals_and_excludes_reversed(): void
    {
        $flour = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($flour, '100', '20');
        $cakeA = $this->createItem('finished_good', 'piece');
        $recipeA = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $cakeA, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $flour, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');

        // production inside the target date range
        $draftIn = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipeA['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId, 'date' => '2026-03-15'], $this->headers)->assertCreated()->json('data');
        $completedIn = $this->postJson("/api/v1/manufacturing/production/drafts/{$draftIn['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk()->json('data');

        // production outside the target date range
        $draftOut = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipeA['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId, 'date' => '2026-05-01'], $this->headers)->assertCreated()->json('data');
        $this->postJson("/api/v1/manufacturing/production/drafts/{$draftOut['id']}/complete", ['actualQty' => '4'], $this->headers)->assertOk();

        // date-range filter excludes the out-of-range production
        $ranged = $this->getJson('/api/v1/manufacturing/reports?dateFrom=2026-03-01&dateTo=2026-03-31&warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertEquals(4.0, $ranged['kpis']['totalQty']);
        $this->assertCount(1, array_filter($ranged['expectedVsActual'], fn ($r) => $r['id'] === $completedIn['id']));

        // full range: both productions counted, totals/avgUnitCost/yield/materialConsumption/byProduct/byWarehouse populated
        $full = $this->getJson('/api/v1/manufacturing/reports?dateFrom=2026-01-01&dateTo=2026-12-31&warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertEquals(8.0, $full['kpis']['totalQty']);
        $this->assertGreaterThan(0.0, $full['kpis']['totalCost']);
        $this->assertEquals(round($full['kpis']['totalCost'] / 8.0, 2), $full['kpis']['avgUnitCost']);
        $this->assertEquals(100.0, $full['kpis']['avgEfficiency']);
        $this->assertNotEmpty($full['materialConsumption']);
        $this->assertEquals(4.0, collect($full['materialConsumption'])->firstWhere('unit', 'kilogram')['qty']); // 2kg * 2 productions
        $this->assertNotEmpty($full['byProduct']);
        $this->assertNotEmpty($full['byWarehouse']);
        $this->assertTrue($full['hasData']);

        // product/type filter: matching type keeps both productions, the complementary type excludes them entirely
        $filteredByType = $this->getJson('/api/v1/manufacturing/reports?dateFrom=2026-01-01&dateTo=2026-12-31&warehouseId='.$this->warehouseId.'&type=finished_good', $this->headers)->assertOk()->json('data');
        $this->assertEquals(8.0, $filteredByType['kpis']['totalQty']);
        $filteredOutByType = $this->getJson('/api/v1/manufacturing/reports?dateFrom=2026-01-01&dateTo=2026-12-31&warehouseId='.$this->warehouseId.'&type=semi_finished_good', $this->headers)->assertOk()->json('data');
        $this->assertEquals(0.0, $filteredOutByType['kpis']['totalQty']);

        // warehouse filter: an unrelated warehouse sees nothing
        $otherWarehouseId = (int) DB::table('warehouses')->insertGetId(['tenant_id' => $this->tenant, 'branch_id' => $this->branchId, 'name' => 'Reports Test WH', 'code' => 'MFG-REPORTS-WH-'.uniqid(), 'type' => 'other', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $emptyWarehouse = $this->getJson('/api/v1/manufacturing/reports?dateFrom=2026-01-01&dateTo=2026-12-31&warehouseId='.$otherWarehouseId, $this->headers)->assertOk()->json('data');
        $this->assertEquals(0.0, $emptyWarehouse['kpis']['totalQty']);
        $this->assertFalse($emptyWarehouse['hasData']);

        // reverse the in-range production — reports (completed-only, like overview) must exclude it
        $this->postJson("/api/v1/manufacturing/production/{$completedIn['id']}/reverse", ['reason' => 'reports reversal test'], $this->headers)->assertOk();
        $afterReverse = $this->getJson('/api/v1/manufacturing/reports?dateFrom=2026-03-01&dateTo=2026-03-31&warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertEquals(0.0, $afterReverse['kpis']['totalQty']);
        $this->assertFalse($afterReverse['hasData']);

        // tenant isolation
        $tenantB = (int) DB::table('tenants')->insertGetId(['name' => 'mfg-reports-b', 'slug' => 'mfg-reports-b-'.uniqid(), 'status' => 'active', 'plan' => 'starter', 'currency' => 'SYP', 'timezone' => 'Asia/Damascus', 'created_at' => now(), 'updated_at' => now()]);
        $userB = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantB, 'name' => 'Owner B', 'email' => 'reports-b-'.uniqid().'@example.test', 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $tokenB = 'mfg-reports-token-'.uniqid();
        DB::table('api_tokens')->insert(['tenant_id' => $tenantB, 'user_id' => $userB, 'name' => 'mfg-reports-b', 'token_hash' => hash('sha256', $tokenB), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $reportsB = $this->getJson('/api/v1/manufacturing/reports?dateFrom=2026-01-01&dateTo=2026-12-31', ['Authorization' => "Bearer $tokenB", 'X-Tenant-Id' => $tenantB])->assertOk()->json('data');
        $this->assertEquals(0.0, $reportsB['kpis']['totalQty']);
    }

    public function json($method, $uri, array $data = [], array $headers = [], $options = 0)
    {
        if (($headers['X-Tenant-Id'] ?? null) == $this->tenant && (str_contains($uri, '/manufacturing/') || str_contains($uri, '/inventory/') || str_contains($uri, '/finance/'))) {
            if (strtoupper($method) === 'GET') $uri .= (str_contains($uri, '?') ? '&' : '?').'scopeBranchId='.$this->branchId;
            else $data += ['scopeBranchId' => $this->branchId, 'branchId' => $this->branchId];
        }
        return parent::json($method, $uri, $data, $headers, $options);
    }
    // ---- helpers ----

    public function test_factory_purchase_production_sale_posts_finished_stock_cost_and_margin_with_returns(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['branch_type' => 'factory']);
        DB::table('tenants')->where('id', $this->tenant)->update(['tax_rate' => '0.100000']);
        $material = $this->createItem('raw_material', 'kilogram');
        $product = $this->createItem('finished_good', 'piece');
        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'Factory supplier'], $this->headers)->assertCreated()->json('data.id');
        $purchase = $this->postJson('/api/v1/finance/supplier-invoices', ['supplierId' => $supplier, 'branchId' => $this->branchId,
            'invoiceType' => 'inventory', 'invoiceDate' => '2026-09-26', 'dueDate' => '2026-09-26', 'receiptMode' => 'immediate',
            'lines' => [['lineType' => 'inventory', 'description' => 'Material', 'inventoryItemId' => $material, 'quantity' => '10', 'lineGrossAmount' => '100.00', 'warehouseId' => $this->warehouseId]]], $this->headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchases/$purchase/post", ['idempotencyKey' => 'factory-buy-sale', 'paidAmount' => '0.00'], $this->headers)->assertOk();
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', ['productItemId' => $product, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $material, 'quantity' => '2', 'unit' => 'kilogram']]], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId, 'branchId' => $this->branchId], $this->headers)->assertCreated()->json('data');
        $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '4', 'additionalCosts' => [['type' => 'أجور', 'amount' => '8.00']]], $this->headers)->assertOk();
        $customer = $this->postJson('/api/v1/finance/customers', ['name' => 'Factory customer'], $this->headers)->assertCreated()->json('data.id');
        $sale = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $this->branchId, 'customerId' => $customer, 'invoiceDate' => '2026-09-26',
            'invoiceDiscountType' => 'fixed', 'invoiceDiscountValue' => '2.00', 'manualAdjustment' => '-1.00',
            'charges' => [['name' => 'Delivery', 'amount' => '3.00', 'taxable' => true]],
            'lines' => [['inventoryItemId' => $product, 'quantity' => '2', 'unitCode' => 'piece', 'unitPrice' => '15.00']]], $this->headers)->assertCreated()->json('data');
        $this->assertNull($sale['profitability']);
        $url = '/api/v1/finance/sales-invoices/'.$sale['id'];
        $preview = $this->getJson($url.'/posting-preview', $this->headers)->assertOk()->json('data');
        $this->assertSame($product, $preview['inventory'][0]['materialId']);
        $this->assertCount(1, $preview['inventory']);
        $this->assertSame('10.00', $preview['cogs']['totalEstimated']);
        $post = ['idempotencyKey' => 'factory-sale-post'];
        $posted = $this->postJson($url.'/post', $post, $this->headers)->assertOk()->json('data');
        $this->postJson($url.'/post', $post, $this->headers)->assertOk();
        $this->assertSame('30.00', $posted['profitability']['netRevenue']);
        $this->assertSame('10.00', $posted['profitability']['netCogs']);
        $this->assertSame('20.00', $posted['profitability']['grossProfit']);
        $this->assertSame('66.67', $posted['profitability']['grossMarginPercent']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $material, 'quantity_on_hand' => '8.000']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $product, 'quantity_on_hand' => '2.000']);
        $this->assertDatabaseHas('manufacturing_batches', ['manufacturing_order_id' => $draft['id'], 'remaining_quantity' => '2.000']);
        $this->assertSame(1, DB::table('stock_movements')->where('reference_type', 'sales_invoice_line')->where('reference_id', $posted['lines'][0]['id'])->count());
        $this->assertSame(1, DB::table('sales_invoice_postings')->where('sales_invoice_id', $sale['id'])->count());
        $this->stockIn($product, '20', '2');
        $this->getJson($url, $this->headers)->assertOk()->assertJsonPath('data.profitability.netCogs', '10.00')->assertJsonPath('data.profitability.grossProfit', '20.00');
        $credit = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $sale['id'], 'creditDate' => '2026-09-26', 'reason' => 'Return',
            'lines' => [['originalSalesInvoiceLineId' => $posted['lines'][0]['id'], 'quantity' => '1', 'restock' => true]]], $this->headers)->assertCreated()->json('data');
        $creditPosted = $this->postJson('/api/v1/finance/sales-credit-notes/'.$credit['id'].'/post', ['idempotencyKey' => 'factory-return'], $this->headers)->assertOk()->json('data');
        $after = $this->getJson($url, $this->headers)->assertOk()->json('data.profitability');
        $this->assertSame('5.00', $after['costReversed']);
        $this->assertSame('5.00', $after['netCogs']);
        $this->assertEquals(30 - ((float) $creditPosted['total'] - (float) $creditPosted['taxTotal']), (float) $after['netRevenue']);
    }

    public function test_factory_sales_catalogue_excludes_unassigned_items_and_rejects_cafe_product_lines(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['branch_type' => 'factory']);
        $item = $this->createItem('finished_good', 'piece');
        $foreign = $this->createItem('finished_good', 'piece');
        DB::table('inventory_item_warehouses')->where('inventory_item_id', $foreign)->delete();
        $ids = $this->getJson('/api/v1/finance/sales-materials?branchId='.$this->branchId, $this->headers)->assertOk()->json('data');
        $this->assertContains($item, array_column($ids, 'id'));
        $this->assertNotContains($foreign, array_column($ids, 'id'));
        $customer = $this->postJson('/api/v1/finance/customers', ['name' => 'Factory customer'], $this->headers)->assertCreated()->json('data.id');
        $header = ['branchId' => $this->branchId, 'customerId' => $customer, 'invoiceDate' => '2026-09-26'];
        $this->postJson('/api/v1/finance/sales-invoices', $header + ['lines' => [['productId' => 999, 'quantity' => '1']]], $this->headers)->assertUnprocessable()->assertJsonValidationErrors('lines');
        $this->postJson('/api/v1/finance/sales-invoices', $header + ['lines' => [['inventoryItemId' => $foreign, 'quantity' => '1', 'unitPrice' => '10.00']]], $this->headers)->assertUnprocessable()->assertJsonValidationErrors('lines');
    }

    public function test_factory_purchase_to_production_uses_warehouse_cost_and_actual_yield_once(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['branch_type' => 'factory']);
        $material = $this->createItem('raw_material', 'kilogram');
        $product = $this->createItem('finished_good', 'piece');
        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'Factory supplier'], $this->headers)->assertCreated()->json('data.id');
        $invoice = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplier, 'branchId' => $this->branchId, 'invoiceType' => 'inventory',
            'invoiceDate' => '2026-09-26', 'dueDate' => '2026-09-26', 'receiptMode' => 'immediate',
            'lines' => [['lineType' => 'inventory', 'description' => 'Flour', 'inventoryItemId' => $material,
                'quantity' => '10.000', 'lineGrossAmount' => '100.00', 'warehouseId' => $this->warehouseId]],
        ], $this->headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchases/$invoice/post", ['idempotencyKey' => 'factory-buy', 'paidAmount' => '0.00'], $this->headers)->assertOk();
        // A catalogue cost from another warehouse must not replace this warehouse's WAC.
        DB::table('inventory_items')->where('id', $material)->update(['cost_per_unit' => '99.0000']);
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', [
            'productItemId' => $product, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $material, 'quantity' => '2', 'unit' => 'kilogram']],
        ], $this->headers)->assertCreated()->json('data');
        $preview = $this->getJson('/api/v1/manufacturing/production/preview?recipeId='.$recipe['id'].'&qty=4&warehouseId='.$this->warehouseId.'&branchId='.$this->branchId, $this->headers)->assertOk()->json('data');
        $this->assertEquals(20, $preview['batchCost']);
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId, 'branchId' => $this->branchId], $this->headers)->assertCreated()->json('data');
        $this->assertNotEmpty($draft['consumption'][0]['name']);
        $journals = DB::table('journal_entries')->where('tenant_id', $this->tenant)->count();
        $payload = ['actualQty' => '3', 'waste' => ['qty' => '1', 'reason' => 'كسر'],
            'additionalCosts' => [['type' => 'أجور', 'amount' => '7.00'], ['type' => 'كهرباء', 'amount' => '3.00']],
            'idempotencyKey' => 'factory-complete'];
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", $payload, $this->headers)->assertOk()->json('data');
        $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", $payload, $this->headers)->assertOk();
        $this->assertEquals(20, $completed['actualCost']);
        $this->assertEquals(6.6667, $completed['actualUnitCost']);
        $this->assertEquals(30, $completed['fullCost']);
        $this->assertEquals(10, $completed['fullUnitCost']);
        $this->assertSame('piece', $completed['waste']['unit']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $material, 'quantity_on_hand' => '8.000']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $product, 'quantity_on_hand' => '3.000', 'average_unit_cost' => '6.6667']);
        $this->assertSame(2, DB::table('stock_movements')->where('reference_type', 'manufacturing_order')->where('reference_id', $draft['id'])->count());
        $this->assertSame($journals, DB::table('journal_entries')->where('tenant_id', $this->tenant)->count());
        $payload['additionalCosts'][0]['amount'] = '8.00';
        $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", $payload, $this->headers)->assertStatus(409);
    }

    public function test_factory_scope_and_missing_stock_are_reported_before_production(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['branch_type' => 'factory']);
        $material = $this->createItem('raw_material', 'kilogram');
        $product = $this->createItem('finished_good', 'piece');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', ['productItemId' => $product, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $material, 'quantity' => '2', 'unit' => 'kilogram']]], $this->headers)->assertCreated()->json('data');
        $preview = $this->getJson('/api/v1/manufacturing/production/preview?recipeId='.$recipe['id'].'&qty=4&warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertTrue($preview['hasInsufficient']);
        $this->assertEquals(0, $preview['rows'][0]['available']);
        $this->stockIn($material, '10', '10');
        DB::table('stock_balances')->where('warehouse_id', $this->warehouseId)->where('inventory_item_id', $material)->update(['reserved_quantity' => '9.000']);
        $reservedPreview = $this->getJson('/api/v1/manufacturing/production/preview?recipeId='.$recipe['id'].'&qty=4&warehouseId='.$this->warehouseId, $this->headers)->assertOk()->json('data');
        $this->assertTrue($reservedPreview['hasInsufficient']);
        $this->assertEquals(1, $reservedPreview['rows'][0]['available']);
        $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated();
        $this->getJson('/api/v1/manufacturing/production?branchId='.$this->branchId, $this->headers)->assertOk()->assertJsonCount(1, 'data');
        $wrongWarehouse = DB::table('warehouses')->where('tenant_id', $this->tenant)->where('branch_id', '!=', $this->branchId)->value('id');
        $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $wrongWarehouse, 'branchId' => $this->branchId], $this->headers)->assertUnprocessable()->assertJsonValidationErrors('warehouseId');
        DB::table('inventory_item_warehouses')->where('inventory_item_id', $product)->where('warehouse_id', $this->warehouseId)->delete();
        $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertUnprocessable()->assertJsonValidationErrors('warehouseId');
    }

    public function test_production_output_conversion_preserves_value_batch_and_full_reversal(): void
    {
        $material = $this->createItem('raw_material', 'kilogram');
        $this->stockIn($material, '10', '10');
        $product = $this->createItem('finished_good', 'gram');
        $this->postJson("/api/v1/inventory/items/$product/unit-conversions", ['sourceUnit' => 'kilogram', 'targetUnit' => 'gram', 'factor' => '1000', 'isActive' => true], $this->headers)->assertCreated();
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', ['productItemId' => $product, 'outputQuantity' => '1', 'outputUnit' => 'kilogram',
            'lines' => [['inventoryItemId' => $material, 'quantity' => '2', 'unit' => 'kilogram']]], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '1', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $completed = $this->postJson("/api/v1/manufacturing/production/drafts/{$draft['id']}/complete", ['actualQty' => '1'], $this->headers)->assertOk()->json('data');
        $this->assertEquals(20, $completed['actualUnitCost']);
        $this->assertEquals(0, $completed['soldQty']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $product, 'quantity_on_hand' => '1000.000', 'average_unit_cost' => '0.0200']);
        $this->assertDatabaseHas('manufacturing_batches', ['manufacturing_order_id' => $draft['id'], 'produced_quantity' => '1000.000', 'remaining_quantity' => '1000.000']);
        $this->postJson("/api/v1/manufacturing/production/{$completed['id']}/reverse", ['reason' => 'Test conversion reversal'], $this->headers)->assertOk();
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $product, 'quantity_on_hand' => '0.000']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $material, 'quantity_on_hand' => '10.000']);
    }

    public function test_production_completion_rejects_foreign_consumption_and_records_zero_override(): void
    {
        $material = $this->createItem('raw_material', 'kilogram');
        $other = $this->createItem('packaging', 'piece');
        $product = $this->createItem('finished_good', 'piece');
        $this->stockIn($material, '10', '10');
        $recipe = $this->postJson('/api/v1/manufacturing/recipes', ['productItemId' => $product, 'outputQuantity' => '4', 'outputUnit' => 'piece',
            'lines' => [['inventoryItemId' => $material, 'quantity' => '2', 'unit' => 'kilogram'], ['inventoryItemId' => $other, 'quantity' => '1', 'unit' => 'piece']]], $this->headers)->assertCreated()->json('data');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe['id'], 'qty' => '4', 'warehouseId' => $this->warehouseId], $this->headers)->assertCreated()->json('data');
        $url = "/api/v1/manufacturing/production/drafts/{$draft['id']}/complete";
        $this->postJson($url, ['actualQty' => '4', 'consumption' => [['materialId' => $product, 'actual' => '1']]], $this->headers)->assertUnprocessable();
        $this->postJson($url, ['actualQty' => '4'], $this->headers)->assertUnprocessable();
        // Failure on the second material must roll back the first material's consumption.
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $material, 'quantity_on_hand' => '10.000']);
        $this->assertSame(0, DB::table('stock_movements')->where('reference_type', 'manufacturing_order')->where('reference_id', $draft['id'])->count());
        $completed = $this->postJson($url, ['actualQty' => '4', 'consumption' => [['materialId' => $other, 'actual' => '0']]], $this->headers)->assertOk()->json('data');
        $this->assertEquals(0, collect($completed['materialsConsumed'])->firstWhere('materialId', $other)['actual']);
    }

    public function test_factory_count_uses_assigned_stock_and_posts_reviewed_variance_once(): void
    {
        DB::table('branches')->where('id', $this->branchId)->update(['branch_type' => 'factory']);
        $raw = $this->createItem('raw_material', 'kilogram');
        $finished = $this->createItem('finished_good', 'piece');
        $foreign = $this->createItem('packaging', 'piece');
        DB::table('inventory_item_warehouses')->where('inventory_item_id', $foreign)->delete();
        $this->stockIn($raw, '10', '10');
        $this->stockIn($finished, '5', '4');
        $this->assertSame('factory', DB::table('branches')->where('id', $this->branchId)->value('branch_type'));
        $otherWarehouse = (int) DB::table('warehouses')->where('tenant_id', $this->tenant)->where(fn ($query) => $query->whereNull('branch_id')->orWhere('branch_id', '<>', $this->branchId))->value('id');
        $this->postJson('/api/v1/inventory/counts', ['branchId' => $this->branchId, 'warehouseId' => $otherWarehouse, 'countDate' => '2026-09-26'], $this->headers)->assertUnprocessable();
        $this->getJson('/api/v1/inventory/counts?branchId='.$this->branchId.'&warehouseId='.$otherWarehouse, $this->headers)->assertUnprocessable();
        $count = $this->postJson('/api/v1/inventory/counts', ['branchId' => $this->branchId, 'warehouseId' => $this->warehouseId, 'countDate' => '2026-09-26'], $this->headers)->assertCreated()->json('data.id');
        $url = '/api/v1/inventory/counts/'.$count;
        $detail = $this->getJson($url, $this->headers)->assertOk()->json('data');
        $this->assertContains($raw, array_column($detail['lines'], 'itemId'));
        $this->assertContains($finished, array_column($detail['lines'], 'itemId'));
        $this->assertNotContains($foreign, array_column($detail['lines'], 'itemId'));
        $this->postJson($url.'/start', [], $this->headers)->assertOk();
        $this->postJson($url.'/submit', [], $this->headers)->assertUnprocessable();
        foreach ($detail['lines'] as $line) {
            if (! in_array($line['itemId'], [$raw, $finished])) {
                $this->putJson($url.'/lines', ['itemId' => $line['itemId'], 'countedQuantity' => $line['expectedQuantity']], $this->headers)->assertOk();
            }
        }
        $this->putJson($url.'/lines', ['itemId' => $raw, 'countedQuantity' => '9', 'reason' => 'Physical shortage'], $this->headers)->assertOk();
        $this->putJson($url.'/lines', ['itemId' => $finished, 'countedQuantity' => '4'], $this->headers)->assertOk();
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $raw, 'quantity_on_hand' => '10.000']);
        $this->postJson($url.'/post', [], $this->headers)->assertUnprocessable();
        $this->postJson($url.'/submit', [], $this->headers)->assertOk();
        $this->postJson($url.'/approve', [], $this->headers)->assertOk();
        $this->postJson($url.'/post', [], $this->headers)->assertOk()->assertJsonPath('data.status', 'posted');
        $this->postJson($url.'/post', [], $this->headers)->assertUnprocessable();
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $raw, 'quantity_on_hand' => '9.000']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $this->warehouseId, 'inventory_item_id' => $finished, 'quantity_on_hand' => '4.000']);
        $this->assertSame(1, DB::table('stock_movements')->where('reference_type', 'stock_count')->where('reference_id', $count)->count());
        $this->assertDatabaseHas('stock_movements', ['reference_type' => 'stock_count', 'reference_id' => $count, 'total_cost' => '10.00']);
    }

    private function headersForRole(string $role, bool $factoryBranch = false): array
    {
        $roleId = (int) DB::table('tenant_roles')->where('tenant_id', $this->tenant)->where('code', $role)->value('id');
        $userId = (int) DB::table('users')->insertGetId([
            'tenant_id' => $this->tenant, 'tenant_role_id' => $roleId ?: null, 'name' => ucfirst($role).' Test User', 'email' => $role.'-'.uniqid().'@example.test',
            'password' => bcrypt('password'), 'role' => $role, 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        // Grant access to the test branch so a permission check below tests the
        // Manufacturing role gate itself, not an unrelated branch-scope 403.
        // factory_manager also needs a branch_type='factory' assignment or
        // ManufacturingAccess rejects it for having no factory branch at all;
        // it keeps $this->branchId too since the order/warehouse under test
        // here belongs to it (phase 1 does not yet restrict *which* branch a
        // manufacturing action may target — see prompt 6 of the execution plan).
        $branchIds = [$this->branchId];
        if ($factoryBranch) {
            $branchIds[] = (int) DB::table('branches')->insertGetId([
                'tenant_id' => $this->tenant, 'name' => 'Factory Test Branch '.uniqid(), 'branch_type' => 'factory',
                'currency' => 'SYP', 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
        foreach ($branchIds as $branchId) {
            DB::table('user_branches')->insert(['tenant_id' => $this->tenant, 'user_id' => $userId, 'branch_id' => $branchId, 'created_at' => now(), 'updated_at' => now()]);
        }
        $token = 'mfg-'.$role.'-token-'.uniqid();
        DB::table('api_tokens')->insert(['tenant_id' => $this->tenant, 'user_id' => $userId, 'name' => 'mfg-'.$role, 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $this->tenant];
    }

    private function createItem(string $itemType, string $unit, bool $active = true): int
    {
        $id = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'صنف اختبار '.uniqid(), 'nameEn' => 'Test Item '.uniqid(),
            'sku' => 'MFG-TEST-'.uniqid(), 'itemType' => $itemType, 'unit' => $unit,
            'minimumStock' => '0', 'reorderLevel' => '0', 'isActive' => $active, 'warehouseIds' => [$this->warehouseId],
        ], $this->headers)->assertCreated()->json('data.id');

        return $id;
    }

    private function stockIn(int $itemId, string $unitCost, string $quantity): void
    {
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $this->warehouseId, 'itemId' => $itemId, 'type' => 'stock_in', 'quantity' => $quantity, 'unitCost' => $unitCost, 'reason' => 'Manufacturing test opening stock',
        ], $this->headers)->assertCreated();
    }
}
