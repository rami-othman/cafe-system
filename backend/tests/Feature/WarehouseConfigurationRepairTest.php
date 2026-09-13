<?php

namespace Tests\Feature;

use App\Services\Inventory\WarehouseConfigurationRepairService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class WarehouseConfigurationRepairTest extends TestCase
{
    use RefreshDatabase;

    public function test_dry_run_does_not_write_and_apply_creates_only_the_missing_branch_main(): void
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
}
