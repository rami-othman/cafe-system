<?php
namespace Tests\Feature\Manufacturing;
use App\Models\User;
use App\Services\FinancialSetupService;
use App\Services\UserBranchAssignmentService;
use App\Support\BranchScope;
use App\Support\FactoryWarehouseScope;
use App\Support\FinancialActor;
use Database\Seeders\ManufacturingDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;
class FactoryIsolationTest extends TestCase {
    use RefreshDatabase;
    private int $tenant; private int $factory; private int $cafe; private int $warehouse; private array $headers; private array $ownerHeaders;
    protected function setUp(): void {
        parent::setUp(); $this->seed(); $this->seed(ManufacturingDemoSeeder::class);
        $this->tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $this->factory = (int) DB::table('branches')->where('tenant_id', $this->tenant)->where('branch_type', 'factory')->value('id');
        $this->cafe = (int) DB::table('branches')->where('tenant_id', $this->tenant)->where('branch_type', 'cafe')->value('id');
        app(FinancialSetupService::class)->ensureBranchWarehouse($this->tenant, $this->cafe);
        $this->warehouse = (int) DB::table('branches')->where('id', $this->factory)->value('default_warehouse_id');
        $user = User::where('email', 'factory.demo@cafe618.test')->firstOrFail();
        $this->headers = $this->token($user);
        $this->ownerHeaders = $this->token(User::where('tenant_id', $this->tenant)->where('role', 'owner')->firstOrFail());
    }
    private function token(User $user): array { $token = uniqid('isolation-', true); DB::table('api_tokens')->insert(['tenant_id' => $this->tenant, 'user_id' => $user->id, 'name' => 'isolation', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addHour(), 'created_at' => now(), 'updated_at' => now()]); return ['Authorization' => 'Bearer '.$token, 'X-Tenant-Id' => $this->tenant]; }
    public function test_cafe_cashier_shift_order_discount_payment_close_and_manager_access(): void {
        $branch = (int) DB::table('branches')->where('tenant_id', $this->tenant)->where('name', 'Downtown')->value('id');
        $cashier = $this->token(User::where('email', 'cashier@cafe618.local')->firstOrFail());
        $shift = $this->postJson('/api/v1/shifts/current', ['branchId' => $branch, 'openingCash' => '0.00'], $cashier)->assertCreated()->json('data.id');
        $product = (int) DB::table('products')->where('tenant_id', $this->tenant)->where('name', 'Espresso')->value('id');
        $modifiers = DB::table('product_modifier_group as p')->join('modifier_groups as g', 'g.id', '=', 'p.modifier_group_id')->join('modifier_options as o', 'o.modifier_group_id', '=', 'g.id')->where('p.product_id', $product)->where('g.is_required', true)->where('o.is_default', true)->get(['o.id as optionId'])->map(fn ($row) => ['optionId' => (int) $row->optionId])->all();
        $order = $this->postJson('/api/v1/orders', ['branchId' => $branch, 'shiftId' => $shift, 'orderType' => 'takeaway', 'items' => [['productId' => $product, 'quantity' => 1, 'modifiers' => $modifiers]]], $cashier)->assertCreated()->json('data.id');
        $discount = (int) DB::table('discounts')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Cafe regression', 'application_mode' => 'manual', 'type' => 'percentage', 'value' => 10, 'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $amount = $this->postJson('/api/v1/orders/'.$order.'/discounts/apply', ['discountId' => $discount], $cashier)->assertOk()->json('data.totals.total');
        $this->postJson('/api/v1/orders/'.$order.'/pay', ['method' => 'cash', 'amount' => $amount, 'idempotencyKey' => 'cafe-regression-pay'], $cashier)->assertOk();
        $this->postJson('/api/v1/shifts/'.$shift.'/close', ['closingCash' => $amount], $cashier)->assertOk();
        $this->assertDatabaseHas('orders', ['id' => $order, 'payment_status' => 'paid']);
        $this->assertDatabaseHas('shifts', ['id' => $shift, 'status' => 'closed']);
        $manager = $this->token(User::where('email', 'manager@cafe618.local')->firstOrFail());
        DB::table('finance_role_permissions')->updateOrInsert(['tenant_id' => $this->tenant, 'role' => 'manager', 'permission' => 'finance.view'], ['created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/v1/finance/dashboard?branchId='.$branch, $manager)->assertOk();
        $this->getJson('/api/v1/inventory/items', $manager)->assertOk();
        $this->getJson('/api/v1/manufacturing/overview', $manager)->assertForbidden();
    }
    public function test_private_materials_crud_lookup_and_default_warehouse(): void {
        $id = $this->postJson('/api/v1/inventory/items', ['nameAr' => 'مادة خاصة', 'nameEn' => 'Private', 'itemType' => 'raw_material', 'unit' => 'kilogram', 'isActive' => true, 'minimumStock' => '0', 'reorderLevel' => '0'], $this->headers)->assertCreated()->assertJsonPath('data.ownerBranchId', $this->factory)->json('data.id');
        $this->assertDatabaseHas('inventory_item_warehouses', ['inventory_item_id' => $id, 'warehouse_id' => $this->warehouse]);
        $this->getJson('/api/v1/inventory/items/'.$id, $this->ownerHeaders)->assertNotFound();
        $this->getJson('/api/v1/inventory/items/'.$id.'?scopeBranchId='.$this->factory, $this->ownerHeaders)->assertOk();
        $rows = $this->getJson('/api/v1/inventory/items?scopeBranchId='.$this->cafe, $this->headers)->assertOk()->json('data.items');
        foreach ($rows as $row) $this->assertSame($this->factory, $row['ownerBranchId']);
        $this->assertNull(DB::table('branches')->where('id', $this->factory)->value('pos_inventory_warehouse_id'));
        $this->assertSame('factory', DB::table('warehouses')->where('id', $this->warehouse)->value('type'));
    }
    public function test_customer_import_and_group_names_are_private_to_each_scope(): void {
        $csv = "name;phone;group\nScoped imported;091234567;Shared name\n";
        $path = '/api/v1/admin/customer-management/customer-imports';
        $cafeImport = $this->post($path.'/preview', ['file' => \Illuminate\Http\UploadedFile::fake()->createWithContent('customers.csv', $csv)], $this->ownerHeaders)->assertCreated()->json('data.id');
        $this->postJson($path.'/'.$cafeImport.'/commit', ['createMissingGroups' => true], $this->ownerHeaders)->assertOk();
        $factoryImport = $this->post($path.'/preview?scopeBranchId='.$this->factory, ['file' => \Illuminate\Http\UploadedFile::fake()->createWithContent('customers.csv', $csv)], $this->ownerHeaders)->assertCreated()->json('data.id');
        $this->getJson($path.'/'.$factoryImport, $this->ownerHeaders)->assertNotFound();
        $this->postJson($path.'/'.$factoryImport.'/commit?scopeBranchId='.$this->factory, ['createMissingGroups' => true], $this->ownerHeaders)->assertOk();
        $this->assertSame(2, DB::table('customers')->where('tenant_id', $this->tenant)->where('name', 'Scoped imported')->count());
        $this->assertSame(2, DB::table('customer_groups')->where('tenant_id', $this->tenant)->where('name', 'Shared name')->count());
        $this->assertDatabaseHas('customers', ['name' => 'Scoped imported', 'owner_branch_id' => $this->factory]);
        $migration = require database_path('migrations/2026_10_06_000007_scope_customer_imports_and_group_names.php');
        try {
            $migration->down();
            $this->fail('Rollback must refuse names that are duplicated across scopes.');
        } catch (\RuntimeException $exception) {
            $this->assertSame('Scoped group names need manual resolution before rollback; no data was deleted.', $exception->getMessage());
        }
        $this->assertSame(2, DB::table('customer_groups')->where('tenant_id', $this->tenant)->where('name', 'Shared name')->count());
        $this->assertTrue(\Illuminate\Support\Facades\Schema::hasColumn('customer_imports', 'owner_branch_id'));
    }
    public function test_recipe_and_ingredient_reads_are_private_and_paginated(): void {
        $this->getJson('/api/v1/manufacturing/ingredients?perPage=2', $this->headers)->assertOk()->assertJsonCount(2, 'data')->assertJsonPath('meta.currentPage', 1);
        $recipe = DB::table('manufacturing_recipes')->where('branch_id', $this->factory)->first();
        $this->getJson('/api/v1/manufacturing/recipes/'.$recipe->id, $this->headers)->assertOk();
        $other = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Other factory', 'branch_type' => 'factory', 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/v1/manufacturing/recipes/'.$recipe->id.'?scopeBranchId='.$other, $this->ownerHeaders)->assertNotFound();
        $this->postJson('/api/v1/manufacturing/production/drafts', ['branchId' => $this->cafe, 'recipeId' => $recipe->id, 'qty' => '1', 'warehouseId' => $this->warehouse], $this->ownerHeaders)->assertUnprocessable();
        $this->artisan('factory:backfill-recipes')->assertSuccessful();
        $this->artisan('factory:backfill-items')->assertSuccessful();
    }
    public function test_global_finance_locations_and_null_branch_are_rejected(): void {
        $cafeCustomer = (int) DB::table('customers')->where('tenant_id', $this->tenant)->whereNull('owner_branch_id')->value('id');
        $this->getJson('/api/v1/finance/reports/customer-statement?customerId='.$cafeCustomer, $this->headers)->assertNotFound();
        $actor = User::where('email', 'factory.demo@cafe618.test')->firstOrFail();
        $q = DB::table('financial_locations')->where('tenant_id', $this->tenant);
        BranchScope::applyFinancial($q, 'branch_id', $actor);
        $this->assertNotEmpty($q->get()); foreach ($q->get() as $row) $this->assertSame($this->factory, (int) $row->branch_id);
        try { FinancialActor::assertBranchAccess($actor->id, $this->tenant, null); $this->fail('Global financial access must fail'); } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) { $this->assertSame(403, $e->getStatusCode()); }
        $cash = app(\App\Services\CashSourceResolver::class)->resolve($this->tenant, $actor->id, $this->factory);
        $this->assertNull($cash->shift); $this->assertSame($this->factory, (int) $cash->location->branch_id);
        $global = DB::table('financial_locations')->where('tenant_id', $this->tenant)->whereNull('branch_id')->where('kind', 'cash')->first();
        $this->assertNotNull($global);
        try { app(\App\Services\CashSourceResolver::class)->resolve($this->tenant, $actor->id, $this->factory, (int) $global->id); $this->fail('Global cash must be rejected'); } catch (\Illuminate\Validation\ValidationException $e) { $this->assertArrayHasKey('financialLocationId', $e->errors()); }
    }
    public function test_warehouse_boundaries_and_factory_pos_are_rejected(): void {
        try { FactoryWarehouseScope::assertWarehouseForBranch($this->tenant, $this->cafe, $this->warehouse); $this->fail('Cafe must not use factory warehouse'); } catch (\Illuminate\Validation\ValidationException $e) { $this->assertArrayHasKey('warehouseId', $e->errors()); }
        try { app(\App\Services\PosInventoryWarehouseResolver::class)->forBranch($this->tenant, $this->factory); $this->fail('Factory must not resolve POS'); } catch (\App\Exceptions\OrderLifecycleException $e) { $this->assertSame('FACTORY_POS_FORBIDDEN', $e->domainCode); }
    }
    public function test_internal_party_setup_is_idempotent_and_owner_only(): void {
        $this->artisan('factory:setup-internal-parties')->assertSuccessful();
        $this->assertSame(0, DB::table('customers')->where('is_internal', true)->count());
        $this->artisan('factory:setup-internal-parties', ['--apply' => true])->assertSuccessful(); $count = DB::table('customers')->where('is_internal', true)->count();
        $this->artisan('factory:setup-internal-parties', ['--apply' => true])->assertSuccessful(); $this->assertSame($count, DB::table('customers')->where('is_internal', true)->count());
        $this->postJson('/api/v1/finance/customers', ['name' => 'Illegal', 'isInternal' => true, 'internalBranchId' => $this->cafe], $this->headers)->assertForbidden();
        $this->getJson('/api/v1/finance/reports/internal-reconciliation', $this->ownerHeaders)->assertOk()->assertJsonPath('data.0.difference', '0.00');
        $this->getJson('/api/v1/finance/reports/internal-reconciliation', $this->headers)->assertForbidden();
        $this->postJson('/api/v1/finance/customers', ['name' => 'Wrong scope', 'isInternal' => true, 'internalBranchId' => $this->cafe], $this->ownerHeaders)->assertUnprocessable();
        $this->postJson('/api/v1/finance/suppliers?scopeBranchId='.$this->factory, ['name' => 'Wrong factory supplier', 'isInternal' => true, 'internalBranchId' => $this->factory], $this->ownerHeaders)->assertUnprocessable();
    }
    public function test_master_data_crud_isolation_and_invoice_catalogs(): void {
        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'Factory supplier'], $this->headers)->assertCreated()->json('data.id');
        $customer = $this->postJson('/api/v1/finance/customers', ['name' => 'Factory customer'], $this->headers)->assertCreated()->json('data.id');
        $this->getJson('/api/v1/finance/suppliers/'.$supplier, $this->ownerHeaders)->assertNotFound();
        $this->getJson('/api/v1/finance/customers/'.$customer, $this->ownerHeaders)->assertNotFound();
        $this->getJson('/api/v1/finance/suppliers/'.$supplier, $this->headers)->assertOk();
        $this->getJson('/api/v1/finance/customers/'.$customer, $this->headers)->assertOk();
        $this->artisan('factory:setup-catalogs', ['--apply' => true])->assertSuccessful();
        $types = DB::table('invoice_types')->where('owner_branch_id', $this->factory)->get();
        $this->assertNotEmpty($types); foreach ($types as $type) $this->assertStringStartsWith('f'.$this->factory.'_', $type->code);
        $count = $types->count(); $this->artisan('factory:setup-catalogs', ['--apply' => true])->assertSuccessful();
        $this->assertSame($count, DB::table('invoice_types')->where('owner_branch_id', $this->factory)->count());
    }
    public function test_cross_scope_item_backfill_refuses_to_write(): void {
        $item = DB::table('inventory_items')->where('owner_branch_id', $this->factory)->first();
        $cafeWarehouse = (int) DB::table('branches')->where('id', $this->cafe)->value('pos_inventory_warehouse_id');
        DB::table('inventory_item_warehouses')->insert(['tenant_id' => $this->tenant, 'inventory_item_id' => $item->id, 'warehouse_id' => $cafeWarehouse, 'created_at' => now(), 'updated_at' => now()]);
        $this->artisan('factory:backfill-items', ['--apply' => true])->assertFailed();
        $this->assertSame($this->factory, (int) DB::table('inventory_items')->where('id', $item->id)->value('owner_branch_id'));
    }
    public function test_produce_sell_buy_and_independent_settlements_zero_both_debts(): void {
        $this->artisan('factory:setup-internal-parties', ['--apply' => true])->assertSuccessful();
        $recipe = DB::table('manufacturing_recipes as r')->join('inventory_items as i', 'i.id', '=', 'r.product_item_id')->where('r.branch_id', $this->factory)->where('i.name_en', 'Butter Croissant')->select('r.*')->first();
        $qty = (string) DB::table('manufacturing_recipe_versions')->where('id', $recipe->current_version_id)->value('output_quantity');
        $draft = $this->postJson('/api/v1/manufacturing/production/drafts', ['recipeId' => $recipe->id, 'qty' => $qty, 'warehouseId' => $this->warehouse, 'idempotencyKey' => 'isolation-production'], $this->headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/manufacturing/production/drafts/'.$draft.'/complete', ['actualQty' => $qty, 'idempotencyKey' => 'isolation-complete'], $this->headers)->assertOk();
        $customer = (int) DB::table('customers')->where('owner_branch_id', $this->factory)->where('internal_branch_id', $this->cafe)->value('id');
        $sale = $this->postJson('/api/v1/finance/sales-invoices', ['customerId' => $customer, 'invoiceDate' => now()->toDateString(), 'lines' => [['inventoryItemId' => $recipe->product_item_id, 'quantity' => '1', 'unitPrice' => '100.00']]], $this->headers)->assertCreated()->json('data');
        $this->postJson('/api/v1/finance/sales-invoices/'.$sale['id'].'/post', ['idempotencyKey' => 'isolation-sale'], $this->headers)->assertOk();
        $reportPath = '/api/v1/finance/reports/profit-loss?comparison=none&dateFrom='.now()->toDateString().'&dateTo='.now()->toDateString();
        $this->getJson($reportPath, $this->ownerHeaders)->assertOk()->assertJsonPath('data.totals.revenue', '0.00');
        $this->getJson($reportPath.'&includeInternal=1', $this->ownerHeaders)->assertOk()->assertJsonPath('data.totals.revenue', '100.00');
        $this->getJson($reportPath.'&branchId='.$this->factory, $this->ownerHeaders)->assertOk()->assertJsonPath('data.totals.revenue', '100.00');
        $before = DB::table('stock_balances')->where('warehouse_id', $this->warehouse)->where('inventory_item_id', $recipe->product_item_id)->value('quantity_on_hand');
        $supplier = (int) DB::table('suppliers')->where('tenant_id', $this->tenant)->where('internal_branch_id', $this->factory)->value('id');
        $cafeWarehouse = (int) DB::table('branches')->where('id', $this->cafe)->value('pos_inventory_warehouse_id');
        $item = $this->postJson('/api/v1/inventory/items', ['nameAr' => 'كيك الكافيه', 'nameEn' => 'Cafe cake', 'sku' => 'CAFE-ISOLATION', 'itemType' => 'finished_good', 'unit' => 'piece', 'isActive' => true, 'minimumStock' => '0', 'reorderLevel' => '0', 'warehouseIds' => [$cafeWarehouse]], $this->ownerHeaders)->assertCreated()->json('data.id');
        $purchase = $this->postJson('/api/v1/finance/supplier-invoices', ['branchId' => $this->cafe, 'supplierId' => $supplier, 'invoiceNumber' => 'ISOLATION-PURCHASE', 'invoiceDate' => now()->toDateString(), 'dueDate' => now()->toDateString(), 'invoiceType' => 'inventory', 'receiptMode' => 'immediate', 'lines' => [['lineType' => 'inventory', 'description' => 'Cake', 'inventoryItemId' => $item, 'warehouseId' => $cafeWarehouse, 'quantity' => '1', 'lineGrossAmount' => $sale['total']]]], $this->ownerHeaders)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/finance/purchases/'.$purchase.'/post', ['idempotencyKey' => 'isolation-purchase', 'paidAmount' => '0.00'], $this->ownerHeaders)->assertOk();
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $cafeWarehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '1.000']);
        $this->assertSame($before, DB::table('stock_balances')->where('warehouse_id', $this->warehouse)->where('inventory_item_id', $recipe->product_item_id)->value('quantity_on_hand'));
        $method = (int) DB::table('payment_methods')->where('tenant_id', $this->tenant)->where('code', 'CASH')->value('id');
        $drawer = (int) DB::table('branches')->where('id', $this->cafe)->value('pos_cash_financial_location_id');
        $this->postJson('/api/v1/finance/supplier-payments', ['branchId' => $this->cafe, 'supplierId' => $supplier, 'amount' => $sale['total'], 'paymentDate' => now()->toDateString(), 'paymentMethodId' => $method, 'financialLocationId' => $drawer, 'idempotencyKey' => 'isolation-ap', 'allocations' => [['invoiceId' => $purchase, 'amount' => $sale['total']]]], $this->ownerHeaders)->assertCreated();
        $this->postJson('/api/v1/finance/customer-payments', ['customerId' => $customer, 'amount' => $sale['total'], 'paymentDate' => now()->toDateString(), 'paymentMethodId' => $method, 'idempotencyKey' => 'isolation-ar', 'allocations' => [['invoiceId' => $sale['id'], 'amount' => $sale['total']]]], $this->headers)->assertCreated();
        $rows = $this->getJson('/api/v1/finance/reports/internal-reconciliation', $this->ownerHeaders)->assertOk()->json('data');
        $row = collect($rows)->firstWhere('cafeBranchId', $this->cafe);
        $this->assertSame('0.00', $row['factoryReceivable']); $this->assertSame('0.00', $row['cafePayable']);
        $this->assertSame(0, DB::table('warehouse_transfers')->where('tenant_id', $this->tenant)->count());
        $this->assertSame(0, DB::table('shifts')->where('branch_id', $this->factory)->count());
    }
}
