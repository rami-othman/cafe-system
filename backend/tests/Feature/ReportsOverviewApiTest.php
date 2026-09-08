<?php

namespace Tests\Feature;

use Database\Seeders\ReportsOverviewSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ReportsOverviewApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_overview_is_tenant_isolated_and_returns_real_aggregates(): void
    {
        $this->seed();
        $this->seed(ReportsOverviewSeeder::class);
        $seededOrderCount = DB::table('orders')->where('order_number', 'like', 'RPT-%')->count();
        $this->seed(ReportsOverviewSeeder::class);
        $this->assertSame($seededOrderCount, DB::table('orders')->where('order_number', 'like', 'RPT-%')->count());
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $otherTenant = DB::table('tenants')->insertGetId(['name' => 'Other cafe', 'slug' => 'other-cafe', 'status' => 'active', 'plan' => 'starter', 'currency' => 'SYP', 'timezone' => 'UTC', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $otherTenant, 'name' => 'Hidden Branch', 'currency' => 'SYP', 'timezone' => 'UTC', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        $response = $this->getJson($this->overviewPath(), $this->headers($tenantId));

        // grossProfit.available reflects whether every paid order in the
        // period has a recorded cogs_total (see ReportsOverviewController::
        // period()'s missing_cogs count). ReportsOverviewSeeder always sets
        // cogs_total on the rows it inserts, and the demo POS activity
        // DatabaseSeeder now seeds (Cafe618PosSalesDemoSeeder) pays every
        // order through the real /pay endpoint, which unconditionally
        // records cogs_total (0.00 for non-inventory-tracked items) via
        // SaleConsumptionService — so every order in the default window
        // genuinely has COGS recorded and gross profit is correctly
        // available. This used to read false only because the legacy
        // PosDemoSeeder wrote orders directly and left cogs_total NULL; that
        // seeder is no longer part of DatabaseSeeder (see its own comment).
        // The negative branch of this contract — grossProfit becoming
        // unavailable when a paid order really is missing recorded COGS — is
        // covered explicitly below by
        // test_gross_profit_is_unavailable_when_a_paid_order_is_missing_recorded_cogs().
        $response->assertOk()
            ->assertJsonCount(4, 'data.branches')
            ->assertJsonMissing(['name' => 'Hidden Branch'])
            ->assertJsonPath('data.kpis.grossProfit.available', true)
            ->assertJsonPath('data.kpis.totalExpenses.available', true);
        $this->assertSame(
            $response->json('data.branchComparison'),
            collect($response->json('data.branchComparison'))->sortByDesc('netSales')->values()->all(),
        );
        foreach ($response->json('data.recentExceptions') as $exception) {
            $this->assertTrue(str_starts_with($exception['description'], 'Cash difference') || str_starts_with($exception['description'], 'Low stock') || str_starts_with($exception['description'], 'Out of stock'));
        }
    }

    public function test_overview_filters_dates_and_branches_and_uses_paid_sales_minus_refunds(): void
    {
        $this->seed();
        $this->seed(ReportsOverviewSeeder::class);
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
        $from = now()->subDays(13)->toDateString();
        $to = now()->toDateString();
        $response = $this->getJson("/api/v1/reports/overview?from={$from}&to={$to}&branch_id={$branchId}", $this->headers($tenantId));
        $sales = (float) DB::table('orders')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])->whereBetween('closed_at', [now()->subDays(13)->startOfDay(), now()->endOfDay()])->sum('total');
        $refunds = (float) DB::table('payment_refunds')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('status', 'completed')->whereBetween('refunded_at', [now()->subDays(13)->startOfDay(), now()->endOfDay()])->sum('amount');

        $response->assertOk()
            ->assertJsonPath('data.selectedBranchId', $branchId)
            ->assertJsonCount(0, 'data.branchComparison')
            ->assertJsonPath('data.kpis.netSales.value', round($sales - $refunds, 2));
        $this->assertCount(14, $response->json('data.salesTrend'));
        $products = $response->json('data.topProducts');
        $this->assertSame($products, collect($products)->sortByDesc('netSales')->values()->all());
    }

    public function test_gross_profit_is_unavailable_when_a_paid_order_is_missing_recorded_cogs(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
        $now = now();
        // A paid order written outside the real payment pipeline (e.g. a
        // direct insert) never gets SaleConsumptionService's unconditional
        // cogs_total write — this is the one genuine "COGS not recorded"
        // case ReportsOverviewController's missing_cogs check exists to catch.
        DB::table('orders')->insert([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_number' => 'COGS-GAP-1',
            'type' => 'takeaway', 'status' => 'paid', 'payment_status' => 'paid',
            'subtotal' => '10.00', 'discount_total' => 0, 'tax_total' => 0, 'service_total' => 0, 'total' => '10.00',
            'cogs_total' => null, 'opened_at' => $now->copy()->subMinutes(5), 'closed_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);

        $response = $this->getJson($this->overviewPath(), $this->headers($tenantId));

        $response->assertOk()
            ->assertJsonPath('data.kpis.grossProfit.available', false)
            ->assertJsonPath('data.kpis.grossProfit.value', null)
            ->assertJsonPath('data.kpis.grossProfit.reason', 'Cost of goods sold has not been recorded for every paid order.');
    }

    public function test_overview_rejects_a_branch_outside_the_tenant(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $otherTenant = DB::table('tenants')->insertGetId(['name' => 'Other cafe', 'slug' => 'other-cafe', 'status' => 'active', 'plan' => 'starter', 'currency' => 'SYP', 'timezone' => 'UTC', 'created_at' => now(), 'updated_at' => now()]);
        $branchId = DB::table('branches')->insertGetId(['tenant_id' => $otherTenant, 'name' => 'Foreign Branch', 'currency' => 'SYP', 'timezone' => 'UTC', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        $this->getJson($this->overviewPath()."&branch_id={$branchId}", $this->headers($tenantId))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('branch_id');
    }

    public function test_overview_requires_authentication(): void
    {
        $this->call('GET', $this->overviewPath())->assertUnauthorized();
    }

    private function overviewPath(): string
    {
        return '/api/v1/reports/overview?from='.now()->subDays(13)->toDateString().'&to='.now()->toDateString().'&compare_previous=true';
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = 'reports-overview-test-token';
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'reports-overview-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
