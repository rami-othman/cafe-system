<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use App\Support\FinanceAccess;
use Tests\TestCase;

class FinancialReconciliationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_cash_reconciliation_snapshots_posted_book_balance_and_completes_without_journal_mutation(): void
    {
        $this->seed(); $tenant = $this->tenant(); $headers = $this->headers($tenant);
        $cash = $this->account($tenant, '1010'); $equity = $this->account($tenant, '3000');
        $draft = $this->draft($headers, $cash, $equity, 'Draft must not affect reconciliation');
        $posted = $this->posted($headers, $cash, $equity, 'Posted cash receipt', '100.00');
        $drawer = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');

        $journalCountBeforeReconciliation = DB::table('journal_entries')->where('tenant_id', $tenant)->count();
        $created = $this->postJson('/api/v1/finance/reconciliations', ['type' => 'cash', 'financialLocationId' => $drawer, 'dateFrom' => '2026-09-03', 'dateTo' => '2026-09-03'], $headers)->assertCreated()->json('data');
        $this->assertSame('2600.00', $created['balances']['bookClosing']);
        $this->assertSame('2500.00', $created['balances']['bookOpening']);
        $this->assertFalse($created['canComplete']);
        $this->assertSame('draft', DB::table('journal_entries')->where('id', $draft)->value('status'));

        $completed = $this->patchJson("/api/v1/finance/reconciliations/{$created['id']}", ['actualCashCount' => '2600.00'], $headers)->assertOk()->json('data');
        $this->assertTrue($completed['canComplete']);
        $this->postJson("/api/v1/finance/reconciliations/{$created['id']}/complete", [], $headers)->assertOk()->assertJsonPath('data.status', 'completed');
        $this->assertSame('posted', DB::table('journal_entries')->where('id', $posted)->value('status'));
        $this->assertSame($journalCountBeforeReconciliation, DB::table('journal_entries')->where('tenant_id', $tenant)->count());
        $this->patchJson("/api/v1/finance/reconciliations/{$created['id']}", ['actualCashCount' => '99.00'], $headers)->assertUnprocessable();
        $short = $this->postJson('/api/v1/finance/reconciliations', ['type' => 'cash', 'financialLocationId' => $drawer, 'dateFrom' => '2026-09-04', 'dateTo' => '2026-09-04', 'actualCashCount' => '2599.99'], $headers)->assertCreated()->json('data');
        $this->assertSame('-0.01', $short['balances']['difference']);
        $this->assertSame('short', $short['balances']['differenceDirection']);
        $this->postJson("/api/v1/finance/reconciliations/{$short['id']}/complete", [], $headers)->assertUnprocessable();
    }

    public function test_bank_reconciliation_supports_many_to_one_and_one_to_many_partial_matches_and_strict_completion(): void
    {
        $this->seed(); $tenant = $this->tenant(); $headers = $this->headers($tenant);
        $bank = $this->account($tenant, '1030'); $equity = $this->account($tenant, '3000');
        $first = $this->posted($headers, $bank, $equity, 'Bank receipt one', '60.00');
        $second = $this->posted($headers, $bank, $equity, 'Bank receipt two', '40.00');
        $bankLocation = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $session = $this->postJson('/api/v1/finance/reconciliations', ['type' => 'bank', 'financialLocationId' => $bankLocation, 'dateFrom' => '2026-09-03', 'dateTo' => '2026-09-03', 'externalClosingBalance' => '100.00'], $headers)->assertCreated()->json('data');
        $line = $this->postJson("/api/v1/finance/reconciliations/{$session['id']}/statement-lines", ['transactionDate' => '2026-09-03', 'description' => 'Bank deposit', 'amount' => '100.00', 'direction' => 'inflow', 'externalIdentifier' => 'bank-100'], $headers)->assertCreated()->json('data');
        $this->postJson("/api/v1/finance/reconciliations/{$session['id']}/matches", ['statementLineId' => $line['id'], 'journalEntryId' => $first, 'amount' => '60.00', 'idempotencyKey' => 'bank-match-1'], $headers)->assertCreated();
        $this->postJson("/api/v1/finance/reconciliations/{$session['id']}/matches", ['statementLineId' => $line['id'], 'journalEntryId' => $second, 'amount' => '40.00', 'idempotencyKey' => 'bank-match-2'], $headers)->assertCreated();
        $this->postJson("/api/v1/finance/reconciliations/{$session['id']}/matches", ['statementLineId' => $line['id'], 'journalEntryId' => $second, 'amount' => '40.00', 'idempotencyKey' => 'bank-match-2'], $headers)->assertCreated();
        $detail = $this->getJson("/api/v1/finance/reconciliations/{$session['id']}", $headers)->assertOk()->json('data');
        $this->assertSame('0.00', $detail['statementLines'][0]['remainingAmount']);
        $this->assertSame(2, $detail['summary']['matchedCount']);
        $this->postJson("/api/v1/finance/reconciliations/{$session['id']}/complete", [], $headers)->assertOk()->assertJsonPath('data.status', 'completed');

        $next = $this->postJson('/api/v1/finance/reconciliations', ['type' => 'bank', 'financialLocationId' => $bankLocation, 'dateFrom' => '2026-09-04', 'dateTo' => '2026-09-04', 'externalClosingBalance' => '100.00'], $headers)->assertCreated()->json('data');
        $outflow = $this->posted($headers, $equity, $bank, 'Bank withdrawal', '60.00', '2026-09-04');
        $a = $this->postJson("/api/v1/finance/reconciliations/{$next['id']}/statement-lines", ['transactionDate' => '2026-09-04', 'description' => 'Withdrawal part A', 'amount' => '25.00', 'direction' => 'outflow', 'externalIdentifier' => 'bank-withdrawal-a'], $headers)->assertCreated()->json('data.id');
        $b = $this->postJson("/api/v1/finance/reconciliations/{$next['id']}/statement-lines", ['transactionDate' => '2026-09-04', 'description' => 'Withdrawal part B', 'amount' => '35.00', 'direction' => 'outflow', 'externalIdentifier' => 'bank-withdrawal-b'], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/reconciliations/{$next['id']}/matches", ['statementLineId' => $a, 'journalEntryId' => $outflow, 'amount' => '25.00'], $headers)->assertCreated();
        $this->postJson("/api/v1/finance/reconciliations/{$next['id']}/matches", ['statementLineId' => $b, 'journalEntryId' => $outflow, 'amount' => '35.00'], $headers)->assertCreated();
        $this->getJson("/api/v1/finance/reconciliations/{$next['id']}/system-transactions", $headers)->assertOk()->assertJsonPath('data.0.matchedAmount', '60.00');
    }

    public function test_reconciliation_rejects_invalid_matches_and_cross_tenant_access(): void
    {
        $this->seed(); $tenant = $this->tenant(); $headers = $this->headers($tenant); $bank = $this->account($tenant, '1030'); $equity = $this->account($tenant, '3000');
        $entry = $this->posted($headers, $bank, $equity, 'Bank receipt', '10.00');
        $bankLocation = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $session = $this->postJson('/api/v1/finance/reconciliations', ['type' => 'bank', 'financialLocationId' => $bankLocation, 'dateFrom' => '2026-09-03', 'dateTo' => '2026-09-03', 'externalClosingBalance' => '10.00'], $headers)->assertCreated()->json('data');
        $line = $this->postJson("/api/v1/finance/reconciliations/{$session['id']}/statement-lines", ['transactionDate' => '2026-09-03', 'description' => 'Wrong direction', 'amount' => '10.00', 'direction' => 'outflow'], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/reconciliations/{$session['id']}/matches", ['statementLineId' => $line, 'journalEntryId' => $entry, 'amount' => '10.00'], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/finance/reconciliations/{$session['id']}/complete", [], $headers)->assertUnprocessable();

        $foreign = (int) DB::table('tenants')->insertGetId(['name' => 'Foreign', 'slug' => 'reconciliation-foreign', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]); app(FinancialSetupService::class)->ensureForTenant($foreign);
        $this->getJson("/api/v1/finance/reconciliations/{$session['id']}", $this->headers($foreign))->assertNotFound();
    }

    public function test_card_reconciliation_uses_the_configured_payment_method_settlement_account(): void
    {
        $this->seed(); $tenant = $this->tenant(); $headers = $this->headers($tenant); $bank = $this->account($tenant, '1030');
        $bankLocation = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $method = (int) DB::table('payment_methods')->insertGetId(['tenant_id' => $tenant, 'code' => 'VISA-TEST', 'name' => 'Visa Test', 'type' => 'card', 'financial_account_id' => $bank, 'financial_location_id' => $bankLocation, 'is_active' => true, 'sort_order' => 10, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson('/api/v1/finance/reconciliations', ['type' => 'card', 'paymentMethodId' => $method, 'dateFrom' => '2026-09-03', 'dateTo' => '2026-09-03', 'externalClosingBalance' => '0.00'], $headers)->assertCreated()->assertJsonPath('data.type', 'card')->assertJsonPath('data.account.financialAccountId', $bank);
    }

    public function test_branch_scope_matches_direct_access_and_keeps_company_wide_bank_visible(): void
    {
        $this->seed(); $tenant = $this->tenant(); $owner = $this->headers($tenant);
        $downtown = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id'); $airport = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Airport')->value('id');
        $account = (int) DB::table('financial_accounts')->insertGetId(['tenant_id' => $tenant, 'code' => '1099', 'name_ar' => 'Branch Petty Cash', 'name_en' => 'Branch Petty Cash', 'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true, 'is_system_protected' => false, 'created_at' => now(), 'updated_at' => now()]);
        $location = (int) DB::table('financial_locations')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $downtown, 'financial_account_id' => $account, 'code' => 'DOWNTOWN-PETTY', 'name' => 'Downtown Petty Cash', 'kind' => 'cash', 'type' => 'petty_cash', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $branchSession = $this->postJson('/api/v1/finance/reconciliations', ['type' => 'cash', 'financialLocationId' => $location, 'dateFrom' => '2026-09-03', 'dateTo' => '2026-09-03'], $owner)->assertCreated()->json('data.id');
        $bankLocation = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $companySession = $this->postJson('/api/v1/finance/reconciliations', ['type' => 'bank', 'financialLocationId' => $bankLocation, 'dateFrom' => '2026-09-03', 'dateTo' => '2026-09-03'], $owner)->assertCreated()->json('data.id');
        $this->getJson("/api/v1/finance/reconciliations/$branchSession", $this->managerHeaders($tenant, $downtown))->assertOk();
        $this->getJson("/api/v1/finance/reconciliations/$branchSession", $this->managerHeaders($tenant, $airport))->assertNotFound();
        $this->getJson("/api/v1/finance/reconciliations/$companySession", $this->managerHeaders($tenant, $airport))->assertOk();
    }

    private function tenant(): int { return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id'); }
    private function account(int $tenant, string $code): int { return (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $code)->value('id'); }
    private function headers(int $tenant): array { $user = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id'); if (! $user) $user = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Reconciliation Owner', 'email' => "reconciliation-owner-$tenant@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); $token = "reconciliation-$tenant"; DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'reconciliation'], ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]); return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenant]; }
    private function managerHeaders(int $tenant, int $branch): array { $email = "reconciliation-manager-$tenant-$branch@example.test"; $user = (int) DB::table('users')->where('tenant_id', $tenant)->where('email', $email)->value('id'); if (! $user) $user = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => "Reconciliation Manager $branch", 'email' => $email, 'password' => bcrypt('password'), 'role' => 'manager', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); foreach(FinanceAccess::defaultPermissionsForRole('manager') as $permission)DB::table('finance_role_permissions')->updateOrInsert(['tenant_id'=>$tenant,'role'=>'manager','permission'=>$permission],['created_at'=>now(),'updated_at'=>now()]); DB::table('user_branches')->updateOrInsert(['tenant_id' => $tenant, 'user_id' => $user, 'branch_id' => $branch], ['created_at' => now(), 'updated_at' => now()]); $token = "reconciliation-manager-$tenant-$branch"; DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenant, 'user_id' => $user, 'name' => "reconciliation-manager-$branch"], ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]); return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenant]; }
    private function draft(array $headers, int $debit, int $credit, string $description, string $amount = '100.00', string $date = '2026-09-03'): int { return (int) $this->postJson('/api/v1/finance/journal-entries', $this->journal($debit, $credit, $description, $amount, $date), $headers)->assertCreated()->json('data.id'); }
    private function posted(array $headers, int $debit, int $credit, string $description, string $amount, string $date = '2026-09-03'): int { $id = $this->draft($headers, $debit, $credit, $description, $amount, $date); $this->postJson("/api/v1/finance/journal-entries/$id/post", [], $headers)->assertOk(); return $id; }
    private function journal(int $debit, int $credit, string $description, string $amount, string $date): array { return ['entryDate' => $date, 'sourceType' => 'manual', 'description' => $description, 'lines' => [['accountId' => $debit, 'debit' => $amount, 'credit' => '0.00'], ['accountId' => $credit, 'debit' => '0.00', 'credit' => $amount]]]; }
}
