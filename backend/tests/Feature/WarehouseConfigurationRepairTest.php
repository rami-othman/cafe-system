<?php

namespace Tests\Feature;

use App\Exceptions\OrderLifecycleException;
use App\Services\FinancialSetupService;
use App\Services\Inventory\WarehouseConfigurationRepairService;
use App\Services\PosInventoryWarehouseResolver;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class WarehouseConfigurationRepairTest extends TestCase
{
    use RefreshDatabase;

    public function test_dry_run_does_not_write_and_apply_creates_only_missing_main_without_touching_stock(): void
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Repair Tenant', 'slug' => 'repair-tenant', 'status' => 'active', 'created_at' => $now, 'updated_at' => $now]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Repair Branch', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $service = app(WarehouseConfigurationRepairService::class);

        $dryRun = $service->run(false, $tenant);
        $this->assertSame('MISSING_BRANCH_MAIN', $dryRun['findings'][0]['code']);
        $this->assertSame(0, $dryRun['fixed']);
        $this->assertSame(0, DB::table('warehouses')->where('tenant_id', $tenant)->count());

        $applied = $service->run(true, $tenant);
        $this->assertSame(1, $applied['fixed']);
        $this->assertDatabaseHas('warehouses', ['tenant_id' => $tenant, 'branch_id' => $branch, 'type' => 'branch_main', 'is_active' => true]);
        $this->assertDatabaseMissing('warehouses', ['tenant_id' => $tenant, 'branch_id' => $branch, 'type' => 'bar']);
        $this->assertNull(DB::table('branches')->where('id', $branch)->value('pos_inventory_warehouse_id'));
        $this->assertSame(
            (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('branch_id', $branch)->where('type', 'branch_main')->value('id'),
            (int) app(PosInventoryWarehouseResolver::class)->forBranch($tenant, $branch)->id,
        );
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('stock_balances')->where('tenant_id', $tenant)->count());
    }

    public function test_duplicate_branch_main_is_reported_but_never_auto_modified(): void
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Duplicate Tenant', 'slug' => 'duplicate-tenant', 'status' => 'active', 'created_at' => $now, 'updated_at' => $now]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Duplicate Branch', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        foreach (['PRIMARY-A', 'PRIMARY-B'] as $code) {
            DB::table('warehouses')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'name' => $code, 'code' => $code, 'type' => 'branch_main', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        }

        $result = app(WarehouseConfigurationRepairService::class)->run(true, $tenant);
        $this->assertTrue(collect($result['findings'])->contains(fn (array $finding) => $finding['code'] === 'DUPLICATE_BRANCH_MAIN' && $finding['action'] === 'manual_review'));
        $this->assertSame(2, DB::table('warehouses')->where('tenant_id', $tenant)->where('type', 'branch_main')->count());
    }

    public function test_multiple_bar_candidates_are_reported_and_never_guessed(): void
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Bar Tenant', 'slug' => 'bar-tenant', 'status' => 'active', 'created_at' => $now, 'updated_at' => $now]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Bar Branch', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        app(FinancialSetupService::class)->ensureBranchMainWarehouse($tenant, $branch);
        foreach (['BAR-A', 'BAR-B'] as $code) {
            DB::table('warehouses')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'name' => $code, 'code' => $code, 'type' => 'bar', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        }

        $result = app(WarehouseConfigurationRepairService::class)->run(true, $tenant);

        $this->assertTrue(collect($result['findings'])->contains(fn (array $finding) => $finding['code'] === 'MULTIPLE_POS_BAR_CANDIDATES' && $finding['action'] === 'manual_review'));
        $this->assertNull(DB::table('branches')->where('id', $branch)->value('pos_inventory_warehouse_id'));
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
