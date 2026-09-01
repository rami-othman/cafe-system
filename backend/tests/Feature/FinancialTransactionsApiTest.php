<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use App\Support\FinanceAccess;
use Tests\TestCase;

class FinancialTransactionsApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_transactions_are_journal_backed_with_safe_cash_and_reversal_semantics(): void
    {
        $this->seed(); $tenant = $this->tenant(); $headers = $this->headers($tenant);
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '3000')->value('id');
        $draft = $this->postJson('/api/v1/finance/journal-entries', $this->journal($cash, $equity, 'Draft cash'), $headers)->assertCreated()->json('data.id');
        $posted = $this->postJson('/api/v1/finance/journal-entries', $this->journal($cash, $equity, 'Posted cash'), $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/journal-entries/$posted/post", [], $headers)->assertOk();
        $reversal = $this->postJson("/api/v1/finance/journal-entries/$posted/reverse", [], $headers)->assertCreated()->json('data.id');
        $drawer = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $transfer = $this->postJson('/api/v1/finance/cash-transfers', ['fromFinancialLocationId' => $drawer, 'toFinancialLocationId' => $safe, 'amount' => '25.00', 'transferDate' => '2026-09-03', 'idempotencyKey' => 'transactions-transfer'], $headers)->assertCreated()->json('data');

        $list = $this->getJson('/api/v1/finance/transactions?per_page=2', $headers)->assertOk()->assertJsonPath('meta.perPage', 2);
        $this->assertLessThanOrEqual(2, count($list->json('data')));
        $transferRow = $this->getJson('/api/v1/finance/transactions?source_type=cash_transfer', $headers)->assertOk()->assertJsonCount(1, 'data')->json('data.0');
        $this->assertSame($transfer['journalEntryId'], $transferRow['id']);
        $this->assertSame('cash_transfer', $transferRow['source']['normalizedType']);
        $this->assertSame('25.00', $transferRow['displayAmount']['amount']);
        $this->assertSame('internal_transfer', $transferRow['cashEffect']['direction']);
        $this->getJson('/api/v1/finance/transactions/summary?source_type=cash_transfer', $headers)->assertOk()->assertJsonPath('data.externalCashInflow', '0.00')->assertJsonPath('data.externalCashOutflow', '0.00');
        $this->getJson('/api/v1/finance/transactions/summary?status=draft', $headers)->assertOk()->assertJsonPath('data.draftJournalCount', 1);
        $this->getJson("/api/v1/finance/transactions/$draft", $headers)->assertOk()->assertJsonPath('data.journal.status', 'draft');
        $this->getJson("/api/v1/finance/transactions/$posted", $headers)->assertOk()->assertJsonPath('data.reversal.state', 'original_reversed')->assertJsonPath('data.journal.totalDebit', '100.00')->assertJsonPath('data.journal.lines.0.accountCode', '1010');
        $this->getJson("/api/v1/finance/transactions/$reversal", $headers)->assertOk()->assertJsonPath('data.reversal.state', 'reversal_entry')->assertJsonPath('data.reversal.originalJournalId', $posted);
        $this->getJson('/api/v1/finance/transactions?account_code=1010&search=JE-', $headers)->assertOk()->assertJsonPath('data.0.journal.balanced', true);
    }

    public function test_transaction_detail_is_tenant_and_branch_scoped_while_company_wide_entries_remain_visible(): void
    {
        $this->seed(); $tenant = $this->tenant(); $owner = $this->headers($tenant);
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id');
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id'); $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '3000')->value('id');
        $branchEntry = $this->postJson('/api/v1/finance/journal-entries', $this->journal($cash, $equity, 'Branch', $branch), $owner)->assertCreated()->json('data.id'); $this->postJson("/api/v1/finance/journal-entries/$branchEntry/post", [], $owner)->assertOk();
        $manager = $this->singleBranchManagerHeaders($tenant, $branch);
        $this->getJson('/api/v1/finance/transactions', $manager)->assertOk()->assertJsonFragment(['id' => $branchEntry]);
        $otherBranch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Airport')->value('id');
        $other = $this->postJson('/api/v1/finance/journal-entries', $this->journal($cash, $equity, 'Other', $otherBranch), $owner)->assertCreated()->json('data.id'); $this->postJson("/api/v1/finance/journal-entries/$other/post", [], $owner)->assertOk();
        $this->getJson("/api/v1/finance/transactions/$other", $manager)->assertNotFound();
        $foreign = DB::table('tenants')->insertGetId(['name' => 'Foreign', 'slug' => 'financial-transactions-foreign', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]); app(FinancialSetupService::class)->ensureForTenant($foreign);
        $this->getJson("/api/v1/finance/transactions/$branchEntry", $this->headers((int) $foreign))->assertNotFound();
    }

    private function tenant(): int { return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id'); }
    private function headers(int $tenant, string $role = 'owner'): array { $user = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', $role)->value('id'); if (! $user) $user = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Transactions Owner', 'email' => "transactions-owner-$tenant@example.test", 'password' => bcrypt('password'), 'role' => $role, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); $token = "transactions-$tenant-$role"; DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenant, 'user_id' => $user, 'name' => "transactions-$role"], ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]); return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenant]; }
    private function singleBranchManagerHeaders(int $tenant, int $branch): array { $user = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Single Branch Manager', 'email' => "transactions-manager-$tenant@example.test", 'password' => bcrypt('password'), 'role' => 'manager', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); foreach(FinanceAccess::defaultPermissionsForRole('manager') as $permission)DB::table('finance_role_permissions')->updateOrInsert(['tenant_id'=>$tenant,'role'=>'manager','permission'=>$permission],['created_at'=>now(),'updated_at'=>now()]); DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $user, 'branch_id' => $branch, 'created_at' => now(), 'updated_at' => now()]); $token = "transactions-manager-$tenant"; DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'transactions-single-manager', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]); return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenant]; }
    private function journal(int $debit, int $credit, string $description, ?int $branchId = null): array { return ['entryDate' => '2026-09-03', 'sourceType' => 'manual', 'description' => $description, 'branchId' => $branchId, 'lines' => [['accountId' => $debit, 'debit' => '100.00', 'credit' => '0.00'], ['accountId' => $credit, 'debit' => '0.00', 'credit' => '100.00']]]; }
}
