<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Phase 5 — Suppliers / Accounts Payable. A Supplier Invoice is the AP
 * business record (not the journal itself, mirroring Expense's Phase 3
 * principle); a Supplier Payment settles one or more invoices through
 * money-critical allocation. Supplier balance is always derived from
 * posted-family invoices minus their allocations — never a stored column.
 */
class SupplierAccountsPayableApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_supplier_crud_generates_a_readable_code_and_enforces_tenant_isolation(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);

        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'Acme Roasters', 'phone' => '0999', 'paymentTermsDays' => 30], $headers)
            ->assertCreated()->assertJsonPath('data.supplierNumber', 'SUP-00001')->assertJsonPath('data.isActive', true);
        $id = $supplier->json('data.id');

        $second = $this->postJson('/api/v1/finance/suppliers', ['name' => 'Second Supplier'], $headers)->assertCreated();
        $this->assertSame('SUP-00002', $second->json('data.supplierNumber'));

        $this->patchJson("/api/v1/finance/suppliers/{$id}", ['name' => 'Acme Roasters Ltd', 'paymentTermsDays' => 45], $headers)
            ->assertOk()->assertJsonPath('data.name', 'Acme Roasters Ltd')->assertJsonPath('data.paymentTermsDays', 45);
        $this->patchJson("/api/v1/finance/suppliers/{$id}/status", ['isActive' => false], $headers)->assertOk()->assertJsonPath('data.isActive', false);

        $tenantB = $this->createTenant('supplier-tenant-b');
        $this->getJson('/api/v1/finance/suppliers', $this->headers($tenantB))->assertOk()->assertJsonMissing(['id' => $id]);
        $this->getJson("/api/v1/finance/suppliers/{$id}", $this->headers($tenantB))->assertNotFound();

        // An inactive supplier cannot be used on a new invoice.
        $account = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6100')->value('id');
        $category = $this->postJson('/api/v1/finance/expense-categories', ['code' => 'SUPPTEST', 'name' => 'Supplies', 'financialAccountId' => $account, 'isActive' => true], $headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/finance/supplier-invoices', $this->invoicePayload($id, $category, '100.00'), $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('supplierId');
    }

    public function test_expense_invoice_posts_a_balanced_ap_journal_and_becomes_immutable(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId, $categoryId] = $this->supplierAndCategory($tenant, $headers);

        $draft = $this->postJson('/api/v1/finance/supplier-invoices', $this->invoicePayload($supplierId, $categoryId, '500.00', tax: '50.00'), $headers)
            ->assertCreated()->assertJsonPath('data.status', 'draft')->assertJsonPath('data.totalAmount', '550.00');
        $id = $draft->json('data.id');

        $this->patchJson("/api/v1/finance/supplier-invoices/{$id}", $this->invoicePayload($supplierId, $categoryId, '600.00'), $headers)
            ->assertOk()->assertJsonPath('data.totalAmount', '600.00');

        $posted = $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'inv-post-1'], $headers)
            ->assertOk()->assertJsonPath('data.status', 'posted');
        $journalId = $posted->json('data.journalEntryId');
        $this->assertNotNull($journalId);

        $entry = DB::table('journal_entries')->where('id', $journalId)->first();
        $this->assertSame('posted', $entry->status);
        $this->assertSame('supplier_invoice', $entry->source_type);
        $this->assertSame($id, (int) $entry->source_id);
        $this->assertSame('SUPPLIER_INVOICE_POSTED', $entry->source_event);
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journalId)->get();
        $this->assertSame(600.0, (float) $lines->sum('debit'));
        $this->assertSame(600.0, (float) $lines->sum('credit'));
        $expenseAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6100')->value('id');
        $apAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '2000')->value('id');
        $this->assertSame(600.0, (float) $lines->firstWhere('financial_account_id', $expenseAccountId)->debit);
        $this->assertSame(600.0, (float) $lines->firstWhere('financial_account_id', $apAccountId)->credit);

        // Posting replay is idempotent; posted invoice is immutable.
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'inv-post-1'], $headers)->assertOk()->assertJsonPath('data.journalEntryId', $journalId);
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'supplier_invoice')->where('source_id', $id)->count());
        $this->patchJson("/api/v1/finance/supplier-invoices/{$id}", $this->invoicePayload($supplierId, $categoryId, '1.00'), $headers)->assertUnprocessable();
    }

    public function test_inventory_type_invoice_posts_ap_liability_without_creating_any_stock_movement(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId] = $this->supplierAndCategory($tenant, $headers);
        $beforeMovementCount = DB::table('stock_movements')->where('tenant_id', $tenant)->count();

        $payload = ['supplierId' => $supplierId, 'invoiceNumber' => 'SUP-INV-INV-1', 'invoiceDate' => '2026-08-20', 'dueDate' => '2026-09-20', 'invoiceType' => 'inventory', 'subtotal' => '300.00'];
        $draft = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated();
        $id = $draft->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'inv-post-inventory-1'], $headers)->assertOk();

        $inventoryAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id');
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', DB::table('supplier_invoices')->where('id', $id)->value('journal_entry_id'))->get();
        $this->assertSame(300.0, (float) $lines->firstWhere('financial_account_id', $inventoryAccountId)->debit);
        $this->assertSame($beforeMovementCount, DB::table('stock_movements')->where('tenant_id', $tenant)->count(), 'A supplier invoice must never create a stock movement.');
    }

    public function test_other_type_invoice_rejects_the_inventory_asset_account_and_wrong_tenant_accounts(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId] = $this->supplierAndCategory($tenant, $headers);
        $inventoryAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id');
        $apAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '2000')->value('id');

        $base = ['supplierId' => $supplierId, 'invoiceNumber' => 'SUP-INV-OTHER-1', 'invoiceDate' => '2026-08-20', 'dueDate' => '2026-09-20', 'invoiceType' => 'other', 'subtotal' => '80.00'];
        $this->postJson('/api/v1/finance/supplier-invoices', [...$base, 'debitAccountId' => $inventoryAccountId], $headers)->assertUnprocessable()->assertJsonValidationErrors('debitAccountId');
        $this->postJson('/api/v1/finance/supplier-invoices', [...$base, 'debitAccountId' => $apAccountId], $headers)->assertUnprocessable()->assertJsonValidationErrors('debitAccountId');

        $tenantB = $this->createTenant('other-account-tenant');
        $foreignAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenantB)->where('code', '6100')->value('id');
        $this->postJson('/api/v1/finance/supplier-invoices', [...$base, 'debitAccountId' => $foreignAccountId], $headers)->assertUnprocessable()->assertJsonValidationErrors('debitAccountId');

        $costOfSalesAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5000')->value('id');
        $this->postJson('/api/v1/finance/supplier-invoices', [...$base, 'debitAccountId' => $costOfSalesAccountId], $headers)->assertCreated();
    }

    public function test_overdue_flag_is_derived_not_persisted(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId, $categoryId] = $this->supplierAndCategory($tenant, $headers);

        $payload = $this->invoicePayload($supplierId, $categoryId, '100.00');
        $payload['invoiceDate'] = '2020-01-01';
        $payload['dueDate'] = '2020-02-01'; // both well before "today"
        $draft = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated();
        $id = $draft->json('data.id');

        // Draft invoices carry no liability yet, so they are never "overdue".
        $this->getJson("/api/v1/finance/supplier-invoices/{$id}", $headers)->assertOk()->assertJsonPath('data.isOverdue', false);
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'inv-overdue-1'], $headers)->assertOk();
        $this->getJson("/api/v1/finance/supplier-invoices/{$id}", $headers)->assertOk()->assertJsonPath('data.isOverdue', true);
    }

    public function test_partial_then_full_payment_updates_status_and_remaining_correctly(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId, $categoryId] = $this->supplierAndCategory($tenant, $headers);
        $invoiceId = $this->postedInvoice($tenant, $headers, $supplierId, $categoryId, '500.00');

        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $balanceBefore = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$locationId.'/transactions', $headers)->json('data.location.balance');

        $first = $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplierId, 'paymentDate' => '2026-08-21', 'amount' => '200.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-partial-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '200.00']],
        ], $headers)->assertCreated()->assertJsonPath('data.status', 'posted');

        $this->getJson("/api/v1/finance/supplier-invoices/{$invoiceId}", $headers)
            ->assertOk()->assertJsonPath('data.status', 'partially_paid')->assertJsonPath('data.remainingAmount', '300.00');

        $second = $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplierId, 'paymentDate' => '2026-08-22', 'amount' => '300.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-partial-2',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '300.00']],
        ], $headers)->assertCreated();
        $this->assertNotSame($first->json('data.id'), $second->json('data.id'));

        $this->getJson("/api/v1/finance/supplier-invoices/{$invoiceId}", $headers)
            ->assertOk()->assertJsonPath('data.status', 'paid')->assertJsonPath('data.remainingAmount', '0.00');

        $balanceAfter = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$locationId.'/transactions', $headers)->json('data.location.balance');
        $this->assertSame(round($balanceBefore - 500.0, 2), round($balanceAfter, 2));

        // Overpaying an allocation beyond the invoice's now-zero remaining is rejected.
        $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplierId, 'paymentDate' => '2026-08-23', 'amount' => '1.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-overpay-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '1.00']],
        ], $headers)->assertUnprocessable();
    }

    public function test_one_payment_allocates_across_two_invoices_and_supports_the_documented_statement_scenario(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId, $categoryId] = $this->supplierAndCategory($tenant, $headers);
        $invoiceA = $this->postedInvoice($tenant, $headers, $supplierId, $categoryId, '300.00');
        $invoiceB = $this->postedInvoice($tenant, $headers, $supplierId, $categoryId, '500.00');

        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');

        $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplierId, 'paymentDate' => '2026-08-21', 'amount' => '600.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-multi-1',
            'allocations' => [['invoiceId' => $invoiceA, 'amount' => '300.00'], ['invoiceId' => $invoiceB, 'amount' => '300.00']],
        ], $headers)->assertCreated();

        $this->getJson("/api/v1/finance/supplier-invoices/{$invoiceA}", $headers)->assertOk()->assertJsonPath('data.status', 'paid');
        $this->getJson("/api/v1/finance/supplier-invoices/{$invoiceB}", $headers)->assertOk()->assertJsonPath('data.status', 'partially_paid')->assertJsonPath('data.remainingAmount', '200.00');
        $this->assertSame('200.00', $this->getJson("/api/v1/finance/suppliers/{$supplierId}", $headers)->json('data.outstandingBalance'));

        // docs/finance §44 scenario: Invoice 1000, Payment 400, Invoice 500, Payment 300 -> outstanding 800.
        $tenant2 = $this->demoTenantId();
        $headers2 = $this->headers($tenant2);
        [$supplier2, $category2] = $this->supplierAndCategory($tenant2, $headers2, unique: true);
        $inv1 = $this->postedInvoice($tenant2, $headers2, $supplier2, $category2, '1000.00');
        $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplier2, 'paymentDate' => '2026-08-21', 'amount' => '400.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'stmt-pay-1',
            'allocations' => [['invoiceId' => $inv1, 'amount' => '400.00']],
        ], $headers2)->assertCreated();
        $inv2 = $this->postedInvoice($tenant2, $headers2, $supplier2, $category2, '500.00');
        $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplier2, 'paymentDate' => '2026-08-22', 'amount' => '300.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'stmt-pay-2',
            'allocations' => [['invoiceId' => $inv2, 'amount' => '300.00']],
        ], $headers2)->assertCreated();

        $profile = $this->getJson("/api/v1/finance/suppliers/{$supplier2}", $headers2)->assertOk();
        $this->assertSame('800.00', $profile->json('data.outstandingBalance'));
        $statement = $this->getJson("/api/v1/finance/suppliers/{$supplier2}/statement", $headers2)->assertOk();
        $lines = $statement->json('data.lines');
        $this->assertSame('800.00', end($lines)['runningBalance']);
        // Each line must carry the source invoice/payment id so the Flutter
        // statement can drill down to the exact record, not just its reference text.
        $this->assertSame($inv1, $lines[0]['id']);
        $this->assertSame('invoice', $lines[0]['type']);
    }

    public function test_allocation_across_different_supplier_or_tenant_invoice_is_rejected(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId, $categoryId] = $this->supplierAndCategory($tenant, $headers);
        [$otherSupplierId] = $this->supplierAndCategory($tenant, $headers, unique: true);
        $foreignInvoice = $this->postedInvoice($tenant, $headers, $otherSupplierId, $categoryId, '100.00');

        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');

        $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplierId, 'paymentDate' => '2026-08-21', 'amount' => '50.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-wrong-supplier-1',
            'allocations' => [['invoiceId' => $foreignInvoice, 'amount' => '50.00']],
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('allocations');
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->where('idempotency_key', 'pay-wrong-supplier-1')->count());
    }

    public function test_supplier_payment_idempotency_replay_and_conflict(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId, $categoryId] = $this->supplierAndCategory($tenant, $headers);
        $invoiceId = $this->postedInvoice($tenant, $headers, $supplierId, $categoryId, '200.00');
        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $payload = ['supplierId' => $supplierId, 'paymentDate' => '2026-08-21', 'amount' => '200.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-idem-1', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '200.00']]];

        $first = $this->postJson('/api/v1/finance/supplier-payments', $payload, $headers)->assertCreated();
        $this->postJson('/api/v1/finance/supplier-payments', $payload, $headers)->assertCreated()->assertJsonPath('data.id', $first->json('data.id'));
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'supplier_payment')->where('source_id', $first->json('data.id'))->count());

        $this->postJson('/api/v1/finance/supplier-payments', [...$payload, 'amount' => '150.00', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '150.00']]], $headers)->assertConflict();
    }

    public function test_reversing_a_posted_invoice_with_no_allocations_is_allowed_but_blocked_once_allocated(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId, $categoryId] = $this->supplierAndCategory($tenant, $headers);
        $invoiceId = $this->postedInvoice($tenant, $headers, $supplierId, $categoryId, '150.00');

        $unallocated = $this->postJson("/api/v1/finance/supplier-invoices/{$invoiceId}/reverse", [], $headers)->assertOk();
        $this->assertSame('cancelled', $unallocated->json('data.status'));
        $original = DB::table('journal_entries')->where('id', $unallocated->json('data.journalEntryId'))->first();
        $this->assertSame('posted', $original->status, 'The original journal entry must stay posted.');

        $allocatedInvoiceId = $this->postedInvoice($tenant, $headers, $supplierId, $categoryId, '150.00');
        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplierId, 'paymentDate' => '2026-08-21', 'amount' => '150.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId,
            'idempotencyKey' => 'pay-block-reverse-1', 'allocations' => [['invoiceId' => $allocatedInvoiceId, 'amount' => '150.00']],
        ], $headers)->assertCreated();
        $this->postJson("/api/v1/finance/supplier-invoices/{$allocatedInvoiceId}/reverse", [], $headers)->assertUnprocessable();
    }

    public function test_reversing_a_supplier_payment_restores_invoice_balance_and_cash(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        [$supplierId, $categoryId] = $this->supplierAndCategory($tenant, $headers);
        $invoiceId = $this->postedInvoice($tenant, $headers, $supplierId, $categoryId, '400.00');
        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $balanceBeforePay = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$locationId.'/transactions', $headers)->json('data.location.balance');

        $payment = $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplierId, 'paymentDate' => '2026-08-21', 'amount' => '400.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId,
            'idempotencyKey' => 'pay-reverse-1', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '400.00']],
        ], $headers)->assertCreated();
        $this->getJson("/api/v1/finance/supplier-invoices/{$invoiceId}", $headers)->assertOk()->assertJsonPath('data.status', 'paid');

        $reversed = $this->postJson("/api/v1/finance/supplier-payments/{$payment->json('data.id')}/reverse", [], $headers)->assertOk();
        $this->assertSame('reversed', $reversed->json('data.status'));

        $this->getJson("/api/v1/finance/supplier-invoices/{$invoiceId}", $headers)->assertOk()->assertJsonPath('data.status', 'posted')->assertJsonPath('data.remainingAmount', '400.00');
        $this->assertSame(0, DB::table('payment_allocations')->where('tenant_id', $tenant)->where('supplier_payment_id', $payment->json('data.id'))->count());
        $balanceAfterReversal = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$locationId.'/transactions', $headers)->json('data.location.balance');
        $this->assertSame(round($balanceBeforePay, 2), round($balanceAfterReversal, 2));

        $this->postJson("/api/v1/finance/supplier-payments/{$payment->json('data.id')}/reverse", [], $headers)->assertUnprocessable();
    }

    private function invoicePayload(int $supplierId, int $categoryId, string $subtotal, string $tax = '0.00'): array
    {
        return [
            'supplierId' => $supplierId, 'invoiceNumber' => 'SUP-INV-'.uniqid(), 'invoiceDate' => '2026-08-20', 'dueDate' => '2026-09-20',
            'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId, 'subtotal' => $subtotal, 'taxAmount' => $tax,
        ];
    }

    private function supplierAndCategory(int $tenant, array $headers, bool $unique = false): array
    {
        $supplierId = $this->postJson('/api/v1/finance/suppliers', ['name' => 'Supplier '.uniqid()], $headers)->assertCreated()->json('data.id');
        $account = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6100')->value('id');
        $code = $unique ? 'CAT-'.uniqid() : 'APCAT-'.uniqid();
        $categoryId = $this->postJson('/api/v1/finance/expense-categories', ['code' => $code, 'name' => 'AP Category', 'financialAccountId' => $account, 'isActive' => true], $headers)->assertCreated()->json('data.id');

        return [$supplierId, $categoryId];
    }

    private function postedInvoice(int $tenant, array $headers, int $supplierId, int $categoryId, string $subtotal): int
    {
        $draft = $this->postJson('/api/v1/finance/supplier-invoices', $this->invoicePayload($supplierId, $categoryId, $subtotal), $headers)->assertCreated();
        $id = $draft->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'invoice-post-'.uniqid()], $headers)->assertOk();

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
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Finance Owner', 'email' => "supplier-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $plainToken = "supplier-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'supplier-feature-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
