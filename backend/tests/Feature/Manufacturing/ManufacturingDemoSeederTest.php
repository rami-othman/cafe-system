<?php

namespace Tests\Feature\Manufacturing;

use Database\Seeders\ManufacturingDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ManufacturingDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_demo_has_one_factory_warehouse_and_repeated_seed_preserves_stock_and_recipe_versions(): void
    {
        $this->seed();
        $this->seed(ManufacturingDemoSeeder::class);
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branch = DB::table('branches')->where('tenant_id', $tenant)->where('name', 'المعمل التجريبي')->first();
        $this->assertSame('factory', $branch->branch_type);
        $this->assertSame(1, DB::table('warehouses')->where('branch_id', $branch->id)->count());
        $items = DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'like', 'MFGDEMO-%')->pluck('id');
        $this->assertCount(17, $items);
        $this->assertSame(17, DB::table('inventory_item_warehouses')->where('warehouse_id', $branch->pos_inventory_warehouse_id)->whereIn('inventory_item_id', $items)->count());
        $this->assertSame(4, DB::table('manufacturing_recipes')->where('tenant_id', $tenant)->whereIn('product_item_id', $items)->count());
        $before = DB::table('stock_balances')->where('warehouse_id', $branch->pos_inventory_warehouse_id)->orderBy('inventory_item_id')->get()->toJson();
        $versions = DB::table('manufacturing_recipe_versions')->count();
        $movementCount = DB::table('stock_movements')->where('tenant_id', $tenant)->where('idempotency_key', 'like', 'mfgdemo-opening-%')->count();
        $this->assertSame(12, $movementCount);
        $this->seed(ManufacturingDemoSeeder::class);
        $this->assertSame($before, DB::table('stock_balances')->where('warehouse_id', $branch->pos_inventory_warehouse_id)->orderBy('inventory_item_id')->get()->toJson());
        $this->assertSame($versions, DB::table('manufacturing_recipe_versions')->count());
        $this->assertSame($movementCount, DB::table('stock_movements')->where('tenant_id', $tenant)->where('idempotency_key', 'like', 'mfgdemo-opening-%')->count());
        $chocolate = DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'MFGDEMO-CHOCOLATE')->value('id');
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $branch->pos_inventory_warehouse_id, 'inventory_item_id' => $chocolate, 'quantity_on_hand' => '5000.000']);
    }
}
