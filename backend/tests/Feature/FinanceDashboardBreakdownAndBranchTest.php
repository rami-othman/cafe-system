<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/** Phase 10 test areas #54-61 (expense/payment-method breakdown) and #62-66 (branch performance). */
class FinanceDashboardBreakdownAndBranchTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_expense_breakdown_groups_by_category_with_percentage(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'brk-category');
        $branch = $this->branchId($tenant);
        $date = '2030-09-01';

        $rentAccount = $this->accountId($tenant, '6100');
        $rentCategory = (int) DB::table('expense_categories')->insertGetId(['tenant_id' => $tenant, 'code' => 'RENT', 'name' => 'Rent', 'financial_account_id' => $rentAccount, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->postExpenseInCategory($tenant, $branch, $date, '80.00', $rentCategory);
        $this->postExpenseInCategory($tenant, $branch, $date, '20.00', $this->expenseCategoryId($tenant));

        $data = $this->getJson("/api/v1/finance/dashboard/trends?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $breakdown = collect($data['expenseBreakdown'])->keyBy('code');
        $this->assertSame('80.00', $breakdown['RENT']['amount']);
        $this->assertSame(80.0, (float) $breakdown['RENT']['percentageOfTotal']);
        $this->assertSame(20.0, (float) $breakdown['DC-CAT']['percentageOfTotal']);
    }

    public function test_expense_breakdown_is_tenant_isolated(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'brk-tenant');
        $branch = $this->branchId($tenant);
        $date = '2030-09-02';

        $foreignTenant = (int) DB::table('tenants')->insertGetId(['name' => 'Foreign Brk', 'slug' => 'dash-foreign-brk', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        app(\App\Services\FinancialSetupService::class)->ensureForTenant($foreignTenant);
        DB::table('users')->insertGetId(['tenant_id' => $foreignTenant, 'name' => 'Foreign Owner', 'email' => 'foreign-brk-owner@test.local', 'password' => bcrypt('x'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $foreignBranch = (int) DB::table('branches')->insertGetId(['tenant_id' => $foreignTenant, 'name' => 'FB', 'currency' => 'USD', 'timezone' => 'UTC', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->postExpenseInCategory($foreignTenant, $foreignBranch, $date, '999.00', $this->expenseCategoryId($foreignTenant));
        $this->postExpenseInCategory($tenant, $branch, $date, '10.00', $this->expenseCategoryId($tenant));

        $data = $this->getJson("/api/v1/finance/dashboard/trends?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertCount(1, $data['expenseBreakdown']);
        $this->assertSame('10.00', $data['expenseBreakdown'][0]['amount']);
    }

    public function test_payment_methods_report_cash_and_card_received(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'brk-methods');
        $branch = $this->branchId($tenant);
        $date = '2030-09-03';
        $card = $this->makeCardPaymentMethod($tenant, 'BRKCARD');
        $cashMethodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');

        $cashOrder = $this->makeOrder($tenant, $branch, '40.00', $date.' 10:00:00');
        $this->makePayment($tenant, $branch, $cashOrder, '40.00', $date.' 10:00:00', 'cash', $cashMethodId);
        $cardOrder = $this->makeOrder($tenant, $branch, '60.00', $date.' 11:00:00');
        $this->makePayment($tenant, $branch, $cardOrder, '60.00', $date.' 11:00:00', 'card', $card['methodId']);

        $data = $this->getJson("/api/v1/finance/dashboard/trends?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $byCode = collect($data['paymentMethods'])->keyBy('code');
        $this->assertSame('40.00', $byCode['CASH']['grossReceived']);
        $this->assertSame('60.00', $byCode['BRKCARD']['grossReceived']);
    }

    public function test_refunds_reduce_the_correct_payment_method_bucket(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'brk-refund-method');
        $branch = $this->branchId($tenant);
        $date = '2030-09-04';

        $order = $this->makeOrder($tenant, $branch, '100.00', $date.' 10:00:00');
        $payment = $this->makePayment($tenant, $branch, $order, '100.00', $date.' 10:00:00', 'cash');
        $this->makeRefund($tenant, $branch, $order, $payment, '30.00', $date.' 11:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard/trends?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $cash = collect($data['paymentMethods'])->firstWhere('code', 'CASH');
        $this->assertSame('100.00', $cash['grossReceived']);
        $this->assertSame('30.00', $cash['refunds']);
        $this->assertSame('70.00', $cash['netReceived']);
    }

    public function test_legacy_payment_without_a_mapped_payment_method_is_reported_by_its_raw_method_string(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'brk-legacy');
        $branch = $this->branchId($tenant);
        $date = '2030-09-05';

        $order = $this->makeOrder($tenant, $branch, '25.00', $date.' 10:00:00');
        // No payment_method_id at all — legacy raw 'method' column only.
        DB::table('payments')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'order_id' => $order, 'method' => 'cash', 'payment_method_id' => null, 'amount' => '25.00', 'status' => 'completed', 'paid_at' => $date.' 10:00:00', 'created_at' => now(), 'updated_at' => now()]);

        $data = $this->getJson("/api/v1/finance/dashboard/trends?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $legacy = collect($data['paymentMethods'])->firstWhere('code', 'cash');
        $this->assertNotNull($legacy);
        $this->assertSame('25.00', $legacy['grossReceived']);
        $this->assertNull($legacy['paymentMethodId']);
    }

    public function test_branch_performance_reports_each_branch_correctly_without_cross_leakage(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'branch-perf');
        $downtown = $this->branchId($tenant, 'Downtown');
        $mall = $this->branchId($tenant, 'Mall');
        $date = '2030-09-06';

        $downtownOrder = $this->makeOrder($tenant, $downtown, '100.00', $date.' 10:00:00');
        DB::table('orders')->where('id', $downtownOrder)->update(['cogs_total' => '30.00']);
        $this->makePayment($tenant, $downtown, $downtownOrder, '100.00', $date.' 10:00:00');

        $mallOrder = $this->makeOrder($tenant, $mall, '200.00', $date.' 10:00:00');
        DB::table('orders')->where('id', $mallOrder)->update(['cogs_total' => '50.00']);
        $this->makePayment($tenant, $mall, $mallOrder, '200.00', $date.' 10:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard/branches?date_from=$date&date_to=$date", $headers)->assertOk()->json('data');
        $byBranch = collect($data['branches'])->keyBy(fn ($row) => $row['branch']['id']);
        $this->assertSame('100.00', $byBranch[$downtown]['netSales']);
        $this->assertSame('30.00', $byBranch[$downtown]['cogs']);
        $this->assertSame('200.00', $byBranch[$mall]['netSales']);
        $this->assertSame('50.00', $byBranch[$mall]['cogs']);
    }

    public function test_company_wide_expense_remains_unallocated_across_branches(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'branch-unalloc');
        $date = '2030-09-07';

        $expenseAccountId = $this->accountId($tenant, '6190');
        $cashAccountId = $this->accountId($tenant, '1010');
        $journalId = (int) DB::table('journal_entries')->insertGetId(['tenant_id' => $tenant, 'branch_id' => null, 'entry_number' => 'UA-'.uniqid(), 'entry_date' => $date, 'source_type' => 'manual', 'status' => 'posted', 'posted_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $expenseAccountId, 'line_number' => 1, 'debit' => '90.00', 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $cashAccountId, 'line_number' => 2, 'debit' => '0.00', 'credit' => '90.00', 'created_at' => now(), 'updated_at' => now()]);

        $data = $this->getJson("/api/v1/finance/dashboard/branches?date_from=$date&date_to=$date", $headers)->assertOk()->json('data');
        $this->assertSame('90.00', $data['unallocatedCompanyExpenses']);
        foreach ($data['branches'] as $row) {
            $this->assertSame('0.00', $row['operatingExpenses']);
        }
    }

    public function test_incomplete_cogs_branch_is_marked_unreliable_and_not_used_for_ranking(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'branch-unreliable');
        $downtown = $this->branchId($tenant, 'Downtown');
        $mall = $this->branchId($tenant, 'Mall');
        $date = '2030-09-08';

        $downtownOrder = $this->makeOrder($tenant, $downtown, '100.00', $date.' 10:00:00');
        DB::table('orders')->where('id', $downtownOrder)->update(['cogs_total' => '30.00']);
        $this->makePayment($tenant, $downtown, $downtownOrder, '100.00', $date.' 10:00:00');

        // Mall's sale has no cogs_total at all — incomplete coverage.
        $mallOrder = $this->makeOrder($tenant, $mall, '500.00', $date.' 10:00:00');
        $this->makePayment($tenant, $mall, $mallOrder, '500.00', $date.' 10:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard/branches?date_from=$date&date_to=$date", $headers)->assertOk()->json('data');
        $byBranch = collect($data['branches'])->keyBy(fn ($row) => $row['branch']['id']);
        $this->assertTrue($byBranch[$downtown]['comparisonReliable']);
        $this->assertFalse($byBranch[$mall]['comparisonReliable']);
        $this->assertSame('unavailable', $byBranch[$mall]['dataQuality']['cogs']);
        $this->assertNull($byBranch[$mall]['grossMarginPercentage']);
    }

    private function postExpenseInCategory(int $tenant, int $branch, string $date, string $amount, int $categoryId): int
    {
        $request = \Illuminate\Http\Request::create('/x', 'POST');
        $actor = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        $method = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $location = $this->locationId($tenant, 'CASH-DRAWER');
        $service = app(\App\Services\ExpenseService::class);
        $expenseId = $service->create($request, $tenant, ['branchId' => $branch, 'expenseCategoryId' => $categoryId, 'amount' => $amount, 'taxAmount' => '0.00', 'expenseDate' => $date, 'description' => 'cat test', 'idempotencyKey' => 'brk-exp-'.uniqid()], $actor)->id;
        $service->transition($request, $tenant, $expenseId, 'submit', [], $actor);
        $service->transition($request, $tenant, $expenseId, 'approve', [], $actor);
        $service->pay($request, $tenant, $expenseId, ['paymentMethodId' => $method, 'financialLocationId' => $location, 'paymentDate' => $date, 'idempotencyKey' => 'brk-exp-pay-'.uniqid()], $actor);

        return $expenseId;
    }
}
