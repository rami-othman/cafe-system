<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use App\Support\FinanceAccess;
use Tests\TestCase;

/**
 * Phase 3 — Expenses. Comprehensive coverage of the parts the smoke test in
 * FinancialInventoryFoundationApiTest only touches at a high level: category
 * validation, the full draft/submit/approve/reject lifecycle, branch
 * authorization, exact debit/credit correctness and cash-balance effect of a
 * payment, rollback-on-invalid-payment-source, idempotent/conflicting replay
 * semantics, and reversal (original preserved, balance restored).
 */
class ExpenseWorkflowApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_expense_category_validation_rejects_wrong_account_group_inactive_account_and_enforces_tenant_isolation(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);

        $assetAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->postJson('/api/v1/finance/expense-categories', ['code' => 'BAD', 'name' => 'Bad', 'financialAccountId' => $assetAccount, 'isActive' => true], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('financialAccountId');

        $inactiveExpenseAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6190')->value('id');
        DB::table('financial_accounts')->where('id', $inactiveExpenseAccount)->update(['is_active' => false]);
        $this->postJson('/api/v1/finance/expense-categories', ['code' => 'MISC', 'name' => 'Misc', 'financialAccountId' => $inactiveExpenseAccount, 'isActive' => true], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('financialAccountId');

        $tenantB = $this->createTenant('expense-category-tenant-b');
        $foreignAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenantB)->where('code', '6100')->value('id');
        $this->postJson('/api/v1/finance/expense-categories', ['code' => 'FOREIGN', 'name' => 'Foreign', 'financialAccountId' => $foreignAccount, 'isActive' => true], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('financialAccountId');

        $goodAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6120')->value('id');
        $category = $this->postJson('/api/v1/finance/expense-categories', ['code' => 'UTIL', 'name' => 'Utilities', 'financialAccountId' => $goodAccount, 'isActive' => true], $headers)
            ->assertCreated()->assertJsonPath('data.code', 'UTIL');
        $categoryId = $category->json('data.id');
        $this->patchJson('/api/v1/finance/expense-categories/'.$categoryId, ['code' => 'UTIL', 'name' => 'Utilities Renamed', 'financialAccountId' => $goodAccount, 'isActive' => true], $headers)
            ->assertOk()->assertJsonPath('data.name', 'Utilities Renamed');

        $this->getJson('/api/v1/finance/expense-categories', $this->headers($tenantB))->assertOk()->assertJsonMissing(['id' => $categoryId]);
        $this->patchJson('/api/v1/finance/expense-categories/'.$categoryId.'/status', ['isActive' => false], $this->headers($tenantB))->assertNotFound();

        $this->patchJson('/api/v1/finance/expense-categories/'.$categoryId.'/status', ['isActive' => false], $headers)->assertOk()->assertJsonPath('data.isActive', false);
        $draft = ['expenseCategoryId' => $categoryId, 'amount' => '50.00', 'expenseDate' => '2026-08-20', 'description' => 'Should fail, inactive category'];
        $this->postJson('/api/v1/finance/expenses', $draft, $headers)->assertUnprocessable()->assertJsonValidationErrors('expenseCategoryId');
    }

    public function test_draft_lifecycle_edit_submit_reject_and_invalid_transitions_are_rejected(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $categoryId = $this->rentCategory($tenant, $headers);

        $draft = ['expenseCategoryId' => $categoryId, 'amount' => '100.00', 'taxAmount' => '0.00', 'expenseDate' => '2026-08-20', 'description' => 'Initial description'];
        $expense = $this->postJson('/api/v1/finance/expenses', $draft, $headers)->assertCreated()->assertJsonPath('data.status', 'draft');
        $id = $expense->json('data.id');

        $this->postJson('/api/v1/finance/expenses/'.$id.'/approve', [], $headers)->assertUnprocessable()->assertJsonValidationErrors('expense');
        $this->postJson('/api/v1/finance/expenses/'.$id.'/reject', ['rejectionReason' => 'too early'], $headers)->assertUnprocessable()->assertJsonValidationErrors('expense');

        $this->patchJson('/api/v1/finance/expenses/'.$id, [...$draft, 'amount' => '120.00', 'description' => 'Revised description'], $headers)
            ->assertOk()->assertJsonPath('data.amount', '120.00')->assertJsonPath('data.totalAmount', '120.00')->assertJsonPath('data.description', 'Revised description');

        $this->postJson('/api/v1/finance/expenses/'.$id.'/submit', [], $headers)->assertOk()->assertJsonPath('data.status', 'pending_approval');

        $this->patchJson('/api/v1/finance/expenses/'.$id, [...$draft, 'amount' => '999.00'], $headers)->assertUnprocessable()->assertJsonValidationErrors('expense');
        $this->postJson('/api/v1/finance/expenses/'.$id.'/submit', [], $headers)->assertUnprocessable()->assertJsonValidationErrors('expense');

        $this->postJson('/api/v1/finance/expenses/'.$id.'/reject', [], $headers)->assertUnprocessable()->assertJsonValidationErrors('rejectionReason');
        $rejected = $this->postJson('/api/v1/finance/expenses/'.$id.'/reject', ['rejectionReason' => 'Not needed this month'], $headers)
            ->assertOk()->assertJsonPath('data.status', 'rejected')->assertJsonPath('data.rejectionReason', 'Not needed this month');
        $this->assertNotNull($rejected->json('data.rejectedAt'));

        $this->postJson('/api/v1/finance/expenses/'.$id.'/submit', [], $headers)->assertUnprocessable();
        $this->postJson('/api/v1/finance/expenses/'.$id.'/approve', [], $headers)->assertUnprocessable();
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'expense')->where('source_id', $id)->count());
    }

    public function test_branch_scoped_manager_cannot_read_or_approve_another_branchs_expense(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $ownerHeaders = $this->headers($tenant);
        $ownBranch = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $otherBranch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Second Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $categoryId = $this->rentCategory($tenant, $ownerHeaders);

        $expense = $this->postJson('/api/v1/finance/expenses', [
            'branchId' => $otherBranch, 'expenseCategoryId' => $categoryId, 'amount' => '75.00', 'expenseDate' => '2026-08-20', 'description' => 'Other branch rent',
        ], $ownerHeaders)->assertCreated();
        $id = $expense->json('data.id');
        $this->postJson('/api/v1/finance/expenses/'.$id.'/submit', [], $ownerHeaders)->assertOk();

        $managerHeaders = $this->managerHeaders($tenant, $ownBranch);
        $this->getJson('/api/v1/finance/expenses/'.$id, $managerHeaders)->assertForbidden();
        $this->postJson('/api/v1/finance/expenses/'.$id.'/approve', [], $managerHeaders)->assertForbidden();

        $ownExpense = $this->postJson('/api/v1/finance/expenses', [
            'branchId' => $ownBranch, 'expenseCategoryId' => $categoryId, 'amount' => '40.00', 'expenseDate' => '2026-08-20', 'description' => 'Own branch rent',
        ], $managerHeaders)->assertCreated();
        $this->postJson('/api/v1/finance/expenses/'.$ownExpense->json('data.id').'/submit', [], $managerHeaders)->assertOk();
        $this->postJson('/api/v1/finance/expenses/'.$ownExpense->json('data.id').'/approve', [], $managerHeaders)->assertUnprocessable()->assertJsonValidationErrors('approval');
        $this->postJson('/api/v1/finance/expenses/'.$ownExpense->json('data.id').'/approve', [], $ownerHeaders)->assertOk()->assertJsonPath('data.status', 'approved');
    }

    public function test_expense_list_scoping_matches_direct_access_rules_for_owner_single_branch_multi_branch_and_no_branch_users(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $ownerHeaders = $this->headers($tenant);
        $branchA = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $branchB = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch B', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $branchC = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch C', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $categoryId = $this->rentCategory($tenant, $ownerHeaders);

        $expenseA = $this->createExpense($tenant, $ownerHeaders, $categoryId, $branchA, '10.00');
        $expenseB = $this->createExpense($tenant, $ownerHeaders, $categoryId, $branchB, '20.00');
        $expenseC = $this->createExpense($tenant, $ownerHeaders, $categoryId, $branchC, '30.00');
        $expenseCompanyWide = $this->createExpense($tenant, $ownerHeaders, $categoryId, null, '40.00');

        // Owner sees every branch, including branches they have no explicit
        // user_branches row for (FinancialActor::assertBranchAccess bypasses
        // the check entirely for role=owner).
        $ownerIds = collect($this->getJson('/api/v1/finance/expenses', $ownerHeaders)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ownerIds->contains($expenseA) && $ownerIds->contains($expenseB) && $ownerIds->contains($expenseC) && $ownerIds->contains($expenseCompanyWide));

        // A single-branch manager sees their own branch plus company-wide
        // (branch_id NULL) expenses, but not other branches' — and the list
        // matches exactly what direct GET-by-id allows or rejects.
        $managerA = $this->managerHeaders($tenant, $branchA);
        $idsForA = collect($this->getJson('/api/v1/finance/expenses', $managerA)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($idsForA->contains($expenseA));
        $this->assertTrue($idsForA->contains($expenseCompanyWide));
        $this->assertFalse($idsForA->contains($expenseB));
        $this->assertFalse($idsForA->contains($expenseC));
        $this->getJson('/api/v1/finance/expenses/'.$expenseA, $managerA)->assertOk();
        $this->getJson('/api/v1/finance/expenses/'.$expenseCompanyWide, $managerA)->assertOk();
        $this->getJson('/api/v1/finance/expenses/'.$expenseB, $managerA)->assertForbidden();
        $this->getJson('/api/v1/finance/expenses/'.$expenseC, $managerA)->assertForbidden();

        // A manager assigned to two branches sees both, but not the third.
        $managerAB = $this->managerHeaders($tenant, $branchA);
        // managerHeaders() only grants one branch; add the second explicitly.
        $userId = (int) DB::table('users')->where('tenant_id', $tenant)->where('name', 'Branch Manager')->orderByDesc('id')->value('id');
        DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $userId, 'branch_id' => $branchB, 'created_at' => now(), 'updated_at' => now()]);
        $idsForAB = collect($this->getJson('/api/v1/finance/expenses', $managerAB)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($idsForAB->contains($expenseA));
        $this->assertTrue($idsForAB->contains($expenseB));
        $this->assertTrue($idsForAB->contains($expenseCompanyWide));
        $this->assertFalse($idsForAB->contains($expenseC));
        $this->getJson('/api/v1/finance/expenses/'.$expenseB, $managerAB)->assertOk();
        $this->getJson('/api/v1/finance/expenses/'.$expenseC, $managerAB)->assertForbidden();

        // A manager with no branch assignment sees only company-wide expenses.
        $unassignedUserId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Unassigned Manager', 'email' => 'expense-unassigned-'.uniqid().'@example.test', 'password' => bcrypt('password'), 'role' => 'manager', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $unassignedHeaders = $this->tokenHeaders($tenant, $unassignedUserId, 'unassigned');
        $idsForUnassigned = collect($this->getJson('/api/v1/finance/expenses', $unassignedHeaders)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($idsForUnassigned->contains($expenseCompanyWide));
        $this->assertFalse($idsForUnassigned->contains($expenseA));
        $this->getJson('/api/v1/finance/expenses/'.$expenseA, $unassignedHeaders)->assertForbidden();
        $this->getJson('/api/v1/finance/expenses/'.$expenseCompanyWide, $unassignedHeaders)->assertOk();

        // Cross-tenant: a token from another tenant sees none of this
        // tenant's expenses in its list and cannot fetch any by id.
        $tenantB = $this->createTenant('expense-access-tenant-b');
        $otherHeaders = $this->headers($tenantB);
        $idsForOtherTenant = collect($this->getJson('/api/v1/finance/expenses', $otherHeaders)->assertOk()->json('data'))->pluck('id');
        $this->assertFalse($idsForOtherTenant->contains($expenseA) || $idsForOtherTenant->contains($expenseCompanyWide));
        $this->getJson('/api/v1/finance/expenses/'.$expenseA, $otherHeaders)->assertNotFound();
        $this->getJson('/api/v1/finance/expenses/'.$expenseCompanyWide, $otherHeaders)->assertNotFound();
    }

    public function test_payment_debits_expense_account_credits_cash_account_balances_the_journal_and_moves_the_cash_balance(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $categoryId = $this->rentCategory($tenant, $headers);
        $id = $this->approvedExpense($tenant, $headers, $categoryId, '250.00', '25.00');

        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $expenseAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6100')->value('id');
        $cashAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $balanceBefore = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$locationId.'/transactions', $headers)->json('data.location.balance');

        $pay = ['paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'paymentDate' => '2026-08-21', 'idempotencyKey' => 'pay-balance-1'];
        $result = $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', $pay, $headers)->assertOk()->assertJsonPath('data.status', 'paid')->assertJsonPath('data.paymentStatus', 'paid');
        $journalEntryId = $result->json('data.journalEntryId');
        $this->assertNotNull($journalEntryId);

        $entry = DB::table('journal_entries')->where('id', $journalEntryId)->first();
        $this->assertSame('posted', $entry->status);
        $this->assertSame($tenant, (int) $entry->tenant_id);
        $this->assertSame('expense', $entry->source_type);
        $this->assertSame($id, (int) $entry->source_id);
        $this->assertSame('EXPENSE_PAID', $entry->source_event);

        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journalEntryId)->orderBy('line_number')->get();
        $this->assertCount(2, $lines);
        $debitTotal = $lines->sum(fn ($line) => (float) $line->debit);
        $creditTotal = $lines->sum(fn ($line) => (float) $line->credit);
        $this->assertSame(275.0, $debitTotal);
        $this->assertSame(275.0, $creditTotal);

        $expenseLine = $lines->firstWhere('financial_account_id', $expenseAccountId);
        $cashLine = $lines->firstWhere('financial_account_id', $cashAccountId);
        $this->assertNotNull($expenseLine, 'Expense category account must be debited.');
        $this->assertSame(275.0, (float) $expenseLine->debit);
        $this->assertSame(0.0, (float) $expenseLine->credit);
        $this->assertNotNull($cashLine, 'Selected cash account must be credited.');
        $this->assertSame(275.0, (float) $cashLine->credit);
        $this->assertSame(0.0, (float) $cashLine->debit);

        $balanceAfter = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$locationId.'/transactions', $headers)->json('data.location.balance');
        $this->assertSame(round($balanceBefore - 275.0, 2), round($balanceAfter, 2));

        // Idempotent replay: identical key + identical payload returns the same paid result, no second journal.
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', $pay, $headers)->assertOk()->assertJsonPath('data.journalEntryId', $journalEntryId);
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'expense')->where('source_id', $id)->where('source_event', 'EXPENSE_PAID')->count());

        // Conflicting replay: same key, different payload -> 409, no new journal.
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', [...$pay, 'financialLocationId' => $locationId, 'paymentDate' => '2026-08-22'], $headers)->assertConflict();

        // A brand-new idempotency key against an already-paid expense is rejected, not silently re-posted.
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', [...$pay, 'idempotencyKey' => 'pay-balance-2'], $headers)->assertUnprocessable()->assertJsonValidationErrors('expense');
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'expense')->where('source_id', $id)->count());
    }

    public function test_payment_with_an_invalid_payment_source_is_rejected_and_leaves_the_expense_unpaid_with_no_journal(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $categoryId = $this->rentCategory($tenant, $headers);
        $id = $this->approvedExpense($tenant, $headers, $categoryId, '60.00', '0.00');

        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');

        // Mismatched method/location pair (location's account differs from method's account).
        $bankLocationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', [
            'paymentMethodId' => $methodId, 'financialLocationId' => $bankLocationId, 'paymentDate' => '2026-08-21', 'idempotencyKey' => 'bad-pair-1',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('payment');

        // Inactive payment method.
        DB::table('payment_methods')->where('id', $methodId)->update(['is_active' => false]);
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', [
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'paymentDate' => '2026-08-21', 'idempotencyKey' => 'bad-method-1',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('payment');
        DB::table('payment_methods')->where('id', $methodId)->update(['is_active' => true]);

        // Category's linked account becomes inactive between approval and payment.
        $categoryAccountId = (int) DB::table('expense_categories')->where('id', $categoryId)->value('financial_account_id');
        DB::table('financial_accounts')->where('id', $categoryAccountId)->update(['is_active' => false]);
        $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', [
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'paymentDate' => '2026-08-21', 'idempotencyKey' => 'bad-category-1',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('expenseCategoryId');
        DB::table('financial_accounts')->where('id', $categoryAccountId)->update(['is_active' => true]);

        $expense = DB::table('expenses')->where('id', $id)->first();
        $this->assertSame('approved', $expense->status);
        $this->assertSame('unpaid', $expense->payment_status);
        $this->assertNull($expense->journal_entry_id);
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'expense')->where('source_id', $id)->count());
    }

    public function test_paid_expense_is_immutable_and_reversal_preserves_the_original_journal_and_restores_the_cash_balance(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $categoryId = $this->rentCategory($tenant, $headers);
        $id = $this->approvedExpense($tenant, $headers, $categoryId, '80.00', '0.00');

        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $balanceBeforePay = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$locationId.'/transactions', $headers)->json('data.location.balance');

        $paid = $this->postJson('/api/v1/finance/expenses/'.$id.'/pay', [
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'paymentDate' => '2026-08-21', 'idempotencyKey' => 'reverse-flow-pay',
        ], $headers)->assertOk();
        $originalJournalId = $paid->json('data.journalEntryId');

        $this->patchJson('/api/v1/finance/expenses/'.$id, [
            'expenseCategoryId' => $categoryId, 'amount' => '1.00', 'expenseDate' => '2026-08-21', 'description' => 'attempted mutation',
        ], $headers)->assertUnprocessable();
        $unchanged = DB::table('expenses')->where('id', $id)->first();
        $this->assertSame(80.0, (float) $unchanged->amount);

        $reversed = $this->postJson('/api/v1/finance/expenses/'.$id.'/reverse', [], $headers)->assertOk()->assertJsonPath('data.status', 'reversed');
        $reversalJournalId = $reversed->json('data.reversalJournalEntryId');
        $this->assertNotNull($reversalJournalId);
        $this->assertNotSame($originalJournalId, $reversalJournalId);

        $original = DB::table('journal_entries')->where('id', $originalJournalId)->first();
        $this->assertSame('posted', $original->status, 'The original journal entry must stay posted, never mutated or deleted.');
        $reversal = DB::table('journal_entries')->where('id', $reversalJournalId)->first();
        $this->assertSame('posted', $reversal->status);
        $this->assertSame((int) $originalJournalId, (int) $reversal->reversal_of_id);

        $originalLines = DB::table('journal_entry_lines')->where('journal_entry_id', $originalJournalId)->orderBy('line_number')->get();
        $reversalLines = DB::table('journal_entry_lines')->where('journal_entry_id', $reversalJournalId)->orderBy('line_number')->get();
        $this->assertSame(
            $originalLines->sum(fn ($l) => (float) $l->debit),
            $reversalLines->sum(fn ($l) => (float) $l->credit),
        );
        $this->assertSame(
            $originalLines->sum(fn ($l) => (float) $l->credit),
            $reversalLines->sum(fn ($l) => (float) $l->debit),
        );

        $balanceAfterReversal = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$locationId.'/transactions', $headers)->json('data.location.balance');
        $this->assertSame(round($balanceBeforePay, 2), round($balanceAfterReversal, 2));

        $this->postJson('/api/v1/finance/expenses/'.$id.'/reverse', [], $headers)->assertUnprocessable();
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('reversal_of_id', $originalJournalId)->count());
    }

    public function test_summary_aggregates_the_same_filtered_scope_as_the_list_not_a_partial_page(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $categoryId = $this->rentCategory($tenant, $headers);

        $draft = $this->createExpense($tenant, $headers, $categoryId, null, '10.00');
        $pendingA = $this->createExpense($tenant, $headers, $categoryId, null, '20.00');
        $this->postJson('/api/v1/finance/expenses/'.$pendingA.'/submit', [], $headers)->assertOk();
        $pendingB = $this->createExpense($tenant, $headers, $categoryId, null, '30.00');
        $this->postJson('/api/v1/finance/expenses/'.$pendingB.'/submit', [], $headers)->assertOk();
        $rejected = $this->createExpense($tenant, $headers, $categoryId, null, '40.00');
        $this->postJson('/api/v1/finance/expenses/'.$rejected.'/submit', [], $headers)->assertOk();
        $this->postJson('/api/v1/finance/expenses/'.$rejected.'/reject', ['rejectionReason' => 'not needed'], $headers)->assertOk();

        $summary = $this->getJson('/api/v1/finance/expenses/summary', $headers)->assertOk();
        $this->assertGreaterThanOrEqual(4, $summary->json('data.count'));
        $this->assertGreaterThanOrEqual(100.0, (float) $summary->json('data.totalAmount'));
        $this->assertSame(50.0, (float) $summary->json('data.pendingApprovalAmount'));
        $this->assertSame(40.0, (float) $summary->json('data.rejectedAmount'));

        // The status filter narrows summary() exactly like it narrows index().
        $rejectedOnly = $this->getJson('/api/v1/finance/expenses/summary?status=rejected', $headers)->assertOk();
        $this->assertSame(1, $rejectedOnly->json('data.count'));
        $this->assertSame(40.0, (float) $rejectedOnly->json('data.totalAmount'));
        $this->assertSame(40.0, (float) $rejectedOnly->json('data.averageAmount'));

        $draftStatus = DB::table('expenses')->where('id', $draft)->value('status');
        $this->assertSame('draft', $draftStatus);
    }

    public function test_allowed_actions_reflect_backend_state_and_approval_policy_not_status_alone(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $ownerHeaders = $this->headers($tenant);
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $categoryId = $this->rentCategory($tenant, $ownerHeaders);
        $managerHeaders = $this->managerHeaders($tenant, $branch);

        $expense = $this->postJson('/api/v1/finance/expenses', [
            'branchId' => $branch, 'expenseCategoryId' => $categoryId, 'amount' => '15.00', 'expenseDate' => '2026-08-20', 'description' => 'Allowed actions fixture',
        ], $managerHeaders)->assertCreated();
        $id = $expense->json('data.id');
        $this->assertSame(['edit', 'submit'], $expense->json('data.allowedActions'));

        $this->postJson('/api/v1/finance/expenses/'.$id.'/submit', [], $managerHeaders)->assertOk();

        // The manager who created it cannot approve their own expense — only reject is offered.
        $ownRead = $this->getJson('/api/v1/finance/expenses/'.$id, $managerHeaders)->assertOk();
        $this->assertSame(['reject'], $ownRead->json('data.allowedActions'));

        // The owner, unaffected by the self-approval rule, sees both.
        $ownerRead = $this->getJson('/api/v1/finance/expenses/'.$id, $ownerHeaders)->assertOk();
        $this->assertSame(['approve', 'reject'], $ownerRead->json('data.allowedActions'));

        $this->postJson('/api/v1/finance/expenses/'.$id.'/approve', [], $ownerHeaders)->assertOk();
        $approvedRead = $this->getJson('/api/v1/finance/expenses/'.$id, $ownerHeaders)->assertOk();
        $this->assertSame(['pay'], $approvedRead->json('data.allowedActions'));
    }

    public function test_expenses_branches_only_expose_the_actors_authorized_branches(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $owner = $this->headers($tenant);
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $ownerBranches = $this->getJson('/api/v1/finance/expenses/branches', $owner)->assertOk()->json('data.branches');
        $this->assertGreaterThanOrEqual(1, count($ownerBranches));

        $manager = $this->managerHeaders($tenant, $branch);
        $managerBranches = $this->getJson('/api/v1/finance/expenses/branches', $manager)->assertOk()->json('data.branches');
        $this->assertSame([$branch], array_column($managerBranches, 'id'));
    }

    private function rentCategory(int $tenant, array $headers): int
    {
        $account = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6100')->value('id');
        $code = 'RENT-'.$tenant.'-'.uniqid();
        return $this->postJson('/api/v1/finance/expense-categories', ['code' => $code, 'name' => 'Rent', 'financialAccountId' => $account, 'isActive' => true], $headers)
            ->assertCreated()->json('data.id');
    }

    private function createExpense(int $tenant, array $headers, int $categoryId, ?int $branchId, string $amount): int
    {
        return $this->postJson('/api/v1/finance/expenses', [
            'branchId' => $branchId, 'expenseCategoryId' => $categoryId, 'amount' => $amount, 'expenseDate' => '2026-08-20',
            'description' => 'Access-scoping fixture', 'idempotencyKey' => 'expense-access-'.uniqid(),
        ], $headers)->assertCreated()->json('data.id');
    }

    private function approvedExpense(int $tenant, array $headers, int $categoryId, string $amount, string $tax): int
    {
        $expense = $this->postJson('/api/v1/finance/expenses', [
            'expenseCategoryId' => $categoryId, 'amount' => $amount, 'taxAmount' => $tax, 'expenseDate' => '2026-08-20', 'description' => 'Approved expense fixture',
        ], $headers)->assertCreated();
        $id = $expense->json('data.id');
        $this->postJson('/api/v1/finance/expenses/'.$id.'/submit', [], $headers)->assertOk();
        $this->postJson('/api/v1/finance/expenses/'.$id.'/approve', [], $headers)->assertOk()->assertJsonPath('data.status', 'approved');

        return $id;
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function createTenant(string $slug): int
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Central Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(\App\Services\FinancialSetupService::class)->ensureForTenant($tenantId);

        return (int) $tenantId;
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Finance Owner', 'email' => "expense-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }

        return $this->tokenHeaders($tenantId, $userId, 'owner');
    }

    private function managerHeaders(int $tenantId, int $branchId): array
    {
        $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Branch Manager', 'email' => 'expense-manager-'.$tenantId.'-'.uniqid().'@example.test', 'password' => bcrypt('password'), 'role' => 'manager', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->grantManagerFinanceDefaults($tenantId);
        DB::table('user_branches')->insert(['tenant_id' => $tenantId, 'user_id' => $userId, 'branch_id' => $branchId, 'created_at' => now(), 'updated_at' => now()]);

        return $this->tokenHeaders($tenantId, $userId, 'manager');
    }

    private function tokenHeaders(int $tenantId, int $userId, string $label): array
    {
        $plainToken = "expense-test-$tenantId-$userId-$label";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'expense-feature-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
    private function grantManagerFinanceDefaults(int $tenantId): void { foreach (FinanceAccess::defaultPermissionsForRole('manager') as $permission) DB::table('finance_role_permissions')->updateOrInsert(['tenant_id'=>$tenantId,'role'=>'manager','permission'=>$permission],['created_at'=>now(),'updated_at'=>now()]); }
}
