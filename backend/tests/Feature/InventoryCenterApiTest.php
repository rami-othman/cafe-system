<?php

namespace Tests\Feature;

use Database\Seeders\FinancialInventoryFoundationSeeder;
use Database\Seeders\InventoryCenterSeeder;
use Database\Seeders\InventorySeeder;
use Database\Seeders\SuperAdminSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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
        $warehouse = $this->warehouse($tenant);
        $headers = $this->headers($tenant);
        $this->postJson('/api/v1/inventory/movements', $this->movement($item, $warehouse, 'stock_in', '10.000', '2.0000'), $headers)->assertCreated();
        $count = $this->postJson('/api/v1/inventory/counts', ['warehouseId' => $warehouse, 'countDate' => '2026-08-17'], $headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/inventory/counts/'.$count.'/start', [], $headers)->assertOk();
        $this->putJson('/api/v1/inventory/counts/'.$count.'/lines', ['itemId' => $item, 'countedQuantity' => '8.000', 'reason' => 'فرق فعلي'], $headers)->assertOk();
        $this->postJson('/api/v1/inventory/counts/'.$count.'/submit', [], $headers)->assertOk();
        $this->postJson('/api/v1/inventory/counts/'.$count.'/post', [], $headers)->assertUnprocessable();
        $this->postJson('/api/v1/inventory/counts/'.$count.'/approve', [], $headers)->assertOk()->assertJsonPath('data.approvedBy', null);
        $this->postJson('/api/v1/inventory/counts/'.$count.'/post', [], $headers)->assertOk()->assertJsonPath('data.status', 'posted');
        $this->postJson('/api/v1/inventory/counts/'.$count.'/post', [], $headers)->assertUnprocessable();
        $this->assertDatabaseHas('stock_movements', ['tenant_id' => $tenant, 'reference_type' => 'stock_count', 'reference_id' => $count, 'type' => 'stock_count_variance']);
        $this->getJson('/api/v1/inventory/dashboard', $headers)->assertOk()->assertJsonPath('data.lowStockItemCount', 5)->assertJsonPath('data.outOfStockItemCount', 1);
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

        $response = $this->getJson('/api/v1/inventory/dashboard?warehouse_id='.$warehouse.'&from='.now()->toDateString().'&to='.now()->toDateString().'&search=Test&compare_previous=true', $headers);

        $response->assertOk()
            ->assertJsonPath('data.kpis.totalInventoryValue.value', '16.00')
            ->assertJsonPath('data.kpis.wasteValue.value', '4.00')
            ->assertJsonPath('data.recentMovements.0.type', 'waste')
            ->assertJsonPath('data.recentMovements.0.itemNameEn', 'Test material');
        $this->assertCount(1, $response->json('data.stockValueByWarehouse'));
        $this->assertSame(
            $response->json('data.lowStockAlerts'),
            collect($response->json('data.lowStockAlerts'))->sortBy(fn (array $alert) => $alert['outOfStock'] ? 0 : 1)->values()->all(),
        );
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
        return ['X-Tenant-Id' => $tenant];
    }

    private function tenant(string $slug): int
    {
        return (int) DB::table('tenants')->where('slug', $slug)->value('id');
    }

    private function warehouse(int $tenant): int
    {
        return (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');
    }

    private function otherTenant(): int
    {
        $now = now();

        return (int) DB::table('tenants')->insertGetId(['name' => 'Other', 'slug' => 'other-inventory', 'status' => 'active', 'plan' => 'starter', 'currency' => 'SYP', 'timezone' => 'Asia/Damascus', 'created_at' => $now, 'updated_at' => $now]);
    }
}
