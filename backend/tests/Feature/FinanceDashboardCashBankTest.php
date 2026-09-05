<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/** Phase 10 test area #34-38 — Cash & Banks from the posted ledger. */
class FinanceDashboardCashBankTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_cash_and_bank_balances_come_from_posted_ledger_activity(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cb-basic');
        $date = '2030-06-01';

        $this->postJournal($tenant, '1010', '1020', '500.00', $date); // Debit Cash Drawer, Credit Main Safe (both cash)
        $this->postJournal($tenant, '1030', '3000', '300.00', $date); // Debit Bank, Credit Equity

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date", $headers)->assertOk()->json('data');
        // The tenant's seeded opening-balance journal already carries a 12,500.00 cash baseline
        // (Cash Drawer 2,500 + Main Safe 10,000); Cash Drawer +500, Main Safe -500 -> net cash movement 0.
        $this->assertSame('12500.00', $data['kpis']['cashBanks']['cash']);
        $this->assertSame('300.00', $data['kpis']['cashBanks']['banks']);
        $this->assertSame('12800.00', $data['kpis']['cashBanks']['total']);
    }

    public function test_draft_journal_is_excluded_from_cash_and_bank_balance(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cb-draft');
        $date = '2030-06-02';

        $this->postJournal($tenant, '1010', '3000', '1000.00', $date, 'draft');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date", $headers)->assertOk()->json('data');
        $this->assertSame('12500.00', $data['kpis']['cashBanks']['cash']);
    }

    public function test_as_of_date_reflects_only_activity_up_to_that_date(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cb-asof');

        $this->postJournal($tenant, '1010', '3000', '200.00', '2030-06-05');
        $this->postJournal($tenant, '1010', '3000', '300.00', '2030-06-10');

        $upToFirst = $this->getJson('/api/v1/finance/dashboard?date_from=2030-06-01&date_to=2030-06-05', $headers)->assertOk()->json('data');
        $upToSecond = $this->getJson('/api/v1/finance/dashboard?date_from=2030-06-01&date_to=2030-06-10', $headers)->assertOk()->json('data');
        $this->assertSame('2030-06-05', $upToFirst['kpis']['cashBanks']['asOfDate']);
        $this->assertSame('12700.00', $upToFirst['kpis']['cashBanks']['cash']);
        $this->assertSame('13000.00', $upToSecond['kpis']['cashBanks']['cash']);
    }

    public function test_internal_cash_transfer_moves_accounts_without_becoming_revenue(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cb-transfer');
        $date = '2030-06-12';

        // A transfer between two cash accounts: total cash balance unaffected, and never counted as sales.
        $this->postJournal($tenant, '1020', '1010', '150.00', $date);

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date", $headers)->assertOk()->json('data');
        $this->assertSame('12500.00', $data['kpis']['cashBanks']['cash']);
        $this->assertSame('0.00', $data['kpis']['netSales']['current']);
    }

    private function postJournal(int $tenant, string $debitCode, string $creditCode, string $amount, string $date, string $status = 'posted'): int
    {
        $debit = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $debitCode)->value('id');
        $credit = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $creditCode)->value('id');
        $journalId = (int) DB::table('journal_entries')->insertGetId(['tenant_id' => $tenant, 'branch_id' => null, 'entry_number' => 'CBJ-'.uniqid(), 'entry_date' => $date, 'source_type' => 'manual', 'status' => $status, 'posted_at' => $status === 'posted' ? now() : null, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $debit, 'line_number' => 1, 'debit' => $amount, 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $credit, 'line_number' => 2, 'debit' => '0.00', 'credit' => $amount, 'created_at' => now(), 'updated_at' => now()]);

        return $journalId;
    }
}
