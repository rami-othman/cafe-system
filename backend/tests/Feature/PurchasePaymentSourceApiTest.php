<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * D2 — `POST /finance/supplier-payments` (the "دفعة مورد جديدة" flow the
 * Flutter Supplier Profile screen now calls with an explicit branchId and a
 * branch-scoped source) must use the actual selected/authorized cash source,
 * never a silently substituted shared account. CashSourceResolver already
 * enforces this; these tests prove the contract this endpoint relies on.
 */
class PurchasePaymentSourceApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_explicit_branch_drawer_is_used_and_not_replaced_by_main_safe(): void
    {
        [$tenant, $headers, $branchId, $supplierId] = $this->fixture('tierfour-drawer');
        $invoiceId = $this->postedInvoice($headers, $supplierId, '150.00');
        $drawer = $this->drawer($branchId);
        $mainSafe = $this->mainSafe($tenant);
        $this->assertNotSame($drawer, $mainSafe);
        $methodId = $this->cashMethodId($tenant);

        $payment = $this->postJson('/api/v1/finance/supplier-payments', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'paymentDate' => '2026-09-01', 'amount' => '150.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $drawer, 'idempotencyKey' => 'd2-explicit-drawer',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '150.00']],
        ], $headers)->assertCreated();

        $this->assertSame($drawer, (int) $payment->json('data.financialLocationId'));
        $this->assertNotSame($mainSafe, (int) $payment->json('data.financialLocationId'));

        // Journal assertions: Dr Payable (2000) / Cr the branch drawer's own account.
        $journalId = (int) $payment->json('data.journalEntryId');
        $drawerAccountId = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');
        $payableAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '2000')->value('id');
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journalId)->orderBy('line_number')->get();
        $this->assertCount(2, $lines);
        $this->assertSame($payableAccountId, (int) $lines[0]->financial_account_id);
        $this->assertSame('150.00', $lines[0]->debit);
        $this->assertSame($drawerAccountId, (int) $lines[1]->financial_account_id);
        $this->assertSame('150.00', $lines[1]->credit);
        $this->assertSame($drawer, (int) $lines[1]->financial_location_id);
        $this->assertSame($branchId, (int) DB::table('journal_entries')->where('id', $journalId)->value('branch_id'));
        $this->assertSame('2026-09-01', (string) DB::table('journal_entries')->where('id', $journalId)->value('entry_date'));
    }

    public function test_wrong_branch_source_is_rejected(): void
    {
        [$tenant, $headers, $branchA, $supplierId] = $this->fixture('wrong-branch');
        $branchB = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch B', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->provisionDrawer($tenant, $branchB);
        $invoiceId = $this->postedInvoice($headers, $supplierId, '90.00');
        $methodId = $this->cashMethodId($tenant);

        $response = $this->postJson('/api/v1/finance/supplier-payments', [
            'branchId' => $branchA, 'supplierId' => $supplierId, 'paymentDate' => '2026-09-01', 'amount' => '90.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $this->drawer($branchB), 'idempotencyKey' => 'd2-wrong-branch',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '90.00']],
        ], $headers)->assertUnprocessable();
        $response->assertJsonValidationErrors(['financialLocationId']);
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
    }

    public function test_shared_main_safe_remains_usable_from_any_branch_when_explicitly_selected(): void
    {
        // A tenant-wide safe with branch_id = null is a legitimate cross-branch
        // source under the existing domain — CashSourceResolver preserves this;
        // the fix only removes the *silent, unauthorized* default, not this.
        [$tenant, $headers, $branchId, $supplierId] = $this->fixture('shared-safe');
        $invoiceId = $this->postedInvoice($headers, $supplierId, '60.00');
        $mainSafe = $this->mainSafe($tenant);
        $methodId = $this->cashMethodId($tenant);

        $this->postJson('/api/v1/finance/supplier-payments', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'paymentDate' => '2026-09-01', 'amount' => '60.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $mainSafe, 'idempotencyKey' => 'd2-shared-safe',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '60.00']],
        ], $headers)->assertCreated()->assertJsonPath('data.financialLocationId', $mainSafe);
    }

    public function test_cashier_payment_uses_own_open_shift_drawer_and_cannot_select_another_location(): void
    {
        [$tenant, $headers, $branchId, $supplierId] = $this->fixture('cashier-shift');
        $invoiceId = $this->postedInvoice($headers, $supplierId, '40.00');
        $cashierHeaders = $this->cashierHeaders($tenant, $branchId, 'd2-cashier');
        $this->fundDrawer($tenant, $branchId, $headers, '500.00');
        $shift = $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => '500.00'], $cashierHeaders)
            ->assertCreated()->json('data');
        $methodId = $this->cashMethodId($tenant);

        // No explicit financialLocationId: resolves to the cashier's own drawer.
        $payment = $this->postJson('/api/v1/finance/supplier-payments', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'paymentDate' => '2026-09-01', 'amount' => '40.00',
            'paymentMethodId' => $methodId, 'idempotencyKey' => 'd2-cashier-own-drawer',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '40.00']],
        ], $cashierHeaders)->assertCreated();
        $this->assertSame($this->drawer($branchId), (int) $payment->json('data.financialLocationId'));
        $this->assertSame((int) $shift['id'], (int) DB::table('supplier_payments')->where('id', $payment->json('data.id'))->value('shift_id'));

        // Explicitly trying to pick a different location (even Main Safe) is rejected for a cashier.
        $invoiceId2 = $this->postedInvoice($headers, $supplierId, '10.00');
        $this->postJson('/api/v1/finance/supplier-payments', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'paymentDate' => '2026-09-01', 'amount' => '10.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $this->mainSafe($tenant), 'idempotencyKey' => 'd2-cashier-override',
            'allocations' => [['invoiceId' => $invoiceId2, 'amount' => '10.00']],
        ], $cashierHeaders)->assertUnprocessable()->assertJsonValidationErrors(['financialLocationId']);
    }

    public function test_another_users_open_shift_drawer_is_rejected_for_a_manager_explicit_pick(): void
    {
        [$tenant, $headers, $branchId, $supplierId] = $this->fixture('foreign-drawer');
        $invoiceId = $this->postedInvoice($headers, $supplierId, '25.00');
        $cashierHeaders = $this->cashierHeaders($tenant, $branchId, 'd2-owned-drawer');
        $this->fundDrawer($tenant, $branchId, $headers, '200.00');
        $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => '200.00'], $cashierHeaders)->assertCreated();
        $methodId = $this->cashMethodId($tenant);

        // An owner explicitly trying to pay from the branch drawer while a cashier's shift owns it is rejected.
        $response = $this->postJson('/api/v1/finance/supplier-payments', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'paymentDate' => '2026-09-01', 'amount' => '25.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $this->drawer($branchId), 'idempotencyKey' => 'd2-foreign-drawer',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '25.00']],
        ], $headers)->assertUnprocessable();
        $response->assertJsonValidationErrors(['financialLocationId']);
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
    }

    public function test_inactive_source_is_rejected(): void
    {
        [$tenant, $headers, $branchId, $supplierId] = $this->fixture('inactive-source');
        $invoiceId = $this->postedInvoice($headers, $supplierId, '15.00');
        DB::table('financial_locations')->where('id', $this->drawer($branchId))->update(['is_active' => false]);
        $methodId = $this->cashMethodId($tenant);

        $response = $this->postJson('/api/v1/finance/supplier-payments', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'paymentDate' => '2026-09-01', 'amount' => '15.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $this->drawer($branchId), 'idempotencyKey' => 'd2-inactive-source',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '15.00']],
        ], $headers)->assertUnprocessable();
        $response->assertJsonValidationErrors(['financialLocationId']);
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
    }

    public function test_no_immediate_payment_via_purchase_posting_requires_no_source_and_creates_no_payment(): void
    {
        [$tenant, $headers, $branchId, $supplierId] = $this->fixture('zero-payment');
        $categoryId = $this->expenseCategory($tenant, $headers, '6140');
        $invoiceId = (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'invoiceNumber' => 'D2-ZERO-1',
            'invoiceDate' => '2026-09-01', 'dueDate' => '2026-09-01', 'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId,
            'lines' => [['lineType' => 'expense', 'description' => 'Service', 'quantity' => '1', 'lineGrossAmount' => '50.00']],
        ], $headers)->assertCreated()->json('data.id');

        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'd2-zero-post', 'paidAmount' => '0.00'], $headers)
            ->assertOk()->assertJsonPath('data.paymentStatus', 'unpaid');
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
        $this->assertSame('posted', DB::table('supplier_invoices')->where('id', $invoiceId)->value('status'));
    }

    public function test_retry_with_same_idempotency_key_does_not_duplicate_payment(): void
    {
        [$tenant, $headers, $branchId, $supplierId] = $this->fixture('idempotent-payment');
        $invoiceId = $this->postedInvoice($headers, $supplierId, '75.00');
        $methodId = $this->cashMethodId($tenant);
        $payload = [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'paymentDate' => '2026-09-01', 'amount' => '75.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $this->drawer($branchId), 'idempotencyKey' => 'd2-retry-key',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '75.00']],
        ];

        $first = $this->postJson('/api/v1/finance/supplier-payments', $payload, $headers)->assertCreated();
        $second = $this->postJson('/api/v1/finance/supplier-payments', $payload, $headers)->assertCreated();
        $this->assertSame($first->json('data.id'), $second->json('data.id'));
        $this->assertSame(1, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
        $this->assertSame('paid', DB::table('supplier_invoices')->where('id', $invoiceId)->value('status'));
    }

    /** @return array{0:int,1:array,2:int,3:int} */
    private function fixture(string $slug): array
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => 'd2-'.$slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branchId = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenantId, 'name' => '618TierFour', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant((int) $tenantId);
        $this->provisionDrawer((int) $tenantId, $branchId);
        $headers = $this->ownerHeaders((int) $tenantId);
        $supplierId = (int) $this->postJson('/api/v1/finance/suppliers', ['name' => 'D2 Supplier '.uniqid()], $headers)->assertCreated()->json('data.id');

        return [(int) $tenantId, $headers, $branchId, $supplierId];
    }

    /** Mirrors the app's branch POS-drawer auto-provisioning for a branch created directly in the test (bypassing the branches API). */
    private function provisionDrawer(int $tenantId, int $branchId): void
    {
        if (DB::table('branches')->where('id', $branchId)->value('pos_cash_financial_location_id')) {
            return;
        }
        $accountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id');
        $locationId = (int) DB::table('financial_locations')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'financial_account_id' => $accountId,
            'code' => 'CASH-DRAWER-'.$branchId, 'name' => 'Branch Drawer '.$branchId, 'kind' => 'cash', 'type' => 'cash_drawer', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('branches')->where('id', $branchId)->update(['pos_cash_financial_location_id' => $locationId]);
    }

    private function drawer(int $branchId): int
    {
        return (int) DB::table('branches')->where('id', $branchId)->value('pos_cash_financial_location_id');
    }

    private function mainSafe(int $tenantId): int
    {
        return (int) DB::table('financial_locations')->where('tenant_id', $tenantId)->where('code', 'MAIN-SAFE')->value('id');
    }

    private function cashMethodId(int $tenantId): int
    {
        return (int) DB::table('payment_methods')->where('tenant_id', $tenantId)->where('code', 'CASH')->value('id');
    }

    private function postedInvoice(array $headers, int $supplierId, string $amount): int
    {
        $categoryId = $this->expenseCategory((int) $headers['X-Tenant-Id'], $headers, '6140');
        $invoiceId = (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => (int) DB::table('branches')->where('tenant_id', $headers['X-Tenant-Id'])->orderBy('id')->value('id'),
            'supplierId' => $supplierId, 'invoiceNumber' => 'D2-'.uniqid(), 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-09-01',
            'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId,
            'lines' => [['lineType' => 'expense', 'description' => 'Service', 'quantity' => '1', 'lineGrossAmount' => $amount]],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$invoiceId}/post", ['idempotencyKey' => 'd2-invoice-post-'.$invoiceId], $headers)->assertOk();

        return $invoiceId;
    }

    private function expenseCategory(int $tenantId, array $headers, string $accountCode): int
    {
        $account = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', $accountCode)->value('id');

        return (int) $this->postJson('/api/v1/finance/expense-categories', ['code' => 'D2CAT-'.uniqid(), 'name' => 'D2 Category', 'financialAccountId' => $account, 'isActive' => true], $headers)->assertCreated()->json('data.id');
    }

    private function ownerHeaders(int $tenantId): array
    {
        $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'D2 Owner', 'email' => "d2-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $token = "d2-owner-$tenantId-$userId";
        DB::table('api_tokens')->insert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'd2-owner', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenantId];
    }

    private function cashierHeaders(int $tenantId, int $branchId, string $tag): array
    {
        $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'D2 Cashier', 'email' => "$tag-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'cashier', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('user_branches')->insert(['tenant_id' => $tenantId, 'user_id' => $userId, 'branch_id' => $branchId, 'created_at' => now(), 'updated_at' => now()]);
        // finance.supplier_payments.* is an opt-in per-tenant grant for cashiers
        // (not on by default — see FinanceAccess::defaultPermissionsForRole).
        foreach (['finance.supplier_payments.create', 'finance.supplier_payments.view'] as $permission) {
            DB::table('finance_role_permissions')->updateOrInsert(['tenant_id' => $tenantId, 'role' => 'cashier', 'permission' => $permission], ['created_at' => now(), 'updated_at' => now()]);
        }
        $token = "$tag-$tenantId-$userId";
        DB::table('api_tokens')->insert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => $tag, 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenantId];
    }

    private function fundDrawer(int $tenantId, int $branchId, array $ownerHeaders, string $amount): void
    {
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $this->mainSafe($tenantId),
            'toFinancialLocationId' => $this->drawer($branchId),
            'amount' => $amount,
            'transferDate' => '2026-09-01',
            'idempotencyKey' => 'd2-fund-'.$tenantId.'-'.$branchId,
        ], $ownerHeaders)->assertCreated();
    }
}
