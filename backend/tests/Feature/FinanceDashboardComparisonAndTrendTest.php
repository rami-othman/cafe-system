<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/** Phase 10 test areas #44-49 (comparison periods) and #50-53 (trends). */
class FinanceDashboardComparisonAndTrendTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_previous_period_resolves_to_an_equal_length_immediately_preceding_range(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cmp-resolve');

        $data = $this->getJson('/api/v1/finance/dashboard?date_from=2030-07-11&date_to=2030-07-20&comparison=previous_period', $headers)->assertOk()->json('data');
        $this->assertSame('2030-07-01', $data['context']['comparison']['from']);
        $this->assertSame('2030-07-10', $data['context']['comparison']['to']);
    }

    public function test_percentage_increase_is_computed(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cmp-pct-up');
        $branch = $this->branchId($tenant);

        $previous = $this->makeOrder($tenant, $branch, '100.00', '2030-07-05 12:00:00');
        $this->makePayment($tenant, $branch, $previous, '100.00', '2030-07-05 12:00:00');
        $current = $this->makeOrder($tenant, $branch, '150.00', '2030-07-15 12:00:00');
        $this->makePayment($tenant, $branch, $current, '150.00', '2030-07-15 12:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=2030-07-11&date_to=2030-07-20&branch_id=$branch&comparison=previous_period", $headers)->assertOk()->json('data');
        $this->assertSame('150.00', $data['kpis']['netSales']['current']);
        $this->assertSame('100.00', $data['kpis']['netSales']['previous']);
        $this->assertSame(50.0, (float) $data['kpis']['netSales']['percentageChange']);
        $this->assertSame('increase', $data['kpis']['netSales']['changeState']);
    }

    public function test_percentage_decrease_is_computed(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cmp-pct-down');
        $branch = $this->branchId($tenant);

        $previous = $this->makeOrder($tenant, $branch, '200.00', '2030-07-05 12:00:00');
        $this->makePayment($tenant, $branch, $previous, '200.00', '2030-07-05 12:00:00');
        $current = $this->makeOrder($tenant, $branch, '150.00', '2030-07-15 12:00:00');
        $this->makePayment($tenant, $branch, $current, '150.00', '2030-07-15 12:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=2030-07-11&date_to=2030-07-20&branch_id=$branch&comparison=previous_period", $headers)->assertOk()->json('data');
        $this->assertSame('150.00', $data['kpis']['netSales']['current']);
        $this->assertSame('200.00', $data['kpis']['netSales']['previous']);
        $this->assertSame(-25.0, (float) $data['kpis']['netSales']['percentageChange']);
        $this->assertSame('decrease', $data['kpis']['netSales']['changeState']);
    }

    public function test_previous_zero_is_handled_safely_as_new_not_infinite(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cmp-zero');
        $branch = $this->branchId($tenant);

        $order = $this->makeOrder($tenant, $branch, '80.00', '2030-07-15 12:00:00');
        $this->makePayment($tenant, $branch, $order, '80.00', '2030-07-15 12:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=2030-07-11&date_to=2030-07-20&branch_id=$branch&comparison=previous_period", $headers)->assertOk()->json('data');
        $this->assertNull($data['kpis']['netSales']['percentageChange']);
        $this->assertSame('new', $data['kpis']['netSales']['changeState']);
    }

    public function test_balance_kpis_compare_as_of_balances_not_summed_flows(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cmp-balance');

        $this->postJournal($tenant, '1010', '3000', '400.00', '2030-07-05'); // within comparison window
        $this->postJournal($tenant, '1010', '3000', '600.00', '2030-07-15'); // within current window

        $data = $this->getJson('/api/v1/finance/dashboard?date_from=2030-07-11&date_to=2030-07-20&comparison=previous_period', $headers)->assertOk()->json('data');
        // Comparison "previous" cash balance is the ending balance AS OF 07-10 (12500+400=12900),
        // not the sum of movements WITHIN 07-01..07-10.
        $this->assertSame('12900.00', $data['kpis']['cashBanks']['previousTotal']);
        $this->assertSame('13500.00', $data['kpis']['cashBanks']['total']);
    }

    public function test_comparison_none_returns_no_comparison_window(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cmp-none');

        $data = $this->getJson('/api/v1/finance/dashboard?date_from=2030-07-11&date_to=2030-07-20&comparison=none', $headers)->assertOk()->json('data');
        $this->assertNull($data['context']['comparison']['from']);
        $this->assertNull($data['kpis']['netSales']['previous']);
        $this->assertNull($data['kpis']['netSales']['percentageChange']);
    }

    public function test_daily_trend_granularity_for_a_short_range(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'trend-daily');
        $branch = $this->branchId($tenant);

        $order = $this->makeOrder($tenant, $branch, '40.00', '2030-08-05 12:00:00');
        $this->makePayment($tenant, $branch, $order, '40.00', '2030-08-05 12:00:00');
        $this->makeRefund($tenant, $branch, $order, null, '10.00', '2030-08-05 13:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard/trends?date_from=2030-08-01&date_to=2030-08-10&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('day', $data['revenueVsExpenses']['granularity']);
        $bucket = collect($data['revenueVsExpenses']['series'])->firstWhere('periodStart', '2030-08-05');
        $this->assertSame('30.00', $bucket['netSales']);
    }

    public function test_longer_range_uses_week_or_month_granularity(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'trend-long');

        $week = $this->getJson('/api/v1/finance/dashboard/trends?date_from=2030-01-01&date_to=2030-04-01', $headers)->assertOk()->json('data');
        $this->assertSame('week', $week['revenueVsExpenses']['granularity']);

        $month = $this->getJson('/api/v1/finance/dashboard/trends?date_from=2030-01-01&date_to=2031-06-01', $headers)->assertOk()->json('data');
        $this->assertSame('month', $month['revenueVsExpenses']['granularity']);
    }

    public function test_cogs_coverage_is_reported_per_trend_bucket(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'trend-cogs');
        $branch = $this->branchId($tenant);

        $covered = $this->makeOrder($tenant, $branch, '50.00', '2030-08-06 12:00:00');
        DB::table('orders')->where('id', $covered)->update(['cogs_total' => '20.00']);
        $this->makePayment($tenant, $branch, $covered, '50.00', '2030-08-06 12:00:00');
        $uncovered = $this->makeOrder($tenant, $branch, '30.00', '2030-08-07 12:00:00');
        $this->makePayment($tenant, $branch, $uncovered, '30.00', '2030-08-07 12:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard/trends?date_from=2030-08-01&date_to=2030-08-10&branch_id=$branch", $headers)->assertOk()->json('data');
        $covered6 = collect($data['salesCogsGrossProfit']['series'])->firstWhere('periodStart', '2030-08-06');
        $uncovered7 = collect($data['salesCogsGrossProfit']['series'])->firstWhere('periodStart', '2030-08-07');
        $this->assertSame('complete', $covered6['cogsCoverage']['status']);
        $this->assertSame('unavailable', $uncovered7['cogsCoverage']['status']);
    }

    private function postJournal(int $tenant, string $debitCode, string $creditCode, string $amount, string $date): int
    {
        $debit = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $debitCode)->value('id');
        $credit = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $creditCode)->value('id');
        $journalId = (int) DB::table('journal_entries')->insertGetId(['tenant_id' => $tenant, 'branch_id' => null, 'entry_number' => 'CMPJ-'.uniqid(), 'entry_date' => $date, 'source_type' => 'manual', 'status' => 'posted', 'posted_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $debit, 'line_number' => 1, 'debit' => $amount, 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $credit, 'line_number' => 2, 'debit' => '0.00', 'credit' => $amount, 'created_at' => now(), 'updated_at' => now()]);

        return $journalId;
    }
}
