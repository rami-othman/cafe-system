<?php

namespace Tests\Feature;

use Database\Seeders\FinancialInventoryFoundationSeeder;
use Database\Seeders\InventoryCenterSeeder;
use Database\Seeders\InventorySeeder;
use Database\Seeders\SuperAdminSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use App\Domain\Inventory\InventoryReconciliationService;
use Tests\TestCase;

class InventoryCenterApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_inventory_catalog_seeders_are_idempotent_and_keep_one_record_per_identity(): void
    {
        $this->seed(SuperAdminSeeder::class);
        $this->seed(TenantAccessSeeder::class);
        $this->seed(FinancialInventoryFoundationSeeder::class);
        $this->seed(InventorySeeder::class);
        $this->seed(InventoryCenterSeeder::class);
        $tenant = $this->tenant('cafe-618');
        $firstCount = DB::table('inventory_items')->where('tenant_id', $tenant)->count();

        $this->seed(InventorySeeder::class);
        $this->seed(InventoryCenterSeeder::class);

        $this->assertSame($firstCount, DB::table('inventory_items')->where('tenant_id', $tenant)->count());
        $this->assertSame(
            $firstCount,
            DB::table('inventory_items')
                ->where('tenant_id', $tenant)
                ->distinct()
                ->count('catalog_identity'),
        );
        $this->assertSame(0, DB::table('inventory_items')->where('tenant_id', $tenant)->whereIn('sku', ['INV-COFFEE-BEANS', 'INV-MILK', 'INV-CUPS', 'INV-CROISSANTS'])->where('is_active', true)->count());
    }

    public function test_item_without_sku_cannot_duplicate_the_same_name_unit_and_type_within_a_tenant(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $payload = ['nameAr' => 'House blend', 'nameEn' => 'House blend', 'itemType' => 'raw_material', 'unit' => 'kg', 'minimumStock' => '1.000', 'reorderLevel' => '1.000', 'latestUnitCost' => '1.0000', 'isActive' => true];

        $this->postJson('/api/v1/inventory/items', $payload, $this->headers($tenant))->assertCreated();
        $this->postJson('/api/v1/inventory/items', $payload, $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('nameAr');
    }

    public function test_inventory_items_accept_only_catalog_units(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $this->getJson('/api/v1/inventory/units', $this->headers($tenant))
            ->assertOk()
            ->assertJsonCount(11, 'data')
            ->assertJsonFragment(['code' => 'kilogram', 'label' => 'Kilogram']);
        $payload = ['nameAr' => 'Controlled unit item', 'nameEn' => 'Controlled unit item', 'sku' => 'UNIT-CONTROL', 'itemType' => 'supply', 'unit' => 'made_up_unit', 'minimumStock' => '1.000', 'reorderLevel' => '1.000', 'latestUnitCost' => '1.0000', 'isActive' => true];

        $this->postJson('/api/v1/inventory/items', $payload, $this->headers($tenant))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('unit');
        $payload['unit'] = 'kilogram';
        $this->postJson('/api/v1/inventory/items', $payload, $this->headers($tenant))
            ->assertCreated()
            ->assertJsonPath('data.unit', 'kilogram');
    }

    public function test_item_specific_unit_conversions_are_controlled_and_tenant_scoped(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $otherTenant = $this->otherTenant();
        $item = $this->createItem($tenant);
        $headers = $this->headers($tenant);

        $created = $this->postJson('/api/v1/inventory/items/'.$item.'/unit-conversions', [
            'sourceUnit' => 'box',
            'targetUnit' => 'kilogram',
            'factor' => '1.000000',
            'isActive' => true,
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.sourceLabel', 'Box')
            ->assertJsonPath('data.targetLabel', 'Kilogram');
        $conversion = (int) $created->json('data.id');

        $this->getJson('/api/v1/inventory/items/'.$item.'/unit-conversions', $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data');
        $this->postJson('/api/v1/inventory/items/'.$item.'/unit-conversions', [
            'sourceUnit' => 'box',
            'targetUnit' => 'kilogram',
            'factor' => '1',
            'isActive' => true,
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('targetUnit');
        $this->postJson('/api/v1/inventory/items/'.$item.'/unit-conversions', [
            'sourceUnit' => 'made-up-unit',
            'targetUnit' => 'kilogram',
            'factor' => '1',
            'isActive' => true,
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('sourceUnit');
        $this->patchJson('/api/v1/inventory/items/'.$item.'/unit-conversions/'.$conversion, [
            'sourceUnit' => 'carton',
            'targetUnit' => 'piece',
            'factor' => '1000',
            'isActive' => false,
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.factor', '1000.000000')
            ->assertJsonPath('data.isActive', false);
        $this->getJson('/api/v1/inventory/items/'.$item.'/unit-conversions', $this->headers($otherTenant))
            ->assertNotFound();

        $this->patchJson('/api/v1/inventory/items/'.$item, [
            'nameAr' => 'مادة اختبار',
            'nameEn' => 'Test material',
            'sku' => 'TEST-ITEM',
            'itemType' => 'raw_material',
            'unit' => 'piece',
            'minimumStock' => '20.000',
            'reorderLevel' => '20.000',
            'latestUnitCost' => '1.0000',
            'isActive' => true,
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('unit');
    }

    public function test_inventory_items_list_uses_server_filters_pagination_and_zero_opening_stock(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $headers = $this->headers($tenant);
        foreach (['Pageable Arabica', 'Pageable Cups', 'Pageable Lids'] as $index => $name) {
            $response = $this->postJson('/api/v1/inventory/items', [
                'nameAr' => $name,
                'nameEn' => $name,
                'sku' => 'PAGE-'.$index,
                'itemType' => $index === 0 ? 'raw_material' : 'packaging',
                'category' => $index === 0 ? 'Coffee' : 'Cups',
                'unit' => 'piece',
                'minimumStock' => '2.000',
                'reorderLevel' => '3.000',
                'latestUnitCost' => '1.2500',
                'isActive' => true,
            ], $headers)->assertCreated();
            $itemId = (int) $response->json('data.id');
            $this->assertDatabaseMissing('stock_balances', ['tenant_id' => $tenant, 'inventory_item_id' => $itemId]);
            $this->assertDatabaseMissing('stock_movements', ['tenant_id' => $tenant, 'inventory_item_id' => $itemId]);
        }

        $page = $this->getJson('/api/v1/inventory/items?search=Pageable&stockStatus=out&perPage=1&page=2', $headers);
        $page->assertOk()
            ->assertJsonPath('data.meta.currentPage', 2)
            ->assertJsonPath('data.meta.perPage', 1)
            ->assertJsonPath('data.meta.total', 3)
            ->assertJsonPath('data.items.0.availableQuantity', '0.000')
            ->assertJsonPath('data.items.0.totalQuantity', '0.000')
            ->assertJsonFragment(['Cups']);

        $this->getJson('/api/v1/inventory/items?search=Pageable&type=packaging&category=Cups&status=active', $headers)
            ->assertOk()
            ->assertJsonPath('data.meta.total', 2);
    }

    public function test_inventory_is_strictly_tenant_scoped_and_rejects_foreign_warehouse(): void
    {
        $this->seed();
        $a = $this->tenant('cafe-618');
        $b = $this->otherTenant();
        $item = $this->createItem($a);
        $foreign = (int) DB::table('warehouses')->where('tenant_id', $b)->value('id');
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $foreign), $this->headers($a))->assertUnprocessable();
        $this->getJson('/api/v1/inventory/items/'.$item, $this->headers($b))->assertNotFound();
        $this->getJson('/api/v1/inventory/balances', $this->headers($b))->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_stock_in_weighted_average_and_stock_out_are_atomic_and_negative_stock_is_rejected(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $item = $this->createItem($tenant);
        $warehouse = $this->warehouse($tenant);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '10.000', '2.0000'), $this->headers($tenant))->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '10.000', '4.0000'), $this->headers($tenant))->assertCreated();
        $out = $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_out', '5.000'), $this->headers($tenant))->assertCreated()->json('data');
        $this->assertSame('3.0000', $out['unitCost']);
        $this->assertSame('15.000', $out['quantityAfter']);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_out', '16.000'), $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('quantity');
        $this->getJson('/api/v1/inventory/items/'.$item, $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.totalQuantity', '15.000')
            ->assertJsonPath('data.totalValue', '45.00')
            ->assertJsonCount(1, 'data.stockByWarehouse')
            ->assertJsonCount(3, 'data.recentMovements')
            ->assertJsonPath('data.recentMovements.0.type', 'stock_out');
    }

    public function test_waste_requires_reason_and_posted_ledger_has_no_mutation_routes(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $item = $this->createItem($tenant);
        $warehouse = $this->warehouse($tenant);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '2.000', '1.0000'), $this->headers($tenant))->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'waste', '1.000', null, null), $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('reason');
        $movement = $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'waste', '1.000', null, 'تلف'), $this->headers($tenant))->assertCreated();
        $this->patchJson('/api/v1/inventory/movements/'.$movement->json('data.id'), [], $this->headers($tenant))->assertMethodNotAllowed();
        $this->deleteJson('/api/v1/inventory/movements/'.$movement->json('data.id'), [], $this->headers($tenant))->assertMethodNotAllowed();
    }

    public function test_stock_count_requires_approval_posts_variance_once_and_dashboard_reports_alerts(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $item = $this->createItem($tenant);
        $warehouse = $this->isolatedWarehouse($tenant);
        $headers = $this->headers($tenant);
        $this->assignItemToWarehouse($tenant, $item, $warehouse);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '10.000', '2.0000'), $headers)->assertCreated();
        $count = $this->postJson('/api/v1/inventory/counts', ['warehouseId' => $warehouse, 'countDate' => '2026-08-17'], $headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/inventory/counts/'.$count.'/start', [], $headers)->assertOk();
        $this->putJson('/api/v1/inventory/counts/'.$count.'/lines', ['itemId' => $item, 'countedQuantity' => '8.000', 'reason' => 'فرق فعلي'], $headers)->assertOk();
        $this->postJson('/api/v1/inventory/counts/'.$count.'/submit', [], $headers)->assertOk();
        $this->postJson('/api/v1/inventory/counts/'.$count.'/post', [], $headers)->assertUnprocessable();
        $this->postJson('/api/v1/inventory/counts/'.$count.'/approve', [], $headers)->assertOk()->assertJsonPath('data.approvedBy', (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id'));
        $this->postJson('/api/v1/inventory/counts/'.$count.'/post', [], $headers)->assertOk()->assertJsonPath('data.status', 'posted');
        $this->postJson('/api/v1/inventory/counts/'.$count.'/post', [], $headers)->assertUnprocessable();
        $this->assertDatabaseHas('stock_movements', ['tenant_id' => $tenant, 'reference_type' => 'stock_count', 'reference_id' => $count, 'type' => 'stock_count_variance']);
        $this->getJson('/api/v1/inventory/dashboard', $headers)->assertOk()->assertJsonPath('data.lowStockItemCount', 5)->assertJsonPath('data.outOfStockItemCount', 1);
    }

    public function test_stock_count_list_returns_filtered_pages_summary_and_creator_options(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $warehouse = $this->warehouse($tenant);
        $headers = $this->headers($tenant);
        $first = (int) $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $warehouse,
            'countDate' => '2026-08-10',
            'countType' => 'full',
        ], $headers)->assertCreated()->json('data.id');
        $shift = (int) $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $warehouse,
            'countDate' => '2026-08-11',
            'countType' => 'cycle',
            'categoryFilters' => [(string) DB::table('inventory_items')->where('tenant_id', $tenant)->whereNotNull('category')->value('category')],
        ], $headers)->assertCreated()->json('data.id');
        DB::table('stock_counts')->where('id', $shift)->update(['count_type' => 'shift_check']);
        DB::table('stock_counts')->where('id', $first)->update(['category_filters' => json_encode(['category' => 'beverages'])]);

        $administrative = $this->getJson('/api/v1/inventory/counts?source=administrative&warehouseId='.$warehouse.'&from=2026-08-10&to=2026-08-10&perPage=1', $headers);
        $administrative
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('meta.lastPage', 1)
            ->assertJsonPath('meta.summary.drafts', 1)
            ->assertJsonPath('data.0.id', $first)
            ->assertJsonCount(1, 'meta.filterOptions.createdBy');

        $this->getJson('/api/v1/inventory/counts?source=shift_pos&countType=shift_check&perPage=1', $headers)
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.id', $shift)
            ->assertJsonPath('data.0.countType', 'shift_check');
    }

    public function test_stock_count_lines_keep_the_creation_snapshot_and_enforce_workspace_lifecycle(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $warehouse = $this->isolatedWarehouse($tenant);
        $headers = $this->headers($tenant);
        $item = $this->createItem($tenant);
        $this->assignItemToWarehouse($tenant, $item, $warehouse);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '10.000', '2.0000'), $headers)->assertCreated();
        $count = (int) $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $warehouse,
            'countDate' => '2026-08-24',
            'countType' => 'full',
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/inventory/counts/'.$count.'/start', [], $headers)->assertOk();

        // Inventory may move after the count starts, but its expected quantity
        // and unit cost must remain the creation snapshot.
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '4.000', '3.0000'), $headers)->assertCreated();
        $this->putJson('/api/v1/inventory/counts/'.$count.'/lines', [
            'itemId' => $item,
            'countedQuantity' => '8.000',
            'reason' => 'Physical count discrepancy',
        ], $headers)->assertOk();
        $this->assertDatabaseHas('stock_count_lines', [
            'stock_count_id' => $count,
            'inventory_item_id' => $item,
            'expected_quantity' => '10.000',
            'average_unit_cost' => '2.0000',
            'counted_quantity' => '8.000',
            'variance_quantity' => '-2.000',
        ]);
        $this->putJson('/api/v1/inventory/counts/'.$count.'/lines', [
            'itemId' => $item,
            'countedQuantity' => '-1.000',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('countedQuantity');

        foreach (DB::table('stock_count_lines')->where('stock_count_id', $count)->get() as $line) {
            if ((int) $line->inventory_item_id === $item) {
                continue;
            }
            $this->putJson('/api/v1/inventory/counts/'.$count.'/lines', [
                'itemId' => $line->inventory_item_id,
                'countedQuantity' => $line->expected_quantity,
            ], $headers)->assertOk();
        }
        $this->postJson('/api/v1/inventory/counts/'.$count.'/submit', [], $headers)
            ->assertOk()
            ->assertJsonPath('data.status', 'submitted');
        $this->putJson('/api/v1/inventory/counts/'.$count.'/lines', [
            'itemId' => $item,
            'countedQuantity' => '9.000',
            'reason' => 'Late edit',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('status');

        $branchWarehouse = (int) DB::table('warehouses')
            ->where('tenant_id', $tenant)
            ->whereNotNull('branch_id')
            ->value('id');
        $branchCount = (int) $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $branchWarehouse,
            'countDate' => '2026-08-25',
            'countType' => 'full',
        ], $headers)->assertCreated()->json('data.id');
        $branchLine = DB::table('stock_count_lines')
            ->where('stock_count_id', $branchCount)
            ->first();
        $manager = (int) DB::table('users')->insertGetId([
            'tenant_id' => $tenant,
            'name' => 'Workspace manager',
            'email' => 'workspace-manager@cafe618.local',
            'password' => 'not-used-in-feature-test',
            'role' => 'manager',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->putJson('/api/v1/inventory/counts/'.$branchCount.'/lines', [
            'itemId' => $branchLine->inventory_item_id,
            'countedQuantity' => '0.000',
        ], $this->headersForUser($tenant, $manager))->assertForbidden();
    }

    public function test_stock_count_creation_validates_scope_access_duplicates_and_generates_eligible_lines(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $warehouse = $this->warehouse($tenant);
        $headers = $this->headers($tenant);
        $eligible = DB::table('inventory_items as items')
            ->where('items.tenant_id', $tenant)
            ->where('items.is_active', true)
            ->whereNull('items.deleted_at')
            ->whereNotIn('items.item_type', ['non_stock_item', 'service'])
            ->whereExists(fn ($query) => $query->selectRaw('1')
                ->from('inventory_item_warehouses as availability')
                ->whereColumn('availability.inventory_item_id', 'items.id')
                ->where('availability.tenant_id', $tenant)
                ->where('availability.warehouse_id', $warehouse))
            ->count();

        $full = $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $warehouse,
            'countDate' => '2026-08-21',
            'countType' => 'full',
            'notes' => 'Full count creation test',
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.countType', 'full')
            ->assertJsonPath('data.status', 'draft')
            ->json('data.id');
        $this->assertSame($eligible, DB::table('stock_count_lines')->where('stock_count_id', $full)->count());

        $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $warehouse,
            'countDate' => '2026-08-21',
            'countType' => 'full',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('warehouseId');
        $this->postJson('/api/v1/inventory/counts', [
            'countDate' => '2026-08-21',
            'countType' => 'full',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('warehouseId');

        $category = DB::table('inventory_items as items')
            ->where('items.tenant_id', $tenant)
            ->where('items.is_active', true)
            ->whereExists(fn ($query) => $query->selectRaw('1')
                ->from('inventory_item_warehouses as availability')
                ->whereColumn('availability.inventory_item_id', 'items.id')
                ->where('availability.tenant_id', $tenant)
                ->where('availability.warehouse_id', $warehouse))
            ->value('items.category');
        $expectedCycleLines = DB::table('inventory_items as items')
            ->where('items.tenant_id', $tenant)
            ->where('items.is_active', true)
            ->whereNull('items.deleted_at')
            ->whereNotIn('items.item_type', ['non_stock_item', 'service'])
            ->where('items.category', $category)
            ->whereExists(fn ($query) => $query->selectRaw('1')
                ->from('inventory_item_warehouses as availability')
                ->whereColumn('availability.inventory_item_id', 'items.id')
                ->where('availability.tenant_id', $tenant)
                ->where('availability.warehouse_id', $warehouse))
            ->count();
        $cycle = $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $warehouse,
            'countDate' => '2026-08-22',
            'countType' => 'cycle',
            'categoryFilters' => [$category],
        ], $headers)->assertCreated()->assertJsonPath('data.countType', 'cycle')->json('data.id');
        $this->assertSame($expectedCycleLines, DB::table('stock_count_lines')->where('stock_count_id', $cycle)->count());

        $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $warehouse,
            'countDate' => '2026-08-23',
            'countType' => 'full',
        ], $this->headers($this->otherTenant()))->assertNotFound();

        $branchWarehouse = DB::table('warehouses')
            ->where('tenant_id', $tenant)
            ->whereNotNull('branch_id')
            ->value('id');
        $manager = (int) DB::table('users')->insertGetId([
            'tenant_id' => $tenant,
            'name' => 'Unassigned manager',
            'email' => 'unassigned-manager@cafe618.local',
            'password' => 'not-used-in-feature-test',
            'role' => 'manager',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->getJson('/api/v1/warehouses?status=active&forStockCount=true', $this->headersForUser($tenant, $manager))
            ->assertOk()
            ->assertJsonMissing(['id' => $branchWarehouse]);
        $this->postJson('/api/v1/inventory/counts', [
            'warehouseId' => $branchWarehouse,
            'countDate' => '2026-08-23',
            'countType' => 'full',
        ], $this->headersForUser($tenant, $manager))->assertForbidden();
    }

    public function test_dashboard_filters_and_orders_alerts_and_movements_from_real_inventory_data(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $warehouse = $this->warehouse($tenant);
        $item = $this->createItem($tenant);
        $headers = $this->headers($tenant);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '10.000', '2.0000'), $headers)->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'waste', '2.000', null, 'Damaged stock'), $headers)->assertCreated();

        $response = $this->getJson('/api/v1/inventory/dashboard?warehouse_id='.$warehouse.'&from='.now()->toDateString().'&to='.now()->toDateString().'&search=Test&movement_type=waste&trend_days=7&compare_previous=true', $headers);

        $response->assertOk()
            ->assertJsonStructure(['data' => ['recentMovements' => [['type', 'itemNameEn', 'warehouseName', 'quantityIn', 'quantityOut', 'reference', 'userName', 'occurredAt', 'createdAt']]]])
            ->assertJsonPath('data.kpis.totalInventoryValue.value', '16.00')
            ->assertJsonPath('data.kpis.totalItems.value', '1')
            ->assertJsonPath('data.kpis.wasteValue.value', '4.00')
            ->assertJsonPath('data.kpis.todayConsumptionCost.value', '0.00')
            ->assertJsonPath('data.kpis.todayWasteCost.value', '4.00')
            ->assertJsonPath('data.wasteSummary.todayCost', '4.00')
            ->assertJsonPath('data.wasteSummary.weekCost', '4.00')
            ->assertJsonPath('data.wasteSummary.movementCount', 1)
            ->assertJsonPath('data.wasteSummary.topItems.0.itemName', 'Test material')
            ->assertJsonPath('data.consumptionSummary.totalCost', '0.00')
            ->assertJsonPath('data.recentMovements.0.type', 'waste')
            ->assertJsonPath('data.recentMovements.0.dashboardType', 'waste')
            ->assertJsonPath('data.lowStockAlerts.0.minimumLevel', '20.000')
            ->assertJsonPath('data.lowStockAlerts.0.missingQuantity', '12.000')
            ->assertJsonPath('data.lowStockAlerts.0.suggestedReorderQuantity', '12.000')
            ->assertJsonPath('data.lowStockAlerts.0.severity', 'critical')
            ->assertJsonPath('data.inventoryAlertsSummary.critical', 1)
            ->assertJsonPath('data.inventoryAlertsSummary.low', 0)
            ->assertJsonPath('data.inventoryAlertsSummary.total', 1)
            ->assertJsonPath('data.recentMovements.0.itemNameEn', 'Test material');
        $this->assertCount(1, $response->json('data.stockValueByWarehouse'));
        $this->assertSame(1, $response->json('data.stockValueByWarehouse.0.itemCount'));
        $this->assertSame(1, $response->json('data.stockValueByWarehouse.0.alertsCount'));
        $this->assertSame('critical', $response->json('data.stockValueByWarehouse.0.status'));
        $this->assertSame(0, $response->json('data.stockValueByWarehouse.0.healthPercentage'));
        $this->assertNotEmpty($response->json('data.stockValueByWarehouse.0.lastMovementAt'));
        $this->assertNotEmpty($response->json('data.stockValueTrend.points'));
        $this->assertCount(7, $response->json('data.stockValueTrend.points'));
        $this->assertCount(7, $response->json('data.stock_value_trend'));
        $this->assertSame(
            $response->json('data.lowStockAlerts'),
            collect($response->json('data.lowStockAlerts'))->sortBy(fn (array $alert) => $alert['outOfStock'] ? 0 : 1)->values()->all(),
        );
    }

    public function test_item_management_validates_units_and_filters_assigned_warehouses(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $warehouse = $this->warehouse($tenant);
        $headers = $this->headers($tenant);
        $payload = [
            'nameAr' => 'Managed milk',
            'nameEn' => 'Managed milk',
            'sku' => 'MANAGED-MILK',
            'barcode' => '990001',
            'itemType' => 'stock_item',
            'category' => 'Dairy',
            'unit' => 'liter',
            'purchaseUnit' => 'box',
            'consumptionUnit' => 'liter',
            'minimumStock' => '5.000',
            'reorderLevel' => '10.000',
            'latestUnitCost' => '2.0000',
            'lastPurchaseCost' => '2.2500',
            'trackExpiry' => true,
            'trackBatch' => true,
            'warehouseIds' => [$warehouse],
            'isActive' => true,
        ];
        $this->postJson('/api/v1/inventory/items', $payload, $headers)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('purchaseConversionFactor');

        $created = $this->postJson('/api/v1/inventory/items', $payload + [
            'purchaseConversionFactor' => '12',
        ], $headers)->assertCreated()
            ->assertJsonPath('data.purchaseUnit', 'box')
            ->assertJsonPath('data.lastPurchaseCost', '2.2500')
            ->assertJsonPath('data.trackExpiry', true)
            ->json('data');

        $this->getJson('/api/v1/inventory/items?search=990001&warehouseId='.$warehouse, $headers)
            ->assertOk()
            ->assertJsonPath('data.meta.total', 1)
            ->assertJsonPath('data.items.0.id', $created['id']);
    }

    public function test_stock_in_and_out_keep_the_current_balance_contract(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $item = $this->createItem($tenant);
        $warehouse = $this->warehouse($tenant);
        $headers = $this->headers($tenant);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '10.000', '2.0000'), $headers)->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_out', '3.000'), $headers)->assertCreated();
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '7.000']);
    }

    public function test_inventory_numeric_api_contracts_use_fixed_precision_strings(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $warehouse = $this->warehouse($tenant);
        $headers = $this->headers($tenant);
        $item = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'Numeric contract material',
            'nameEn' => 'Numeric contract material',
            'sku' => 'NUMERIC-CONTRACT',
            'itemType' => 'raw_material',
            'unit' => 'kilogram',
            'purchaseUnit' => 'box',
            'purchaseConversionFactor' => '12.000000',
            'minimumStock' => '1.000',
            'reorderLevel' => '2.000',
            'latestUnitCost' => '2.0000',
            'lastPurchaseCost' => '2.2500',
            'warehouseIds' => [$warehouse],
            'isActive' => true,
        ], $headers)->assertCreated()
            ->assertJsonPath('data.latestUnitCost', '2.0000')
            ->assertJsonPath('data.lastPurchaseCost', '2.2500')
            ->json('data.id');
        $itemData = $this->getJson('/api/v1/inventory/items/'.$item, $headers)->assertOk()->json('data');
        $this->assertIsString($itemData['minimumStock']);
        $this->assertIsString($itemData['latestUnitCost']);
        $this->assertIsString($itemData['lastPurchaseCost']);

        $movement = $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '2.000', '2.0000') + ['unit' => 'box'], $headers)
            ->assertCreated()
            ->assertJsonPath('data.conversionFactor', '12.000000')
            ->assertJsonPath('data.baseQuantity', '24.000')
            ->json('data');
        $this->assertIsString($movement['conversionFactor']);
        $this->assertIsString($movement['baseQuantity']);
    }

    public function test_movement_retry_with_the_same_idempotency_key_replays_the_original_result(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $item = $this->createItem($tenant);
        $warehouse = $this->warehouse($tenant);
        $payload = $this->movement($item, $warehouse, 'stock_in', '5.000', '2.0000') + ['idempotencyKey' => 'movement-retry-001'];
        $first = $this->postJson('/api/v1/inventory/movements', $payload, $this->headers($tenant))->assertCreated()->json('data');
        $second = $this->postJson('/api/v1/inventory/movements', $payload, $this->headers($tenant))->assertOk()->json('data');
        $this->assertSame($first['id'], $second['id']);
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('idempotency_key', 'movement-retry-001')->count());
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '5.000']);
    }

    public function test_movement_converts_an_active_box_conversion_to_the_item_base_unit(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $item = $this->createItem($tenant);
        $warehouse = $this->warehouse($tenant);
        $headers = $this->headers($tenant);
        $this->postJson('/api/v1/inventory/items/'.$item.'/unit-conversions', ['sourceUnit' => 'box', 'targetUnit' => 'kilogram', 'factor' => '12.000000', 'isActive' => true], $headers)->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '2.000', '2.0000') + ['unit' => 'box'], $headers)
            ->assertCreated()
            ->assertJsonPath('data.inputUnit', 'box')
            ->assertJsonPath('data.conversionFactor', '12.000000')
            ->assertJsonPath('data.baseQuantity', '24.000');
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '24.000']);
    }

    public function test_movement_rejects_a_non_base_unit_without_an_active_conversion(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $item = $this->createItem($tenant);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $this->warehouse($tenant), 'stock_in', '1.000', '2.0000') + ['unit' => 'carton'], $this->headers($tenant))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('unit');
    }

    public function test_outbound_converted_quantity_cannot_make_the_balance_negative(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $item = $this->createItem($tenant);
        $warehouse = $this->warehouse($tenant);
        $headers = $this->headers($tenant);
        $this->postJson('/api/v1/inventory/items/'.$item.'/unit-conversions', ['sourceUnit' => 'box', 'targetUnit' => 'kilogram', 'factor' => '12.000000', 'isActive' => true], $headers)->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '1.000', '2.0000') + ['unit' => 'box'], $headers)->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_out', '2.000') + ['unit' => 'box'], $headers)->assertUnprocessable()->assertJsonValidationErrors('quantity');
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '12.000']);
    }

    public function test_reconciliation_dry_run_compares_multiple_scopes_without_writing(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $warehouse = $this->isolatedWarehouse($tenant);
        $first = $this->createItem($tenant);
        $second = (int) $this->postJson('/api/v1/inventory/items', ['nameAr' => 'Second material', 'nameEn' => 'Second material', 'sku' => 'SECOND-ITEM', 'itemType' => 'raw_material', 'unit' => 'kilogram', 'minimumStock' => '1.000', 'reorderLevel' => '1.000', 'latestUnitCost' => '1.0000', 'isActive' => true], $this->headers($tenant))->assertCreated()->json('data.id');
        $this->postJson('/api/v1/inventory/movements', $this->movement($first, $warehouse, 'stock_in', '4.000'), $this->headers($tenant))->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($second, $warehouse, 'stock_in', '6.000'), $this->headers($tenant))->assertCreated();
        DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouse)->where('inventory_item_id', $second)->update(['quantity_on_hand' => '5.000']);
        $report = app(InventoryReconciliationService::class)->dryRun($tenant, $warehouse);
        $this->assertSame(2, $report['checked']);
        $this->assertCount(1, $report['differences']);
        $this->assertSame($second, $report['differences'][0]['itemId']);
        $this->assertSame('-1.000', $report['differences'][0]['difference']);
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $second, 'quantity_on_hand' => '5.000']);
    }

    public function test_count_requires_every_required_line_and_records_base_unit_snapshots(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $headers = $this->headers($tenant);
        $warehouse = $this->isolatedWarehouse($tenant);
        $first = $this->createItem($tenant);
        $second = (int) $this->postJson('/api/v1/inventory/items', ['nameAr' => 'Second count item', 'nameEn' => 'Second count item', 'sku' => 'COUNT-SECOND', 'itemType' => 'raw_material', 'unit' => 'kilogram', 'minimumStock' => '0.000', 'reorderLevel' => '0.000', 'latestUnitCost' => '1.0000', 'isActive' => true], $headers)->assertCreated()->json('data.id');
        foreach ([$first, $second] as $item) $this->assignItemToWarehouse($tenant, $item, $warehouse);
        $this->postJson('/api/v1/inventory/movements', $this->movement($first, $warehouse, 'stock_in', '10.000'), $headers)->assertCreated();
        $count = (int) $this->postJson('/api/v1/inventory/counts', ['warehouseId' => $warehouse, 'countDate' => '2026-08-27'], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/inventory/counts/$count/start", [], $headers)->assertOk();
        $this->putJson("/api/v1/inventory/counts/$count/lines", ['itemId' => $first, 'countedQuantity' => '9.000', 'reason' => 'Physical variance'], $headers)->assertOk();
        $this->postJson("/api/v1/inventory/counts/$count/submit", [], $headers)->assertUnprocessable()->assertJsonValidationErrors('lines');
        $this->putJson("/api/v1/inventory/counts/$count/lines", ['itemId' => $second, 'countedQuantity' => '0.000'], $headers)->assertOk();
        $this->postJson("/api/v1/inventory/counts/$count/submit", [], $headers)->assertOk();
        $this->assertDatabaseHas('stock_count_lines', ['stock_count_id' => $count, 'inventory_item_id' => $second, 'is_counted' => true, 'entered_quantity' => '0.000', 'base_quantity' => '0.000']);
    }

    public function test_bar_check_starts_without_null_count_and_enforces_units_tolerance_and_review(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $headers = $this->headers($tenant);
        $warehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->whereNotNull('branch_id')->value('id');
        $branch = (int) DB::table('warehouses')->where('id', $warehouse)->value('branch_id');
        $item = $this->createItem($tenant);
        DB::table('inventory_item_warehouses')->insertOrIgnore(['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson("/api/v1/inventory/items/$item/unit-conversions", ['sourceUnit' => 'box', 'targetUnit' => 'kilogram', 'factor' => '12.000000', 'isActive' => true], $headers)->assertCreated();
        $template = $this->postJson('/api/v1/inventory/bar-check-templates', ['branchId' => $branch, 'warehouseId' => $warehouse, 'requiredForShiftClose' => true, 'lines' => [['itemId' => $item, 'countUnit' => 'box', 'required' => true, 'toleranceType' => 'percentage', 'tolerance' => '5.000', 'requiresReviewWhenExceeded' => true]]], $headers)->assertCreated()->assertJsonPath('data.lines.0.itemId', $item);
        $shift = (int) $this->postJson('/api/v1/shifts/current', ['branchId' => $branch, 'openingCash' => '0.00'], $headers)->assertCreated()->json('data.id');
        $check = (int) $this->postJson('/api/v1/inventory/bar-checks', ['shiftId' => $shift, 'warehouseId' => $warehouse], $headers)->assertCreated()->json('data.stockCountId');
        $this->assertDatabaseHas('stock_count_lines', ['stock_count_id' => $check, 'inventory_item_id' => $item, 'counted_quantity' => '0.000', 'is_counted' => false, 'entered_unit' => 'box']);
        $this->putJson("/api/v1/inventory/counts/$check/lines", ['itemId' => $item, 'countedQuantity' => '1.000', 'unit' => 'box', 'reason' => 'Bar variance'], $headers)->assertOk();
        $this->assertDatabaseHas('stock_count_lines', ['stock_count_id' => $check, 'inventory_item_id' => $item, 'base_quantity' => '12.000', 'variance_status' => 'needs_manager_review']);
        $this->postJson("/api/v1/inventory/counts/$check/submit", [], $headers)->assertOk();
        $this->postJson("/api/v1/inventory/counts/$check/approve", [], $headers)->assertUnprocessable()->assertJsonValidationErrors('managerReview');
        $manager = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Bar manager', 'email' => 'bar-manager@cafe618.local', 'password' => 'not-used-in-feature-test', 'role' => 'manager', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('user_branches')->insertOrIgnore(['tenant_id' => $tenant, 'user_id' => $manager, 'branch_id' => $branch, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson("/api/v1/inventory/counts/$check/lines/$item/review", ['decision' => 'approved', 'notes' => 'Checked by manager'], $this->headersForUser($tenant, $manager))->assertOk();
        $this->postJson("/api/v1/inventory/counts/$check/approve", [], $headers)->assertOk();
        $this->postJson("/api/v1/inventory/counts/$check/post", [], $headers)->assertOk();
        $this->postJson("/api/v1/shifts/$shift/close", ['closingCash' => '0.00'], $headers)->assertOk();
    }

    public function test_transfer_reserves_dispatches_receives_partially_and_closes_shortage_idempotently(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $headers = $this->headers($tenant);
        $warehouses = DB::table('warehouses')->where('tenant_id', $tenant)->where('is_active', true)->whereNull('deleted_at')->limit(2)->pluck('id')->values();
        $this->assertCount(2, $warehouses);
        [$source, $destination] = [(int) $warehouses[0], (int) $warehouses[1]];
        $item = $this->createItem($tenant);
        foreach ([$source, $destination] as $warehouse) DB::table('inventory_item_warehouses')->insertOrIgnore(['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $source, 'stock_in', '10.000'), $headers)->assertCreated();
        $transfer = (int) $this->postJson('/api/v1/inventory/transfers', ['sourceWarehouseId' => $source, 'destinationWarehouseId' => $destination, 'idempotencyKey' => 'transfer-create-1', 'lines' => [['itemId' => $item, 'requestedQuantity' => '8.000', 'unit' => 'kilogram']]], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/inventory/transfers/$transfer/submit", ['idempotencyKey' => 'transfer-submit-1'], $headers)->assertOk();
        $this->postJson("/api/v1/inventory/transfers/$transfer/approve", ['idempotencyKey' => 'transfer-approve-1'], $headers)->assertOk()->assertJsonPath('data.status', 'approved');
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $source, 'inventory_item_id' => $item, 'reserved_quantity' => '8.000']);
        $this->postJson("/api/v1/inventory/transfers/$transfer/dispatch", ['idempotencyKey' => 'transfer-dispatch-1'], $headers)->assertOk()->assertJsonPath('data.status', 'dispatched');
        $this->postJson("/api/v1/inventory/transfers/$transfer/dispatch", ['idempotencyKey' => 'transfer-dispatch-1'], $headers)->assertOk();
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $source, 'inventory_item_id' => $item, 'quantity_on_hand' => '2.000', 'reserved_quantity' => '0.000']);
        $lineId = (int) DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $transfer)->where('inventory_item_id', $item)->value('id');
        $this->assertDatabaseHas('warehouse_transfer_transit_balances', ['tenant_id' => $tenant, 'warehouse_transfer_line_id' => $lineId, 'quantity_in_transit' => '8.000']);
        $this->postJson("/api/v1/inventory/transfers/$transfer/receive", ['idempotencyKey' => 'transfer-receipt-1', 'lines' => [['itemId' => $item, 'receivedQuantity' => '6.000', 'unit' => 'kilogram', 'discrepancyReason' => 'Short delivery']]], $headers)->assertOk()->assertJsonPath('data.status', 'partially_received');
        $this->assertDatabaseHas('warehouse_transfer_transit_balances', ['tenant_id' => $tenant, 'warehouse_transfer_line_id' => $lineId, 'quantity_in_transit' => '2.000']);
        $this->postJson("/api/v1/inventory/transfers/$transfer/close-shortage", ['idempotencyKey' => 'transfer-shortage-1', 'discrepancyReason' => 'Supplier confirmed shortage'], $headers)->assertOk()->assertJsonPath('data.status', 'closed_shortage');
        $this->postJson("/api/v1/inventory/transfers/$transfer/close-shortage", ['idempotencyKey' => 'transfer-shortage-1', 'discrepancyReason' => 'Supplier confirmed shortage'], $headers)->assertOk();
        $this->assertSame(1, DB::table('stock_movements')->where('reference_type', 'warehouse_transfer')->where('reference_id', $transfer)->count());
        $this->assertDatabaseHas('warehouse_transfer_transit_balances', ['tenant_id' => $tenant, 'warehouse_transfer_line_id' => $lineId, 'quantity_in_transit' => '0.000']);
        $this->assertSame(3, DB::table('warehouse_transfer_transit_movements')->where('warehouse_transfer_id', $transfer)->count());
    }

    public function test_transfer_multiple_receipts_reconcile_source_destination_and_transit(): void
    {
        $this->seed(); $tenant = $this->tenant('cafe-618'); $headers = $this->headers($tenant);
        $warehouses = DB::table('warehouses')->where('tenant_id', $tenant)->where('is_active', true)->limit(2)->pluck('id')->values(); [$source, $destination] = [(int) $warehouses[0], (int) $warehouses[1]];
        $item = $this->createItem($tenant);
        foreach ([$source, $destination] as $warehouse) DB::table('inventory_item_warehouses')->insertOrIgnore(['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $source, 'stock_in', '100.000'), $headers)->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $destination, 'stock_in', '20.000'), $headers)->assertCreated();
        $transfer = (int) $this->postJson('/api/v1/inventory/transfers', ['sourceWarehouseId' => $source, 'destinationWarehouseId' => $destination, 'idempotencyKey' => 'multi-create', 'lines' => [['itemId' => $item, 'requestedQuantity' => '100.000', 'unit' => 'kilogram']]], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/inventory/transfers/$transfer/submit", ['idempotencyKey' => 'multi-submit'], $headers)->assertOk();
        $this->postJson("/api/v1/inventory/transfers/$transfer/approve", ['idempotencyKey' => 'multi-approve'], $headers)->assertOk();
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $source, 'inventory_item_id' => $item, 'quantity_on_hand' => '100.000', 'reserved_quantity' => '100.000']);
        $this->postJson("/api/v1/inventory/transfers/$transfer/dispatch", ['idempotencyKey' => 'multi-dispatch'], $headers)->assertOk();
        foreach ([['40.000', 'multi-r1'], ['30.000', 'multi-r2'], ['30.000', 'multi-r3']] as [$quantity, $key]) $this->postJson("/api/v1/inventory/transfers/$transfer/receive", ['idempotencyKey' => $key, 'lines' => [['itemId' => $item, 'receivedQuantity' => $quantity, 'unit' => 'kilogram', 'discrepancyReason' => $quantity === '30.000' ? 'Partial receipt' : 'Partial receipt']]], $headers)->assertOk();
        $line = (int) DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $transfer)->value('id');
        $this->assertDatabaseHas('warehouse_transfers', ['id' => $transfer, 'status' => 'received']);
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $source, 'inventory_item_id' => $item, 'quantity_on_hand' => '0.000', 'reserved_quantity' => '0.000']);
        $this->assertDatabaseHas('stock_balances', ['tenant_id' => $tenant, 'warehouse_id' => $destination, 'inventory_item_id' => $item, 'quantity_on_hand' => '120.000']);
        $this->assertDatabaseHas('warehouse_transfer_transit_balances', ['warehouse_transfer_line_id' => $line, 'quantity_in_transit' => '0.000']);
    }

    public function test_transfer_list_exposes_source_and_destination_location_contract(): void
    {
        $this->seed();
        $tenant = $this->tenant('cafe-618');
        $headers = $this->headers($tenant);

        $central = DB::table('warehouses')->where('tenant_id', $tenant)->where('type', 'central')->whereNull('branch_id')->first();
        $this->assertNotNull($central, 'Seeder must provide a branchless central warehouse.');

        $branchWarehouses = DB::table('warehouses')->where('tenant_id', $tenant)->whereNotNull('branch_id')->where('is_active', true)->orderBy('branch_id')->get();
        $this->assertGreaterThanOrEqual(2, $branchWarehouses->pluck('branch_id')->unique()->count(), 'Seeder must provide warehouses on at least two different branches.');
        $branchA = $branchWarehouses->first();
        $branchB = $branchWarehouses->first(fn ($w) => (int) $w->branch_id !== (int) $branchA->branch_id);
        $branchAName = (string) DB::table('branches')->where('id', $branchA->branch_id)->value('name');
        $branchBName = (string) DB::table('branches')->where('id', $branchB->branch_id)->value('name');

        $item = $this->createItem($tenant);
        foreach ([$central->id, $branchA->id, $branchB->id] as $warehouseId) {
            DB::table('inventory_item_warehouses')->insertOrIgnore(['tenant_id' => $tenant, 'warehouse_id' => $warehouseId, 'inventory_item_id' => $item, 'created_at' => now(), 'updated_at' => now()]);
        }
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $branchA->id, 'stock_in', '10.000'), $headers)->assertCreated();
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $central->id, 'stock_in', '10.000'), $headers)->assertCreated();

        $lines = [['itemId' => $item, 'requestedQuantity' => '1.000', 'unit' => 'kilogram']];
        $branchToBranch = (int) $this->postJson('/api/v1/inventory/transfers', ['sourceWarehouseId' => $branchA->id, 'destinationWarehouseId' => $branchB->id, 'idempotencyKey' => 'contract-branch-branch', 'lines' => $lines], $headers)->assertCreated()->json('data.id');
        $centralToBranch = (int) $this->postJson('/api/v1/inventory/transfers', ['sourceWarehouseId' => $central->id, 'destinationWarehouseId' => $branchB->id, 'idempotencyKey' => 'contract-central-branch', 'lines' => $lines], $headers)->assertCreated()->json('data.id');
        $branchToCentral = (int) $this->postJson('/api/v1/inventory/transfers', ['sourceWarehouseId' => $branchA->id, 'destinationWarehouseId' => $central->id, 'idempotencyKey' => 'contract-branch-central', 'lines' => $lines], $headers)->assertCreated()->json('data.id');

        $rows = collect($this->getJson('/api/v1/inventory/transfers?perPage=50', $headers)->assertOk()->json('data'))->keyBy('id');

        $bb = $rows[$branchToBranch];
        $this->assertSame((int) $branchA->id, $bb['sourceWarehouseId']);
        $this->assertSame((int) $branchA->branch_id, $bb['sourceBranchId']);
        $this->assertSame($branchAName, $bb['sourceBranchName']);
        $this->assertSame((int) $branchB->id, $bb['destinationWarehouseId']);
        $this->assertSame((int) $branchB->branch_id, $bb['destinationBranchId']);
        $this->assertSame($branchBName, $bb['destinationBranchName']);
        $this->assertStringContainsString($branchAName, $bb['sourceWarehouseName']);
        $this->assertStringContainsString($branchBName, $bb['destinationWarehouseName']);

        $cb = $rows[$centralToBranch];
        $this->assertNull($cb['sourceBranchId'], 'Central warehouse has no branch.');
        $this->assertNull($cb['sourceBranchName'], 'Central warehouse has no branch.');
        $this->assertSame('Central Warehouse', $cb['sourceWarehouseName']);
        $this->assertSame((int) $branchB->branch_id, $cb['destinationBranchId']);
        $this->assertSame($branchBName, $cb['destinationBranchName']);

        $bc = $rows[$branchToCentral];
        $this->assertSame((int) $branchA->branch_id, $bc['sourceBranchId']);
        $this->assertSame($branchAName, $bc['sourceBranchName']);
        $this->assertNull($bc['destinationBranchId'], 'Central warehouse has no branch.');
        $this->assertNull($bc['destinationBranchName'], 'Central warehouse has no branch.');
        $this->assertSame('Central Warehouse', $bc['destinationWarehouseName']);

        $this->getJson("/api/v1/inventory/transfers/$branchToBranch", $headers)->assertOk()
            ->assertJsonPath('data.sourceWarehouseId', (int) $branchA->id)
            ->assertJsonPath('data.sourceBranchId', (int) $branchA->branch_id)
            ->assertJsonPath('data.sourceBranchName', $branchAName)
            ->assertJsonPath('data.destinationWarehouseId', (int) $branchB->id)
            ->assertJsonPath('data.destinationBranchId', (int) $branchB->branch_id)
            ->assertJsonPath('data.destinationBranchName', $branchBName);

        $this->getJson("/api/v1/inventory/transfers/$centralToBranch", $headers)->assertOk()
            ->assertJsonPath('data.sourceBranchId', null)
            ->assertJsonPath('data.sourceBranchName', null)
            ->assertJsonPath('data.sourceWarehouseName', 'Central Warehouse');
    }

    private function createItem(int $tenant): int
    {
        return (int) $this->postJson('/api/v1/inventory/items', ['nameAr' => 'مادة اختبار', 'nameEn' => 'Test material', 'sku' => 'TEST-ITEM', 'itemType' => 'raw_material', 'unit' => 'kg', 'minimumStock' => '20.000', 'reorderLevel' => '20.000', 'latestUnitCost' => '1.0000', 'isActive' => true], $this->headers($tenant))->assertCreated()->json('data.id');
    }

    private function movement(int $item, int $warehouse, string $type = 'stock_in', string $quantity = '10.000', ?string $cost = '2.0000', ?string $reason = 'اختبار'): array
    {
        return array_filter(['warehouseId' => $warehouse, 'itemId' => $item, 'type' => $type, 'quantity' => $quantity, 'unitCost' => $cost, 'reason' => $reason], fn ($value) => $value !== null);
    }

    private function headers(int $tenant): array
    {
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        if (! $owner) {
            $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Test Owner', 'email' => "owner-$tenant@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }

        return $this->headersForUser($tenant, $owner);
    }

    private function headersForUser(int $tenant, int $user): array
    {
        $plainToken = "inventory-test-$tenant-$user";
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'inventory-feature-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenant];
    }

    private function tenant(string $slug): int
    {
        return (int) DB::table('tenants')->where('slug', $slug)->value('id');
    }

    private function warehouse(int $tenant): int
    {
        return (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');
    }

    private function isolatedWarehouse(int $tenant): int
    {
        return (int) DB::table('warehouses')->insertGetId([
            'tenant_id' => $tenant,
            'name' => 'Isolated inventory test warehouse',
            'code' => 'TEST-ISOLATED',
            'type' => 'central',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function assignItemToWarehouse(int $tenant, int $item, int $warehouse): void
    {
        DB::table('inventory_item_warehouses')->insertOrIgnore([
            'tenant_id' => $tenant,
            'warehouse_id' => $warehouse,
            'inventory_item_id' => $item,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function otherTenant(): int
    {
        $now = now();

        return (int) DB::table('tenants')->insertGetId(['name' => 'Other', 'slug' => 'other-inventory', 'status' => 'active', 'plan' => 'starter', 'currency' => 'SYP', 'timezone' => 'Asia/Damascus', 'created_at' => $now, 'updated_at' => $now]);
    }
}
