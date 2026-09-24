<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * B1 — Payment/Receipt voucher posting direction, balance, financial
 * location tagging, draft-vs-post idempotency, and branch authorization.
 *
 * Confirmed contract (unchanged by this task, only verified here):
 *   PAYMENT VOUCHER: Dr accounting distribution / Cr selected cash-bank source
 *   RECEIPT VOUCHER : Dr selected cash-bank source / Cr accounting distribution
 */
final class FinanceVoucherApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_payment_voucher_starts_with_no_default_distribution_account_and_posts_debit_distribution_credit_cash(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch, '1010');
        $expenseAccountId = $this->accountId($tenant, '6100');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];

        $created = $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'payment',
            'documentDate' => now()->toDateString(),
            'branchId' => $branch,
            'financialLocationId' => $cashLocation,
            'amount' => '150.00',
            'description' => 'Test payment voucher',
            'idempotencyKey' => 'pv-basic-1',
            'lines' => [
                ['accountId' => $expenseAccountId, 'amount' => '150.00'],
            ],
        ], $headers)->assertCreated();
        $documentId = (int) $created->json('data.id');
        $this->assertSame('draft', $created->json('data.status'));
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->count());

        $posted = $this->postJson("/api/v1/finance/vouchers/{$documentId}/post", [], $headers)->assertOk();
        $journalId = (int) $posted->json('data.journalEntryId');
        $this->assertSame('posted', $posted->json('data.status'));

        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journalId)->orderBy('line_number')->get();
        $this->assertCount(2, $lines);
        $debitLine = $lines->firstWhere('financial_account_id', $expenseAccountId);
        $creditLine = $lines->firstWhere('financial_account_id', $this->accountId($tenant, '1010'));
        $this->assertNotNull($debitLine, 'The distribution account must carry the debit leg.');
        $this->assertNotNull($creditLine, 'The selected cash source must carry the credit leg.');
        $this->assertSame('150.00', $debitLine->debit);
        $this->assertSame('0.00', $debitLine->credit);
        $this->assertSame('150.00', $creditLine->credit);
        $this->assertSame('0.00', $creditLine->debit);
        $this->assertSame($cashLocation, (int) $creditLine->financial_location_id);
        $this->assertNull($debitLine->financial_location_id);
        $totalDebit = (float) $lines->sum('debit');
        $totalCredit = (float) $lines->sum('credit');
        $this->assertSame($totalDebit, $totalCredit);
    }

    /** C3: an explicit, historical (still-open-period) document date must
     * survive the draft and drive the posted journal entry's date — never
     * silently replaced by the save/post moment. */
    public function test_voucher_keeps_the_selected_historical_document_date_through_draft_and_post(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch, '1010');
        $expenseAccountId = $this->accountId($tenant, '6100');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $historicalDate = now()->subDays(5)->toDateString();
        $this->assertNotSame(now()->toDateString(), $historicalDate);

        $created = $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'payment',
            'documentDate' => $historicalDate,
            'branchId' => $branch,
            'financialLocationId' => $cashLocation,
            'amount' => '75.00',
            'idempotencyKey' => 'pv-historical-1',
            'lines' => [['accountId' => $expenseAccountId, 'amount' => '75.00']],
        ], $headers)->assertCreated();
        $documentId = (int) $created->json('data.id');
        $this->assertSame($historicalDate, DB::table('finance_documents')->where('id', $documentId)->value('document_date'));

        $posted = $this->postJson("/api/v1/finance/vouchers/{$documentId}/post", [], $headers)->assertOk();
        $journalId = (int) $posted->json('data.journalEntryId');
        $this->assertSame($historicalDate, substr((string) DB::table('journal_entries')->where('id', $journalId)->value('entry_date'), 0, 10));
    }

    public function test_receipt_voucher_posts_cash_debit_and_distribution_credit(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch, '1010');
        $revenueAccountId = $this->accountId($tenant, '4030');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];

        $documentId = (int) $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'receipt',
            'documentDate' => now()->toDateString(),
            'branchId' => $branch,
            'financialLocationId' => $cashLocation,
            'amount' => '80.00',
            'idempotencyKey' => 'rv-basic-1',
            'lines' => [
                ['accountId' => $revenueAccountId, 'amount' => '80.00'],
            ],
        ], $headers)->assertCreated()->json('data.id');

        $posted = $this->postJson("/api/v1/finance/vouchers/{$documentId}/post", [], $headers)->assertOk();
        $journalId = (int) $posted->json('data.journalEntryId');
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journalId)->get();
        $debitLine = $lines->firstWhere('financial_account_id', $this->accountId($tenant, '1010'));
        $creditLine = $lines->firstWhere('financial_account_id', $revenueAccountId);
        $this->assertSame('80.00', $debitLine->debit);
        $this->assertSame('0.00', $debitLine->credit);
        $this->assertSame($cashLocation, (int) $debitLine->financial_location_id);
        $this->assertSame('80.00', $creditLine->credit);
        $this->assertSame('0.00', $creditLine->debit);
    }

    public function test_multi_line_distribution_must_exactly_match_total_and_posts_with_correct_totals(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch, '1010');
        $rent = $this->accountId($tenant, '6100');
        $salaries = $this->accountId($tenant, '6110');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];

        $documentId = (int) $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'payment', 'documentDate' => now()->toDateString(), 'branchId' => $branch,
            'financialLocationId' => $cashLocation, 'amount' => '300.00', 'idempotencyKey' => 'pv-multi-1',
            'lines' => [
                ['accountId' => $rent, 'amount' => '200.00'],
                ['accountId' => $salaries, 'amount' => '100.00'],
            ],
        ], $headers)->assertCreated()->json('data.id');

        $posted = $this->postJson("/api/v1/finance/vouchers/{$documentId}/post", [], $headers)->assertOk();
        $journalId = (int) $posted->json('data.journalEntryId');
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journalId)->get();
        $this->assertCount(3, $lines);
        $this->assertSame('300.00', number_format((float) $lines->sum('debit'), 2, '.', ''));
        $this->assertSame('300.00', number_format((float) $lines->sum('credit'), 2, '.', ''));
    }

    public function test_distribution_total_mismatch_is_rejected_with_no_partial_journal_or_document(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch, '1010');
        $expenseAccountId = $this->accountId($tenant, '6100');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];

        $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'payment', 'documentDate' => now()->toDateString(), 'branchId' => $branch,
            'financialLocationId' => $cashLocation, 'amount' => '150.00', 'idempotencyKey' => 'pv-mismatch-1',
            'lines' => [['accountId' => $expenseAccountId, 'amount' => '100.00']],
        ], $headers)->assertStatus(422);

        $this->assertSame(0, DB::table('finance_documents')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->count());
    }

    public function test_no_distribution_account_is_rejected(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch, '1010');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];

        $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'payment', 'documentDate' => now()->toDateString(), 'branchId' => $branch,
            'financialLocationId' => $cashLocation, 'amount' => '150.00', 'idempotencyKey' => 'pv-no-lines-1',
            'lines' => [],
        ], $headers)->assertStatus(422);
    }

    public function test_save_draft_creates_no_journal_entry_and_save_and_post_creates_exactly_one(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch, '1010');
        $expenseAccountId = $this->accountId($tenant, '6100');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];

        $documentId = (int) $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'payment', 'documentDate' => now()->toDateString(), 'branchId' => $branch,
            'financialLocationId' => $cashLocation, 'amount' => '50.00', 'idempotencyKey' => 'pv-draft-1',
            'lines' => [['accountId' => $expenseAccountId, 'amount' => '50.00']],
        ], $headers)->assertCreated()->json('data.id');
        $this->assertSame('draft', DB::table('finance_documents')->find($documentId)->status);
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->count());

        $this->postJson("/api/v1/finance/vouchers/{$documentId}/post", [], $headers)->assertOk();
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->count());

        // Posting an already-posted voucher must not duplicate the journal.
        $this->postJson("/api/v1/finance/vouchers/{$documentId}/post", [], $headers)->assertStatus(422);
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->count());
    }

    public function test_posting_with_idempotency_key_replay_does_not_duplicate_document(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch, '1010');
        $expenseAccountId = $this->accountId($tenant, '6100');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $payload = [
            'documentType' => 'payment', 'documentDate' => now()->toDateString(), 'branchId' => $branch,
            'financialLocationId' => $cashLocation, 'amount' => '75.00', 'idempotencyKey' => 'pv-replay-1',
            'lines' => [['accountId' => $expenseAccountId, 'amount' => '75.00']],
        ];
        $first = (int) $this->postJson('/api/v1/finance/vouchers', $payload, $headers)->assertCreated()->json('data.id');
        $second = (int) $this->postJson('/api/v1/finance/vouchers', $payload, $headers)->assertCreated()->json('data.id');
        $this->assertSame($first, $second);
        $this->assertSame(1, DB::table('finance_documents')->where('tenant_id', $tenant)->where('idempotency_key', 'pv-replay-1')->count());
    }

    public function test_voucher_for_a_branch_the_actor_cannot_access_is_rejected(): void
    {
        [$tenant, $branchA, $branchB] = $this->tenantWithBranch(true);
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocationB = $this->cashLocation($tenant, $branchB, '1010');
        $expenseAccountId = $this->accountId($tenant, '6100');
        $manager = User::query()->create([
            'tenant_id' => $tenant, 'name' => 'Manager A', 'email' => 'manager-a@example.test',
            'password' => 'password', 'role' => 'manager', 'is_active' => true,
        ]);
        DB::table('user_branches')->insert([
            'tenant_id' => $tenant, 'user_id' => $manager->id, 'branch_id' => $branchA,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $token = $this->authenticateTenantUser($tenant, $manager);
        $headers = ['Authorization' => 'Bearer '.$token];

        $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'payment', 'documentDate' => now()->toDateString(), 'branchId' => $branchB,
            'financialLocationId' => $cashLocationB, 'amount' => '10.00', 'idempotencyKey' => 'pv-unauthorized-1',
            'lines' => [['accountId' => $expenseAccountId, 'amount' => '10.00']],
        ], $headers)->assertStatus(403);
        $this->assertSame(0, DB::table('finance_documents')->where('tenant_id', $tenant)->count());
    }

    /** @return array{0:int,1:int,2?:int} */
    private function tenantWithBranch(bool $withSecondBranch = false): array
    {
        $tenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Voucher Test', 'slug' => 'voucher-test-'.uniqid(), 'status' => 'active',
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $branchA = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'Branch A', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        if (! $withSecondBranch) {
            return [$tenant, $branchA];
        }
        $branchB = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'Branch B', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return [$tenant, $branchA, $branchB];
    }

    private function accountId(int $tenant, string $code): int
    {
        return (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $code)->value('id');
    }

    private function cashLocation(int $tenant, int $branch, string $accountCode): int
    {
        return (int) DB::table('financial_locations')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'financial_account_id' => $this->accountId($tenant, $accountCode),
            'code' => 'TEST-CASH-'.$branch.'-'.$accountCode, 'name' => 'Test Cash Location',
            'kind' => 'cash', 'type' => 'main_safe', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }
}
