<?php

namespace Tests\Feature;

use App\Services\AccountingPostingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

class FinancialReportsAndPeriodsTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_accounting_periods_reject_overlap_close_idempotently_and_lock(): void
    {
        $this->seed(); $tenant = $this->tenantId(); $headers = $this->headers($tenant, 'owner', 'period-life');
        $period = (int) $this->postJson('/api/v1/finance/accounting-periods', ['name' => 'October', 'startDate' => '2030-10-01', 'endDate' => '2030-10-31'], $headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/finance/accounting-periods', ['name' => 'Overlap', 'startDate' => '2030-10-15', 'endDate' => '2030-11-15'], $headers)->assertUnprocessable()->assertJsonValidationErrors('dates');
        $this->postJson("/api/v1/finance/accounting-periods/$period/close", [], $headers)->assertOk()->assertJsonPath('data.status', 'closed');
        $this->postJson("/api/v1/finance/accounting-periods/$period/close", [], $headers)->assertOk()->assertJsonPath('data.status', 'closed');
        $this->postJson("/api/v1/finance/accounting-periods/$period/lock", [], $headers)->assertOk()->assertJsonPath('data.status', 'locked');
    }

    public function test_period_close_readiness_blocks_drafts_and_closed_dates_reject_manual_and_automatic_posting(): void
    {
        $this->seed(); $tenant = $this->tenantId(); $headers = $this->headers($tenant, 'owner', 'period-guard'); $cash = $this->accountId($tenant, '1010'); $equity = $this->accountId($tenant, '3000');
        $period = (int) $this->postJson('/api/v1/finance/accounting-periods', ['name' => 'November', 'startDate' => '2030-11-01', 'endDate' => '2030-11-30'], $headers)->assertCreated()->json('data.id');
        $draft = (int) $this->postJson('/api/v1/finance/journal-entries', ['entryDate' => '2030-11-10', 'lines' => [['accountId' => $cash, 'debit' => '10.00'], ['accountId' => $equity, 'credit' => '10.00']]], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/accounting-periods/$period/close", [], $headers)->assertUnprocessable()->assertJsonValidationErrors('readiness');
        DB::table('journal_entries')->where('id', $draft)->delete();
        $this->postJson("/api/v1/finance/accounting-periods/$period/close", [], $headers)->assertOk();
        $manual = (int) $this->postJson('/api/v1/finance/journal-entries', ['entryDate' => '2030-11-11', 'lines' => [['accountId' => $cash, 'debit' => '10.00'], ['accountId' => $equity, 'credit' => '10.00']]], $headers)->assertCreated()->json('data.id');
        $failed = $this->postJson("/api/v1/finance/journal-entries/$manual/post", [], $headers)->assertUnprocessable();
        $this->assertContains('ACCOUNTING_PERIOD_CLOSED', $failed->json('errors.accountingPeriod'));
        try { app(AccountingPostingService::class)->post(Request::create('/period-automatic', 'POST'), $tenant, ['sourceType' => 'period_test', 'sourceId' => 901, 'sourceEvent' => 'TEST', 'entryDate' => '2030-11-12', 'lines' => [['accountCode' => '1010', 'debit' => '10.00'], ['accountCode' => '3000', 'credit' => '10.00']]], (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id')); $this->fail('Expected period guard.'); } catch (ValidationException $e) { $this->assertContains('ACCOUNTING_PERIOD_CLOSED', $e->errors()['accountingPeriod']); }
    }

    public function test_ledger_reports_are_balanced_and_formal_profit_and_loss_uses_posted_lines_only(): void
    {
        $this->seed(); $tenant = $this->tenantId(); $branch = $this->branchId($tenant); $headers = $this->headers($tenant, 'owner', 'report-ledger'); $date = '2030-12-10';
        $this->journal($tenant, $branch, $date, [['1010', '100.00', '0.00'], ['4000', '0.00', '100.00']]);
        $this->journal($tenant, $branch, $date, [['4020', '10.00', '0.00'], ['1010', '0.00', '10.00']]);
        $this->journal($tenant, $branch, $date, [['5000', '30.00', '0.00'], ['1100', '0.00', '30.00']]);
        $this->journal($tenant, $branch, $date, [['6190', '20.00', '0.00'], ['1010', '0.00', '20.00']]);
        $draft = $this->makeJournal($tenant, $branch, $date, 'draft', $date.' 12:00:00');
        DB::table('journal_entry_lines')->insert([['tenant_id' => $tenant, 'journal_entry_id' => $draft, 'financial_account_id' => $this->accountId($tenant, '1010'), 'line_number' => 1, 'debit' => '999.00', 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now()], ['tenant_id' => $tenant, 'journal_entry_id' => $draft, 'financial_account_id' => $this->accountId($tenant, '4000'), 'line_number' => 2, 'debit' => '0.00', 'credit' => '999.00', 'created_at' => now(), 'updated_at' => now()]]);
        $pnl = $this->getJson("/api/v1/finance/reports/profit-loss?dateFrom=$date&dateTo=$date", $headers)->assertOk()->json('data');
        $this->assertSame('90.00', $pnl['totals']['revenue']); $this->assertSame('30.00', $pnl['totals']['costOfSales']); $this->assertSame('20.00', $pnl['totals']['operatingExpenses']); $this->assertSame('40.00', $pnl['totals']['netOperatingProfit']);
        $trial = $this->getJson("/api/v1/finance/reports/trial-balance?dateFrom=$date&dateTo=$date", $headers)->assertOk()->json('data'); $this->assertTrue($trial['totals']['balanced']); $this->assertSame('0.00', $trial['totals']['difference']);
        $sheet = $this->getJson("/api/v1/finance/reports/balance-sheet?asOfDate=$date", $headers)->assertOk()->json('data'); $this->assertTrue($sheet['integrity']['balanced']); $this->assertSame('0.00', $sheet['integrity']['difference']);
        $ledger = $this->getJson("/api/v1/finance/reports/general-ledger?dateFrom=$date&dateTo=$date&accountId=".$this->accountId($tenant, '1010'), $headers)->assertOk()->json('data'); $this->assertCount(3, $ledger['lines']); $this->assertSame(7000, \App\Support\Money::cents($ledger['closingBalance']) - \App\Support\Money::cents($ledger['openingBalance']));
    }

    public function test_cash_flow_aging_and_statement_use_ledger_and_historical_ap_scope(): void
    {
        $this->seed(); $tenant = $this->tenantId(); $branch = $this->branchId($tenant); $headers = $this->headers($tenant, 'owner', 'report-cash-ap'); $date = now()->toDateString();
        $this->journal($tenant, $branch, $date, [['1010', '50.00', '0.00'], ['4000', '0.00', '50.00']], 'pos_order', 10);
        $cash = $this->getJson("/api/v1/finance/reports/cash-flow?dateFrom=$date&dateTo=$date", $headers)->assertOk()->json('data'); $this->assertSame('50.00', $cash['netCashFlow']); $this->assertTrue($cash['integrity']['reconciled']);
        $supplier = $this->supplierId($tenant); $invoice = $this->makeSupplierInvoice($tenant, $branch, $supplier, '80.00', now()->subDays(40)->toDateString()); DB::table('supplier_invoices')->where('id', $invoice)->update(['due_date' => now()->subDays(35)->toDateString()]);
        $aging = $this->getJson('/api/v1/finance/reports/supplier-aging?asOfDate='.$date, $headers)->assertOk()->json('data'); $this->assertSame('80.00', $aging['totals']['days31To60']);
        $statement = $this->getJson("/api/v1/finance/reports/supplier-statement?supplierId=$supplier&dateFrom=".now()->subDays(50)->toDateString()."&dateTo=$date", $headers)->assertOk()->json('data'); $this->assertSame('80.00', $statement['closingBalance']);
    }

    public function test_report_account_and_supplier_inputs_are_tenant_scoped(): void
    {
        $this->seed(); $tenant = $this->tenantId(); $headers = $this->headers($tenant, 'owner', 'report-scope'); $foreign = (int) DB::table('tenants')->insertGetId(['name' => 'Foreign Report', 'slug' => 'foreign-report', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $account = (int) DB::table('financial_accounts')->insertGetId(['tenant_id' => $foreign, 'code' => 'F-100', 'name_ar' => 'F', 'name_en' => 'Foreign', 'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $supplier = (int) DB::table('suppliers')->insertGetId(['tenant_id' => $foreign, 'supplier_number' => 'F-1', 'name' => 'Foreign', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/v1/finance/reports/general-ledger?accountId='.$account, $headers)->assertUnprocessable()->assertJsonValidationErrors('accountId');
        $this->getJson('/api/v1/finance/reports/supplier-aging?supplierId='.$supplier, $headers)->assertUnprocessable()->assertJsonValidationErrors('supplierId');
    }

    private function journal(int $tenant, int $branch, string $date, array $lines, string $sourceType = 'manual', ?int $sourceId = null): int
    {
        $id = $this->makeJournal($tenant, $branch, $date, 'posted', $date.' 10:00:00', $sourceType, $sourceId);
        foreach ($lines as $index => [$code, $debit, $credit]) DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $id, 'financial_account_id' => $this->accountId($tenant, $code), 'line_number' => $index + 1, 'debit' => $debit, 'credit' => $credit, 'created_at' => now(), 'updated_at' => now()]);
        return $id;
    }
}
