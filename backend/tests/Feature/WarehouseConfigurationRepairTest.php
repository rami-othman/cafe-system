<?php

namespace Tests\Feature;

use App\Exceptions\OrderLifecycleException;
use App\Services\Inventory\WarehouseConfigurationRepairService;
use App\Services\PosInventoryWarehouseResolver;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class WarehouseConfigurationRepairTest extends TestCase
{
    use RefreshDatabase;

    public function test_dry_run_does_not_write_and_apply_creates_only_missing_warehouse_without_touching_stock(): void
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Repair Tenant', 'slug' => 'repair-tenant', 'status' => 'active', 'created_at' => $now, 'updated_at' => $now]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Repair Branch', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $service = app(WarehouseConfigurationRepairService::class);

        $dryRun = $service->run(false, $tenant);
        $this->assertSame('MISSING_WAREHOUSE', $dryRun['findings'][0]['code']);
        $this->assertSame(0, $dryRun['fixed']);
        $this->assertSame(0, DB::table('warehouses')->where('tenant_id', $tenant)->count());

        $applied = $service->run(true, $tenant);
        $this->assertSame(1, $applied['fixed']);
        $warehouse = DB::table('warehouses')->where('tenant_id', $tenant)->where('branch_id', $branch)->whereNull('deleted_at')->sole();
        $this->assertTrue((bool) $warehouse->is_active);
        $this->assertSame(
            (int) $warehouse->id,
            (int) app(PosInventoryWarehouseResolver::class)->forBranch($tenant, $branch)->id,
        );
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('stock_balances')->where('tenant_id', $tenant)->count());
    }

    public function test_ambiguous_pos_configuration_is_reported_but_never_auto_modified(): void
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Duplicate Tenant', 'slug' => 'duplicate-tenant', 'status' => 'active', 'created_at' => $now, 'updated_at' => $now]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Duplicate Branch', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        foreach (['STORE-A', 'STORE-B'] as $code) {
            DB::table('warehouses')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'name' => $code, 'code' => $code, 'type' => 'other', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        }

        $result = app(WarehouseConfigurationRepairService::class)->run(true, $tenant);
        $this->assertTrue(collect($result['findings'])->contains(fn (array $finding) => $finding['code'] === 'AMBIGUOUS_POS_WAREHOUSE' && $finding['action'] === 'manual_review'));
        $this->assertSame(2, DB::table('warehouses')->where('tenant_id', $tenant)->where('branch_id', $branch)->count());
        $this->assertNull(DB::table('branches')->where('id', $branch)->value('pos_inventory_warehouse_id'));
    }

    public function test_invalid_pos_configuration_is_reported_for_manual_review(): void
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Invalid Config Tenant', 'slug' => 'invalid-config-tenant', 'status' => 'active', 'created_at' => $now, 'updated_at' => $now]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Invalid Config Branch', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('warehouses')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'name' => 'Store', 'code' => 'STORE', 'type' => 'other', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        // A warehouse that genuinely exists but belongs to a different branch is "invalid" for this branch — never a non-existent id (which is a foreign-key violation, not an application-level fault).
        $otherBranch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Other Branch', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $otherWarehouse = (int) DB::table('warehouses')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $otherBranch, 'name' => 'Other Store', 'code' => 'OTHER-STORE', 'type' => 'other', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('branches')->where('id', $branch)->update(['pos_inventory_warehouse_id' => $otherWarehouse]);

        $result = app(WarehouseConfigurationRepairService::class)->run(true, $tenant);

        $this->assertTrue(collect($result['findings'])->contains(fn (array $finding) => $finding['code'] === 'INVALID_POS_WAREHOUSE_CONFIGURATION' && $finding['action'] === 'manual_review' && $finding['branchId'] === $branch));
    }

    public function test_pos_warehouse_resolver_rejects_cross_tenant_and_cross_branch_configuration(): void
    {
        $now = now();
        $tenantA = (int) DB::table('tenants')->insertGetId(['name' => 'Tenant A', 'slug' => 'tenant-a-pos', 'status' => 'active', 'created_at' => $now, 'updated_at' => $now]);
        $tenantB = (int) DB::table('tenants')->insertGetId(['name' => 'Tenant B', 'slug' => 'tenant-b-pos', 'status' => 'active', 'created_at' => $now, 'updated_at' => $now]);
        $branchA = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenantA, 'name' => 'A', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $branchB = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenantB, 'name' => 'B', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $barB = (int) DB::table('warehouses')->insertGetId(['tenant_id' => $tenantB, 'branch_id' => $branchB, 'name' => 'B Bar', 'code' => 'B-BAR', 'type' => 'bar', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('branches')->where('id', $branchA)->update(['pos_inventory_warehouse_id' => $barB]);

        try {
            app(PosInventoryWarehouseResolver::class)->forBranch($tenantA, $branchA);
            $this->fail('Expected an invalid explicit POS warehouse configuration.');
        } catch (OrderLifecycleException $exception) {
            $this->assertSame('POS_WAREHOUSE_INVALID', $exception->domainCode);
        }
    }
}
