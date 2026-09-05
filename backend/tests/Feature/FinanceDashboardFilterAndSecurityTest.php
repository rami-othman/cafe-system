<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/**
 * Phase 10 test areas #1-7: filter context resolution and branch/tenant
 * security. The tenant (cafe-618) is seeded with 4 branches and timezone
 * Asia/Damascus (UTC+3, no DST).
 */
class FinanceDashboardFilterAndSecurityTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_date_range_is_resolved_from_query_params(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'ctx-dates');

        $data = $this->getJson('/api/v1/finance/dashboard?date_from=2030-01-05&date_to=2030-01-10', $headers)->assertOk()->json('data');
        $this->assertSame('2030-01-05', $data['context']['dateFrom']);
        $this->assertSame('2030-01-10', $data['context']['dateTo']);
    }

    public function test_tenant_timezone_is_respected_for_sales_boundary(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'ctx-tz');
        $branch = $this->branchId($tenant);

        // Asia/Damascus is UTC+3: local 2030-02-15 00:01 = UTC 2030-02-14 21:01,
        // so this sale belongs to the 15th despite its UTC date being the 14th.
        $order = $this->makeOrder($tenant, $branch, '30.00', '2030-02-14 21:01:00');
        $this->makePayment($tenant, $branch, $order, '30.00', '2030-02-14 21:01:00');

        $data14 = $this->getJson("/api/v1/finance/dashboard?date_from=2030-02-14&date_to=2030-02-14&branch_id=$branch", $headers)->assertOk()->json('data');
        $data15 = $this->getJson("/api/v1/finance/dashboard?date_from=2030-02-15&date_to=2030-02-15&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('Asia/Damascus', $data15['context']['timezone']);
        $this->assertSame('0.00', $data14['kpis']['netSales']['current']);
        $this->assertSame('30.00', $data15['kpis']['netSales']['current']);
    }

    public function test_owner_sees_all_tenant_branches_by_default(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'ctx-owner');

        $data = $this->getJson('/api/v1/finance/dashboard?date_from=2030-03-01&date_to=2030-03-01', $headers)->assertOk()->json('data');
        $this->assertCount(4, $data['context']['branches']);
        $this->assertNull($data['context']['selectedBranchId']);
    }

    public function test_single_branch_manager_is_restricted_to_their_branch(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $downtown = $this->branchId($tenant, 'Downtown');
        $headers = $this->headers($tenant, 'manager', 'ctx-single-mgr', $downtown);

        $data = $this->getJson('/api/v1/finance/dashboard?date_from=2030-03-02&date_to=2030-03-02', $headers)->assertOk()->json('data');
        $this->assertCount(1, $data['context']['branches']);
        $this->assertSame($downtown, $data['context']['branches'][0]['id']);
    }

    public function test_multi_branch_manager_is_restricted_to_assigned_branches(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $downtown = $this->branchId($tenant, 'Downtown');
        $mall = $this->branchId($tenant, 'Mall');
        $headers = $this->headers($tenant, 'manager', 'ctx-multi-mgr', $downtown);
        $userId = (int) DB::table('users')->where('tenant_id', $tenant)->where('email', 'ctx-multi-mgr-manager-'.$tenant.'@test.local')->value('id');
        DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $userId, 'branch_id' => $mall, 'created_at' => now(), 'updated_at' => now()]);

        $data = $this->getJson('/api/v1/finance/dashboard?date_from=2030-03-03&date_to=2030-03-03', $headers)->assertOk()->json('data');
        $branchIds = array_column($data['context']['branches'], 'id');
        $this->assertCount(2, $branchIds);
        $this->assertContains($downtown, $branchIds);
        $this->assertContains($mall, $branchIds);
    }

    public function test_unauthorized_branch_filter_is_rejected(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $downtown = $this->branchId($tenant, 'Downtown');
        $airport = $this->branchId($tenant, 'Airport');
        $headers = $this->headers($tenant, 'manager', 'ctx-unauth-mgr', $downtown);

        $this->getJson("/api/v1/finance/dashboard?date_from=2030-03-04&date_to=2030-03-04&branch_id=$airport", $headers)->assertForbidden();
    }

    public function test_omitted_branch_filter_does_not_expand_manager_scope(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $downtown = $this->branchId($tenant, 'Downtown');
        $airport = $this->branchId($tenant, 'Airport');
        $headers = $this->headers($tenant, 'manager', 'ctx-noleak-mgr', $downtown);
        $date = '2030-03-05';

        // A large sale in a branch this manager is NOT assigned to.
        $order = $this->makeOrder($tenant, $airport, '5000.00', $date.' 12:00:00');
        $this->makePayment($tenant, $airport, $order, '5000.00', $date.' 12:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date", $headers)->assertOk()->json('data');
        $this->assertSame('0.00', $data['kpis']['netSales']['current']);
    }
}
