<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class DefaultBarCheckTemplateTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private int $branch;

    private int $warehouse;

    private int $item;

    private array $headers;

    protected function setUp(): void
    {
        parent::setUp();
        $this->tenant = DB::table('tenants')->insertGetId(['name' => 'Bar', 'slug' => 'bar-default', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $this->branch = DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Main', 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($this->tenant, $this->branch);
        $owner = User::query()->create(['tenant_id' => $this->tenant, 'name' => 'Owner', 'email' => 'bar-default@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);
        $this->headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($this->tenant, $owner)];
        $this->warehouse = (int) DB::table('warehouses')->where('tenant_id', $this->tenant)->where('branch_id', $this->branch)->value('id');
        $this->item = DB::table('inventory_items')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Beans', 'name_en' => 'Beans', 'name_ar' => 'حبوب', 'sku' => 'D-BEANS', 'unit' => 'piece', 'item_type' => 'raw_material', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('inventory_item_warehouses')->insert(['tenant_id' => $this->tenant, 'inventory_item_id' => $this->item, 'warehouse_id' => $this->warehouse, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('stock_balances')->insert(['tenant_id' => $this->tenant, 'warehouse_id' => $this->warehouse, 'inventory_item_id' => $this->item, 'quantity_on_hand' => '8.000', 'average_unit_cost' => '1.0000', 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson('/api/v1/shifts/current', ['branchId' => $this->branch, 'openingCash' => '0.00'], $this->headers)->assertCreated();
    }

    private function consumeBySale(): void
    {
        DB::table('stock_movements')->insert(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'warehouse_id' => $this->warehouse, 'inventory_item_id' => $this->item, 'type' => 'sale_consumption', 'quantity' => '2.000', 'quantity_in' => '0.000', 'quantity_out' => '2.000', 'quantity_before' => '10.000', 'quantity_after' => '8.000', 'occurred_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
    }

    public function test_shift_close_requires_counting_the_materials_sales_consumed_without_a_configured_template(): void
    {
        $this->consumeBySale();

        $lines = $this->getJson('/api/v1/shifts/current/snapshot', $this->headers)->assertOk()->json('data.barCount.lines');

        $this->assertCount(1, $lines);
        $this->assertSame((string) $this->item, $lines[0]['id']);
        $this->assertDatabaseHas('bar_check_templates', ['tenant_id' => $this->tenant, 'warehouse_id' => $this->warehouse, 'is_active' => true, 'required_for_shift_close' => true]);
        $this->assertSame(1, DB::table('bar_check_templates')->count());

        $this->getJson('/api/v1/shifts/current/snapshot', $this->headers)->assertOk();
        $this->assertSame(1, DB::table('bar_check_templates')->count(), 'The default template is created once.');
    }

    public function test_without_any_sale_the_bar_counts_what_the_warehouse_holds(): void
    {
        $lines = $this->getJson('/api/v1/shifts/current/snapshot', $this->headers)->assertOk()->json('data.barCount.lines');

        $this->assertSame([(string) $this->item], array_column($lines, 'id'));
    }

    public function test_nothing_is_created_when_the_owner_already_has_a_template(): void
    {
        $this->consumeBySale();
        DB::table('bar_check_templates')->insert(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'warehouse_id' => $this->warehouse, 'name' => 'Owner choice', 'is_active' => false, 'required_for_shift_close' => false, 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/v1/shifts/current/snapshot', $this->headers)->assertOk();
        $this->assertSame(1, DB::table('bar_check_templates')->count());
    }

    public function test_a_required_bar_count_does_not_block_closing_and_is_posted_by_the_close_itself(): void
    {
        $this->consumeBySale();
        $shift = (int) DB::table('shifts')->where('tenant_id', $this->tenant)->value('id');

        $snapshot = $this->getJson('/api/v1/shifts/current/snapshot', $this->headers)->assertOk()->json('data');
        $this->assertSame([], $snapshot['pendingOperations']);

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => 0, 'barCountLines' => [['inventoryItemId' => $this->item, 'counted' => 8]]], $this->headers)->assertOk();

        $this->assertDatabaseHas('shifts', ['id' => $shift, 'status' => 'closed']);
        $this->assertDatabaseHas('stock_counts', ['shift_id' => $shift, 'status' => 'posted']);
    }

    public function test_negative_book_stock_can_be_confirmed_but_a_different_negative_count_is_rejected(): void
    {
        DB::table('stock_balances')->where('warehouse_id', $this->warehouse)->where('inventory_item_id', $this->item)->update(['quantity_on_hand' => '-5.000']);
        $this->consumeBySale();
        $shift = (int) DB::table('shifts')->where('tenant_id', $this->tenant)->value('id');
        $this->getJson('/api/v1/shifts/current/snapshot', $this->headers)->assertOk();

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => 0, 'barCountLines' => [['inventoryItemId' => $this->item, 'counted' => -3]]], $this->headers)->assertUnprocessable();
        $this->assertDatabaseHas('shifts', ['id' => $shift, 'status' => 'open']);

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => 0, 'barCountLines' => [['inventoryItemId' => $this->item, 'counted' => -5]]], $this->headers)->assertOk();
        $this->assertDatabaseHas('shifts', ['id' => $shift, 'status' => 'closed']);
    }
}
