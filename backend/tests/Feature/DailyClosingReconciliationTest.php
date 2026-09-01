<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/**
 * Phase 9 remaining gap #3 — DailyClosingReconciliationPolicy. Cash is the
 * only hard blocker; Card/Bank have no configured daily-required frequency
 * anywhere in the domain, so unresolved Card/Bank reconciliation is a
 * WARNING only, per the explicit Phase 9 policy decision.
 */
class DailyClosingReconciliationTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_required_cash_reconciliation_missing_blocks_close(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-missing');
        $branch = $this->branchId($tenant);
        $date = '2030-04-01';

        $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 12:00:00', 'cash');

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertContains('CASH_RECONCILIATION_INCOMPLETE', array_column($preview['blockers'], 'code'));
    }

    public function test_cash_reconciliation_in_progress_still_blocks_close(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-progress');
        $branch = $this->branchId($tenant);
        $date = '2030-04-02';

        $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 12:00:00', 'cash');
        $this->insertReconciliation($tenant, 'cash', $this->accountId($tenant, '1010'), $date, $date, 'in_progress', $branch);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertContains('CASH_RECONCILIATION_INCOMPLETE', array_column($preview['blockers'], 'code'));
    }

    public function test_completed_correct_cash_reconciliation_clears_the_blocker(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-complete');
        $branch = $this->branchId($tenant);
        $date = '2030-04-03';

        $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 12:00:00', 'cash');
        $this->insertReconciliation($tenant, 'cash', $this->accountId($tenant, '1010'), $date, $date, 'completed', $branch);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertNotContains('CASH_RECONCILIATION_INCOMPLETE', array_column($preview['blockers'], 'code'));
    }

    public function test_completed_cash_reconciliation_for_wrong_date_does_not_clear_the_blocker(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-wrongdate');
        $branch = $this->branchId($tenant);
        $date = '2030-04-04';

        $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 12:00:00', 'cash');
        // Completed, but for a different period entirely.
        $this->insertReconciliation($tenant, 'cash', $this->accountId($tenant, '1010'), '2030-04-01', '2030-04-01', 'completed', $branch);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertContains('CASH_RECONCILIATION_INCOMPLETE', array_column($preview['blockers'], 'code'));
    }

    public function test_completed_cash_reconciliation_for_wrong_account_does_not_clear_the_blocker(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-wrongaccount');
        $branch = $this->branchId($tenant);
        $date = '2030-04-05';

        $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 12:00:00', 'cash');
        // Completed for the Bank account, not either seeded Cash account (1010/1020).
        $this->insertReconciliation($tenant, 'cash', $this->accountId($tenant, '1030'), $date, $date, 'completed', $branch);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertContains('CASH_RECONCILIATION_INCOMPLETE', array_column($preview['blockers'], 'code'));
    }

    public function test_another_branch_reconciliation_cannot_satisfy_this_branch(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-branchscope');
        $branch = $this->branchId($tenant);
        $date = '2030-04-06';

        $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 12:00:00', 'cash');

        // A branch-scoped cash location for a different branch, completed reconciliation — must not satisfy this branch's shared/tenant-wide cash accounts.
        $mall = $this->branchId($tenant, 'Mall');
        $mallCashAccount = (int) DB::table('financial_accounts')->insertGetId(['tenant_id' => $tenant, 'code' => 'MALL-CASH', 'name_ar' => 'x', 'name_en' => 'x', 'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('financial_locations')->insert(['tenant_id' => $tenant, 'branch_id' => $mall, 'financial_account_id' => $mallCashAccount, 'code' => 'MALL-CASH-DRAWER', 'name' => 'Mall Cash', 'kind' => 'cash', 'type' => 'cash_drawer', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->insertReconciliation($tenant, 'cash', $mallCashAccount, $date, $date, 'completed', $mall);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertContains('CASH_RECONCILIATION_INCOMPLETE', array_column($preview['blockers'], 'code'));
    }

    public function test_unresolved_card_reconciliation_is_a_warning_not_a_blocker(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-card');
        $branch = $this->branchId($tenant);
        $date = '2030-04-07';

        $card = $this->makeCardPaymentMethod($tenant, 'RCARD1');
        $order = $this->makeOrder($tenant, $branch, '200.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '200.00', $date.' 12:00:00', 'card', $card['methodId']);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertNotContains('CARD_RECONCILIATION_INCOMPLETE', array_column($preview['blockers'], 'code'));
        $this->assertContains('CARD_RECONCILIATION_INCOMPLETE', array_column($preview['warnings'], 'code'));

        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => $preview['cash']['expectedCash']], $headers)->assertOk();
        $ready = $this->getJson("/api/v1/finance/daily-closings/{$preview['id']}", $headers)->assertOk()->json('data');
        $this->assertTrue($ready['canClose']);
    }

    public function test_unresolved_bank_reconciliation_is_a_warning_not_a_blocker(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-bank');
        $branch = $this->branchId($tenant);
        $date = '2030-04-08';

        $this->makeExpense($tenant, $branch, '75.00', $date, 'paid', 'BANK');

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertNotContains('BANK_RECONCILIATION_INCOMPLETE', array_column($preview['blockers'], 'code'));
        $this->assertContains('BANK_RECONCILIATION_INCOMPLETE', array_column($preview['warnings'], 'code'));
    }

    public function test_reconciliation_summary_counts_are_exposed_on_preview(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'recon-summary');
        $branch = $this->branchId($tenant);
        $date = '2030-04-09';

        $order = $this->makeOrder($tenant, $branch, '30.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '30.00', $date.' 12:00:00', 'cash');
        $this->insertReconciliation($tenant, 'cash', $this->accountId($tenant, '1010'), $date, $date, 'completed', $branch);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertSame(1, $preview['reconciliation']['requiredCount']);
        $this->assertSame(1, $preview['reconciliation']['completedCount']);
        $this->assertSame(0, $preview['reconciliation']['incompleteCount']);
        $this->assertSame(0, $preview['reconciliation']['blockingCount']);
    }

    private function insertReconciliation(int $tenant, string $type, int $accountId, string $from, string $to, string $status, int $branch): int
    {
        return (int) DB::table('financial_reconciliations')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'financial_account_id' => $accountId,
            'reference' => 'DCR-'.uniqid(), 'type' => $type, 'status' => $status, 'date_from' => $from, 'date_to' => $to,
            'book_opening_balance' => '0.00', 'book_closing_balance' => '0.00',
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }
}
