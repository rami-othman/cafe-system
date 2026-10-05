<?php

namespace Tests\Feature;

use App\Services\AccountingPostingService;
use App\Services\FinancialIntegrityService;
use App\Services\FinancialSetupService;
use App\Services\PhinixRemapService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FinancialIntegrityServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_clean_tenant_with_a_real_posting_passes_the_read_only_integrity_check(): void
    {
        [$tenant, $owner] = $this->tenant();
        app(AccountingPostingService::class)->postSale(Request::create('/integrity', 'POST'), $tenant, [
            'sourceId' => 901,
            'sourceEvent' => 'POS_ORDER_PAID',
            'entryDate' => '2026-09-01',
            'lines' => [['accountCode' => '1010', 'debit' => '125.00'], ['accountCode' => '4000', 'credit' => '125.00']],
        ], $owner);

        $result = app(FinancialIntegrityService::class)->inspect($tenant);

        $this->assertSame('PASS', $result['status']);
        $this->assertSame(0, $result['summary']['critical']);
        $this->assertSame(0, $this->check($result, 'TRIAL_BALANCE_IMBALANCE')['count']);
        $this->assertSame(0, $this->check($result, 'BALANCE_SHEET_IMBALANCE')['count']);
    }

    public function test_it_detects_an_isolated_unbalanced_posted_journal_without_repairing_it(): void
    {
        [$tenant, $owner] = $this->tenant();
        $entry = app(AccountingPostingService::class)->postSale(Request::create('/integrity', 'POST'), $tenant, [
            'sourceId' => 902,
            'sourceEvent' => 'POS_ORDER_PAID',
            'entryDate' => '2026-09-01',
            'lines' => [['accountCode' => '1010', 'debit' => '100.00'], ['accountCode' => '4000', 'credit' => '100.00']],
        ], $owner);
        DB::table('journal_entry_lines')->where('journal_entry_id', $entry)->where('credit', '100.00')->update(['credit' => '99.00']);

        $result = app(FinancialIntegrityService::class)->inspect($tenant);

        $this->assertSame('FAIL', $result['status']);
        $this->assertSame(1, $this->check($result, 'UNBALANCED_POSTED_JOURNAL')['count']);
        $this->assertSame(1, $this->check($result, 'TRIAL_BALANCE_IMBALANCE')['count']);
    }

    public function test_it_detects_a_paid_expense_missing_its_posting(): void
    {
        [$tenant, $owner] = $this->tenant();
        $category = DB::table('expense_categories')->insertGetId([
            'tenant_id' => $tenant, 'code' => 'UTIL', 'name' => 'Utilities',
            'financial_account_id' => DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6120')->value('id'),
            'is_active' => true, 'created_by' => $owner, 'updated_by' => $owner, 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('expenses')->insert([
            'tenant_id' => $tenant, 'expense_number' => 'EXP-INTEGRITY-1', 'expense_category_id' => $category,
            'amount' => '20.00', 'tax_amount' => '0.00', 'total_amount' => '20.00', 'expense_date' => '2026-09-01',
            'description' => 'Deliberately unposted test expense', 'status' => 'paid', 'payment_status' => 'paid',
            'created_by' => $owner, 'created_at' => now(), 'updated_at' => now(),
        ]);

        $result = app(FinancialIntegrityService::class)->inspect($tenant);

        $this->assertSame('FAIL', $result['status']);
        $this->assertSame(1, $this->check($result, 'PAID_EXPENSE_MISSING_JOURNAL')['count']);
    }

    private function tenant(): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Integrity Cafe', 'slug' => 'integrity-cafe', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $owner = DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Integrity Owner', 'email' => 'integrity@example.test', 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, null, $owner);

        return [(int) $tenant, (int) $owner];
    }

    public function test_phinix_readiness_uses_active_new_accounts_and_payables_checks_the_new_control(): void
    {
        [$tenant, $owner] = $this->tenant();
        foreach (PhinixRemapService::LEGACY_TO_NEW as $oldCode => $newCode) {
            $old = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $oldCode)->first();
            $newId = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $newCode)->value('id');
            $newId ??= DB::table('financial_accounts')->insertGetId([
                'tenant_id' => $tenant, 'code' => $newCode, 'name_ar' => $newCode, 'name_en' => $newCode,
                'account_group' => $old->account_group, 'normal_balance' => $old->normal_balance, 'catalog_source' => 'phinix',
            ]);
            foreach (['financial_locations', 'payment_methods', 'sales_account_mappings'] as $table) {
                DB::table($table)->where('tenant_id', $tenant)->where('financial_account_id', $old->id)->update(['financial_account_id' => $newId]);
            }
            DB::table('financial_accounts')->where('id', $old->id)->update(['is_active' => false]);
        }
        $clean = app(FinancialIntegrityService::class)->inspect($tenant);
        $this->assertSame('PASS', $clean['status']);
        $this->assertNotContains('2000', app(FinancialSetupService::class)->requiredAccountCodes($tenant));
        $this->assertContains('223', app(FinancialSetupService::class)->requiredAccountCodes($tenant));
        app(AccountingPostingService::class)->post(Request::create('/integrity'), $tenant, [
            'sourceType' => 'manual', 'sourceId' => 999, 'sourceEvent' => 'TEST_AP', 'entryDate' => '2026-09-01',
            'lines' => [['accountCode' => '131', 'debit' => '100.00'], ['accountCode' => '223', 'credit' => '100.00']],
        ], $owner);
        $result = app(FinancialIntegrityService::class)->inspect($tenant);
        $this->assertSame(1, $this->check($result, 'ACCOUNTS_PAYABLE_RECONCILIATION_MISMATCH')['count']);
        $this->assertSame(['-100.00'], $this->check($result, 'ACCOUNTS_PAYABLE_RECONCILIATION_MISMATCH')['references']);

    }

    private function check(array $result, string $code): array
    {
        return collect($result['checks'])->firstWhere('code', $code);
    }
}
