<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Database\Seeders\FinancialInventoryFoundationSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FinancialInventoryFoundationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_tenants_cannot_access_each_others_warehouses_accounts_or_journal_entries(): void
    {
        $this->seed();
        $tenantA = $this->demoTenantId();
        $tenantB = $this->createTenant('other-finance-tenant');
        app(FinancialSetupService::class)->ensureForTenant($tenantB);

        $warehouse = $this->postJson('/api/v1/warehouses', $this->warehousePayload(), $this->headers($tenantA))->assertCreated();
        $accountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenantA)->where('code', '1010')->value('id');
        $equityId = (int) DB::table('financial_accounts')->where('tenant_id', $tenantA)->where('code', '3000')->value('id');
        $entry = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($accountId, $equityId), $this->headers($tenantA))->assertCreated();

        $this->getJson('/api/v1/warehouses', $this->headers($tenantB))->assertOk()->assertJsonCount(1, 'data');
        $this->patchJson('/api/v1/warehouses/'.$warehouse->json('data.id'), $this->warehousePayload(), $this->headers($tenantB))->assertNotFound();
        $this->getJson('/api/v1/finance/accounts', $this->headers($tenantB))->assertOk()->assertJsonMissing(['id' => $accountId]);
        $this->getJson('/api/v1/finance/journal-entries/'.$entry->json('data.id'), $this->headers($tenantB))->assertNotFound();
    }

    public function test_default_accounts_are_seeded_once_per_tenant_and_codes_are_unique_per_tenant(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $this->seed(FinancialInventoryFoundationSeeder::class);
        $this->assertSame(20, DB::table('financial_accounts')->where('tenant_id', $tenantId)->count());

        $this->postJson('/api/v1/finance/accounts', $this->accountPayload(['code' => '9000']), $this->headers($tenantId))->assertCreated();
        $this->postJson('/api/v1/finance/accounts', $this->accountPayload(['code' => '9000', 'nameAr' => 'حساب مكرر']), $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('code');

        $tenantB = $this->createTenant('unique-code-tenant');
        app(FinancialSetupService::class)->ensureForTenant($tenantB);
        $this->postJson('/api/v1/finance/accounts', $this->accountPayload(['code' => '9000']), $this->headers($tenantB))->assertCreated();
    }

    public function test_journal_entry_cannot_post_when_unbalanced_but_balanced_entry_posts_and_is_immutable(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id');
        $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '3000')->value('id');

        $unbalanced = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity, '100.00', '90.00'), $this->headers($tenantId))->assertCreated();
        $this->postJson('/api/v1/finance/journal-entries/'.$unbalanced->json('data.id').'/post', [], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('lines');

        $balanced = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity), $this->headers($tenantId))->assertCreated();
        $entryId = $balanced->json('data.id');
        $this->postJson('/api/v1/finance/journal-entries/'.$entryId.'/post', [], $this->headers($tenantId))->assertOk()->assertJsonPath('data.status', 'posted')->assertJsonPath('data.debitTotal', '100.00')->assertJsonPath('data.creditTotal', '100.00');
        $this->putJson('/api/v1/finance/journal-entries/'.$entryId, [], $this->headers($tenantId))->assertMethodNotAllowed();
        $this->deleteJson('/api/v1/finance/journal-entries/'.$entryId, [], $this->headers($tenantId))->assertMethodNotAllowed();
        $this->assertDatabaseHas('activity_logs', ['tenant_id' => $tenantId, 'entity_type' => 'journal_entry', 'entity_id' => $entryId, 'action' => 'journal_entry.posted']);
    }

    public function test_posted_journal_entry_can_be_reversed_exactly_once_with_swapped_balanced_lines(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id');
        $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '3000')->value('id');

        $entry = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity), $this->headers($tenantId))->assertCreated();
        $entryId = $entry->json('data.id');
        $this->postJson('/api/v1/finance/journal-entries/'.$entryId.'/post', [], $this->headers($tenantId))->assertOk();

        $original = $this->getJson('/api/v1/finance/journal-entries/'.$entryId, $this->headers($tenantId))->assertOk();
        $this->assertSame('posted', $original->json('data.status'));
        $this->assertFalse($original->json('data.isReversed'));

        $reversal = $this->postJson('/api/v1/finance/journal-entries/'.$entryId.'/reverse', [], $this->headers($tenantId))
            ->assertCreated()
            ->assertJsonPath('data.status', 'posted')
            ->assertJsonPath('data.reversalOfId', $entryId)
            ->assertJsonPath('data.debitTotal', '100.00')
            ->assertJsonPath('data.creditTotal', '100.00');
        $reversalId = $reversal->json('data.id');
        $this->assertNotSame($entryId, $reversalId);

        // Original stays exactly as it was: still posted, unedited, and now
        // flagged as reversed only through the relationship, never by
        // mutating its own status.
        $originalAfter = $this->getJson('/api/v1/finance/journal-entries/'.$entryId, $this->headers($tenantId))->assertOk();
        $this->assertSame('posted', $originalAfter->json('data.status'));
        $this->assertTrue($originalAfter->json('data.isReversed'));
        $this->assertSame($original->json('data.debitTotal'), $originalAfter->json('data.debitTotal'));
        $this->assertSame($original->json('data.creditTotal'), $originalAfter->json('data.creditTotal'));

        // Lines are exactly swapped.
        $originalLines = collect($original->json('data.lines'))->keyBy('accountId');
        $reversalLines = collect($reversal->json('data.lines'))->keyBy('accountId');
        foreach ($originalLines as $accountId => $line) {
            $this->assertSame($line['credit'], $reversalLines[$accountId]['debit']);
            $this->assertSame($line['debit'], $reversalLines[$accountId]['credit']);
        }

        // A journal entry can only be reversed once.
        $this->postJson('/api/v1/finance/journal-entries/'.$entryId.'/reverse', [], $this->headers($tenantId))
            ->assertUnprocessable()->assertJsonValidationErrors('entry');

        $this->assertDatabaseHas('activity_logs', ['tenant_id' => $tenantId, 'entity_type' => 'journal_entry', 'entity_id' => $entryId, 'action' => 'journal_entry.reversed']);
    }

    public function test_draft_journal_entry_cannot_be_reversed(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id');
        $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '3000')->value('id');

        $entry = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity), $this->headers($tenantId))->assertCreated();

        $this->postJson('/api/v1/finance/journal-entries/'.$entry->json('data.id').'/reverse', [], $this->headers($tenantId))
            ->assertUnprocessable()->assertJsonValidationErrors('entry');
    }

    public function test_reversal_of_a_foreign_tenants_entry_is_not_found(): void
    {
        $this->seed();
        $tenantA = $this->demoTenantId();
        $tenantB = $this->createTenant('reversal-foreign-tenant');
        app(FinancialSetupService::class)->ensureForTenant($tenantB);
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenantA)->where('code', '1010')->value('id');
        $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenantA)->where('code', '3000')->value('id');
        $entry = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity), $this->headers($tenantA))->assertCreated();
        $this->postJson('/api/v1/finance/journal-entries/'.$entry->json('data.id').'/post', [], $this->headers($tenantA))->assertOk();

        $this->postJson('/api/v1/finance/journal-entries/'.$entry->json('data.id').'/reverse', [], $this->headers($tenantB))->assertNotFound();
    }

    public function test_warehouse_type_and_branch_rules_are_validated(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
        $this->postJson('/api/v1/warehouses', $this->warehousePayload(['type' => 'central', 'branchId' => $branchId]), $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $this->postJson('/api/v1/warehouses', $this->warehousePayload(['type' => 'bar', 'branchId' => null]), $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('branchId');

        $tenantB = $this->createTenant('foreign-branch-tenant');
        $foreignBranchId = DB::table('branches')->insertGetId(['tenant_id' => $tenantB, 'name' => 'Other Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson('/api/v1/warehouses', $this->warehousePayload(['branchId' => $foreignBranchId]), $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('branchId');
    }

    public function test_setup_status_reports_foundation_readiness_accurately(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $this->getJson('/api/v1/finance/setup-status', $this->headers($tenantId))->assertOk()->assertJsonPath('data.systemAccountsReady', true)->assertJsonPath('data.centralWarehouseReady', true)->assertJsonPath('data.branchWarehouseCoverageReady', true)->assertJsonPath('data.financialSetupReady', true);

        DB::table('warehouses')->where('tenant_id', $tenantId)->where('type', 'central')->update(['is_active' => false]);
        $this->getJson('/api/v1/finance/setup-status', $this->headers($tenantId))->assertOk()->assertJsonPath('data.centralWarehouseReady', false)->assertJsonPath('data.financialSetupReady', false);
    }

    public function test_accounts_support_tenant_scoped_search_filters_and_safe_parent_hierarchy(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $parent = $this->postJson('/api/v1/finance/accounts', $this->accountPayload(['code' => '9100', 'nameAr' => 'Ø­Ø³Ø§Ø¨ Ø±Ø¦ÙŠØ³ÙŠ']), $this->headers($tenantId))->assertCreated();
        $child = $this->postJson('/api/v1/finance/accounts', $this->accountPayload(['code' => '9101', 'nameAr' => 'Ø­Ø³Ø§Ø¨ ÙØ±Ø¹ÙŠ', 'parentAccountId' => $parent->json('data.id')]), $this->headers($tenantId))->assertCreated();

        $this->getJson('/api/v1/finance/accounts?search=9101&group=expenses&status=active&system=non-system', $this->headers($tenantId))
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $child->json('data.id'));
        $this->getJson('/api/v1/finance/accounts/'.$child->json('data.id'), $this->headers($tenantId))
            ->assertOk()
            ->assertJsonPath('data.parentAccountId', $parent->json('data.id'))
            ->assertJsonPath('data.parentCode', '9100');
        $this->patchJson('/api/v1/finance/accounts/'.$parent->json('data.id'), $this->accountPayload(['code' => '9100', 'nameAr' => 'Ø­Ø³Ø§Ø¨ Ø±Ø¦ÙŠØ³ÙŠ', 'parentAccountId' => $child->json('data.id')]), $this->headers($tenantId))
            ->assertUnprocessable()->assertJsonValidationErrors('parentAccountId');
        $this->patchJson('/api/v1/finance/accounts/'.$child->json('data.id').'/status', ['isActive' => false], $this->headers($tenantId))->assertOk()->assertJsonPath('data.isActive', false);
        $this->patchJson('/api/v1/finance/accounts/'.DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id').'/status', ['isActive' => false], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('isActive');
    }

    public function test_journal_search_and_foundation_counts_are_real_and_tenant_scoped(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id');
        $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '3000')->value('id');
        $beforeCount = DB::table('journal_entries')->where('tenant_id', $tenantId)->count();
        $beforeDraftCount = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('status', 'draft')->count();
        $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity), $this->headers($tenantId))->assertCreated();

        $this->getJson('/api/v1/finance/journal-entries?search=manual&status=draft', $this->headers($tenantId))->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/finance/setup-status', $this->headers($tenantId))->assertOk()
            ->assertJsonPath('data.accountCount', 20)
            ->assertJsonPath('data.journalCount', $beforeCount + 1)
            ->assertJsonPath('data.draftJournalCount', $beforeDraftCount + 1)
            ->assertJsonPath('data.journalReversalReady', true);
    }

    public function test_cash_bank_locations_payment_methods_and_idempotent_cash_transfer_use_the_posted_ledger(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $headers = $this->headers($tenantId);
        $drawerId = (int) DB::table('financial_locations')->where('tenant_id', $tenantId)->where('code', 'CASH-DRAWER')->value('id');
        $safeId = (int) DB::table('financial_locations')->where('tenant_id', $tenantId)->where('code', 'MAIN-SAFE')->value('id');
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id');
        $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '3000')->value('id');
        $this->getJson('/api/v1/finance/payment-methods', $headers)->assertOk()->assertJsonPath('data.0.code', 'CASH')->assertJsonPath('data.0.financialAccountCode', '1010');
        $beforeBalance = $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->assertOk()->json('data.location.balance');
        $draft = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity), $headers)->assertCreated();
        $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->assertOk()->assertJsonPath('data.location.balance', $beforeBalance);
        $this->postJson('/api/v1/finance/journal-entries/'.$draft->json('data.id').'/post', [], $headers)->assertOk();
        $expectedPostedBalance = number_format((float) $beforeBalance + 100, 2, '.', '');
        $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->assertOk()->assertJsonPath('data.location.balance', $expectedPostedBalance);

        $payload = ['fromFinancialLocationId' => $drawerId, 'toFinancialLocationId' => $safeId, 'amount' => '25.00', 'transferDate' => '2026-08-20', 'idempotencyKey' => 'cash-transfer-1'];
        $first = $this->postJson('/api/v1/finance/cash-transfers', $payload, $headers)->assertCreated()->assertJsonPath('data.status', 'posted');
        $this->postJson('/api/v1/finance/cash-transfers', $payload, $headers)->assertCreated()->assertJsonPath('data.id', $first->json('data.id'));
        $this->postJson('/api/v1/finance/cash-transfers', [...$payload, 'amount' => '26.00'], $headers)->assertConflict();
        $this->assertSame(1, DB::table('cash_transfers')->where('tenant_id', $tenantId)->where('idempotency_key', 'cash-transfer-1')->count());
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenantId)->where('source_type', 'cash_transfer')->where('source_id', $first->json('data.id'))->count());
        $this->postJson('/api/v1/finance/cash-transfers/'.$first->json('data.id').'/reverse', [], $headers)->assertOk()->assertJsonPath('data.status', 'reversed');
        $this->assertSame($expectedPostedBalance, $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->json('data.location.balance'));
    }

    public function test_expense_is_a_tenant_scoped_business_record_with_one_idempotent_posted_payment_and_reversal(): void
    {
        $this->seed(); $tenant = $this->demoTenantId(); $headers = $this->headers($tenant);
        $expenseAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6100')->value('id');
        $category = $this->postJson('/api/v1/finance/expense-categories', ['code' => 'RENT', 'name' => 'Rent', 'financialAccountId' => $expenseAccount, 'isActive' => true], $headers)->assertCreated();
        $this->postJson('/api/v1/finance/expense-categories', ['code' => 'RENT', 'name' => 'Duplicate', 'financialAccountId' => $expenseAccount, 'isActive' => true], $headers)->assertUnprocessable()->assertJsonValidationErrors('code');
        $draftPayload = ['expenseCategoryId' => $category->json('data.id'), 'amount' => '100.00', 'taxAmount' => '10.00', 'expenseDate' => '2026-08-20', 'description' => 'August rent', 'idempotencyKey' => 'expense-create-1'];
        $expense = $this->postJson('/api/v1/finance/expenses', $draftPayload, $headers)->assertCreated()->assertJsonPath('data.status', 'draft'); $id = $expense->json('data.id');
        $this->postJson('/api/v1/finance/expenses', $draftPayload, $headers)->assertCreated()->assertJsonPath('data.id', $id);
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', ['paymentMethodId' => 1, 'financialLocationId' => 1, 'paymentDate' => '2026-08-20', 'idempotencyKey' => 'expense-pay-early'], $headers)->assertUnprocessable();
        $this->postJson('/api/v1/finance/expenses/'.$id.'/submit', [], $headers)->assertOk()->assertJsonPath('data.status', 'pending_approval');
        $this->postJson('/api/v1/finance/expenses/'.$id.'/approve', [], $headers)->assertOk()->assertJsonPath('data.status', 'approved');
        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id'); $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $pay = ['paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'paymentDate' => '2026-08-20', 'idempotencyKey' => 'expense-pay-1'];
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', $pay, $headers)->assertOk()->assertJsonPath('data.status', 'paid')->assertJsonPath('data.paymentStatus', 'paid');
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', $pay, $headers)->assertOk()->assertJsonPath('data.status', 'paid');
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'expense')->where('source_id', $id)->where('source_event', 'EXPENSE_PAID')->count());
        $this->patchJson('/api/v1/finance/expenses/'.$id, [...$draftPayload, 'amount' => '90.00'], $headers)->assertUnprocessable();
        $this->postJson('/api/v1/finance/expenses/'.$id.'/reverse', [], $headers)->assertOk()->assertJsonPath('data.status', 'reversed');
        $this->postJson('/api/v1/finance/expenses/'.$id.'/reverse', [], $headers)->assertUnprocessable();
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Finance Owner', 'email' => "finance-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $plainToken = "financial-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'financial-feature-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }

    private function createTenant(string $slug): int
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Central Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return (int) $tenantId;
    }

    private function warehousePayload(array $overrides = []): array
    {
        $branchId = $overrides['branchId'] ?? (int) DB::table('branches')->where('tenant_id', $this->demoTenantId())->value('id');

        return $overrides + ['name' => 'مخزن اختبار', 'code' => 'TEST-STORE', 'type' => 'branch_main', 'branchId' => $branchId, 'isActive' => true, 'notes' => 'مخزن تجريبي'];
    }

    private function accountPayload(array $overrides = []): array
    {
        return $overrides + ['code' => '9001', 'nameAr' => 'مصروف اختبار', 'nameEn' => 'Test Expense', 'accountGroup' => 'expenses', 'normalBalance' => 'debit', 'isActive' => true];
    }

    private function journalPayload(int $debitAccountId, int $creditAccountId, string $debit = '100.00', string $credit = '100.00'): array
    {
        return ['entryDate' => '2026-08-16', 'sourceType' => 'manual', 'description' => 'قيد اختبار', 'lines' => [['accountId' => $debitAccountId, 'debit' => $debit, 'credit' => '0.00'], ['accountId' => $creditAccountId, 'debit' => '0.00', 'credit' => $credit]]];
    }
}
