<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Phase 3 — Customer Payments / AR allocations / settlement. CustomerPayment
 * is the sole AR settlement record (ADR-04): it creates exactly one journal
 * (Dr cash/bank; Cr Accounts Receivable) and never touches Sales Revenue,
 * Sales Tax, COGS or Inventory — those remain solely SalesInvoicePostingService
 * effects at invoice posting (Phase 2). Outstanding balance is always
 * derived from posted invoice total minus posted payment allocations, never
 * a stored column (mirrors SupplierAccountsPayableApiTest for AP).
 */
class CustomerPaymentApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_full_cash_payment_settles_invoice_and_posts_a_balanced_ar_journal(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '300.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);

        $payment = $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '300.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-full-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '300.00']],
        ], $s['headers'])->assertCreated()->assertJsonPath('data.status', 'posted')->assertJsonPath('data.paymentNumber', 'CR-'.now()->year.'-000001');

        $journalId = $payment->json('data.journalEntryId');
        $this->assertNotNull($journalId);
        $entry = DB::table('journal_entries')->where('id', $journalId)->first();
        $this->assertSame('posted', $entry->status);
        $this->assertSame('customer_payment', $entry->source_type);
        $this->assertSame('CUSTOMER_PAYMENT_POSTED', $entry->source_event);
        $lines = DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journalId)->select('a.code', 'l.debit', 'l.credit')->get()->keyBy('code');
        $this->assertSame('300.00', $lines['1010']->debit);
        $this->assertSame('300.00', $lines['1200']->credit);

        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()
            ->assertJsonPath('data.paymentStatus', 'paid')->assertJsonPath('data.paidAmount', '300.00')->assertJsonPath('data.remainingAmount', '0.00')
            ->assertJsonPath('data.allowedActions.canRegisterPayment', false)
            ->assertJsonPath('data.collections.0.paymentNumber', $payment->json('data.paymentNumber'))->assertJsonPath('data.collections.0.amount', '300.00');
    }

    public function test_partial_cash_then_full_bank_payment_completes_the_invoice(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '300.00');
        [$cashMethod, $cashLocation] = $this->cashMethodAndLocation($s['tenant']);
        [$bankMethod, $bankLocation] = $this->bankMethodAndLocation($s);

        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '100.00',
            'paymentMethodId' => $cashMethod, 'financialLocationId' => $cashLocation, 'idempotencyKey' => 'pay-partial-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '100.00']],
        ], $s['headers'])->assertCreated();

        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()
            ->assertJsonPath('data.paymentStatus', 'partial')->assertJsonPath('data.paidAmount', '100.00')->assertJsonPath('data.remainingAmount', '200.00')
            ->assertJsonPath('data.allowedActions.canRegisterPayment', true);

        $second = $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-14', 'amount' => '200.00',
            'paymentMethodId' => $bankMethod, 'financialLocationId' => $bankLocation, 'idempotencyKey' => 'pay-partial-2',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '200.00']],
        ], $s['headers'])->assertCreated();
        $lines = DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $second->json('data.journalEntryId'))->select('a.code', 'l.debit')->get()->keyBy('code');
        $this->assertSame('200.00', $lines['1030']->debit, 'The second (bank) receipt must debit the Bank account, not Cash.');

        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()
            ->assertJsonPath('data.paymentStatus', 'paid')->assertJsonPath('data.remainingAmount', '0.00')->assertJsonPath('data.allowedActions.canRegisterPayment', false);

        // Second payment must not create any Revenue/COGS/Inventory effect (§8).
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->where('source_id', $invoiceId)->count());
    }

    public function test_one_payment_allocates_across_two_invoices_and_leaves_documented_remainder(): void
    {
        $s = $this->scenario();
        $invoiceA = $this->postedInvoice($s, '300.00');
        $invoiceB = $this->postedInvoice($s, '150.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);

        // docs §9/§26 scenario: Invoice A=300, Invoice B=150, Payment=350 -> 300 to A, 50 to B, B remaining 100.
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '350.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-multi-1',
            'allocations' => [['invoiceId' => $invoiceA, 'amount' => '300.00'], ['invoiceId' => $invoiceB, 'amount' => '50.00']],
        ], $s['headers'])->assertCreated();

        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceA}", $s['headers'])->assertOk()->assertJsonPath('data.paymentStatus', 'paid');
        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceB}", $s['headers'])->assertOk()->assertJsonPath('data.paymentStatus', 'partial')->assertJsonPath('data.remainingAmount', '100.00');
    }

    public function test_many_payments_against_one_invoice_each_reduce_remaining(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '100.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        foreach (['30.00', '30.00', '40.00'] as $i => $amount) {
            $this->postJson('/api/v1/finance/customer-payments', [
                'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => $amount,
                'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => "pay-many-{$i}",
                'allocations' => [['invoiceId' => $invoiceId, 'amount' => $amount]],
            ], $s['headers'])->assertCreated();
        }
        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()->assertJsonPath('data.paymentStatus', 'paid')->assertJsonPath('data.remainingAmount', '0.00');
        $this->assertSame(3, DB::table('customer_payments')->where('tenant_id', $s['tenant'])->where('status', 'posted')->count());
    }

    public function test_over_allocation_beyond_remaining_is_rejected_and_serializes_concurrent_settlement(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '100.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);

        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '100.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-over-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '100.00']],
        ], $s['headers'])->assertCreated();

        // §25 concurrency proxy: a second payment racing for the same now-exhausted 100 remaining must fail, never drive remaining negative.
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '1.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-over-2',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '1.00']],
        ], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('allocations');
        $this->assertSame('0.00', $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->json('data.remainingAmount'));

        $direct = $this->postedInvoice($s, '100.00');
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '150.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-over-3',
            'allocations' => [['invoiceId' => $direct, 'amount' => '150.00']],
        ], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('allocations');
    }

    public function test_allocation_total_must_equal_payment_amount_exactly(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '100.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);

        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '100.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-mismatch-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '60.00']],
        ], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('allocations');
        $this->assertSame(0, DB::table('customer_payments')->where('tenant_id', $s['tenant'])->where('idempotency_key', 'pay-mismatch-1')->count());
    }

    public function test_allocation_against_a_different_customers_invoice_is_rejected(): void
    {
        $s = $this->scenario();
        $otherCustomer = $this->postJson('/api/v1/finance/customers', ['name' => 'Other Customer'], $s['headers'])->assertCreated()->json('data.id');
        $foreignInvoice = $this->postedInvoice($s, '100.00', $otherCustomer);
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);

        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '100.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-wrong-customer-1',
            'allocations' => [['invoiceId' => $foreignInvoice, 'amount' => '100.00']],
        ], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('allocations');
    }

    public function test_draft_and_fully_paid_invoices_cannot_receive_allocations(): void
    {
        $s = $this->scenario();
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);

        $product = $this->productPriced($s, '50.00');
        $draftId = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $product, 'quantity' => '1']]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '50.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-draft-1',
            'allocations' => [['invoiceId' => $draftId, 'amount' => '50.00']],
        ], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('allocations');

        $paidId = $this->postedInvoice($s, '50.00');
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '50.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-fill-1',
            'allocations' => [['invoiceId' => $paidId, 'amount' => '50.00']],
        ], $s['headers'])->assertCreated();
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '10.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-already-paid-1',
            'allocations' => [['invoiceId' => $paidId, 'amount' => '10.00']],
        ], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('allocations');
    }

    public function test_customer_payment_idempotency_replay_and_conflict(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '200.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $payload = ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '200.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-idem-1', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '200.00']]];

        $first = $this->postJson('/api/v1/finance/customer-payments', $payload, $s['headers'])->assertCreated();
        $this->postJson('/api/v1/finance/customer-payments', $payload, $s['headers'])->assertCreated()->assertJsonPath('data.id', $first->json('data.id'));
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'customer_payment')->where('source_id', $first->json('data.id'))->count());
        $this->assertSame(1, DB::table('customer_payment_allocations')->where('tenant_id', $s['tenant'])->where('customer_payment_id', $first->json('data.id'))->count());

        $this->postJson('/api/v1/finance/customer-payments', [...$payload, 'amount' => '150.00', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '150.00']]], $s['headers'])->assertConflict();
    }

    public function test_preview_makes_zero_state_changes_and_matches_the_following_post(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '300.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $payload = ['customerId' => $s['customer'], 'amount' => '120.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '120.00']]];

        $before = ['payments' => DB::table('customer_payments')->count(), 'allocations' => DB::table('customer_payment_allocations')->count(), 'journals' => DB::table('journal_entries')->count()];
        $preview = $this->postJson('/api/v1/finance/customer-payments/preview', $payload, $s['headers'])->assertOk()
            ->assertJsonPath('data.amount', '120.00')->assertJsonPath('data.accounting.creditAmount', '120.00')->assertJsonPath('data.accounting.creditAccountCode', '1200')->assertJsonPath('data.accounting.debitAccountCode', '1010')
            ->assertJsonPath('data.allocations.0.remainingBefore', '300.00')->assertJsonPath('data.allocations.0.remainingAfter', '180.00')->assertJsonPath('data.allocations.0.paymentStatusAfter', 'partial');
        $after = ['payments' => DB::table('customer_payments')->count(), 'allocations' => DB::table('customer_payment_allocations')->count(), 'journals' => DB::table('journal_entries')->count()];
        $this->assertSame($before, $after, 'Preview must make zero state changes.');

        $this->postJson('/api/v1/finance/customer-payments', [...$payload, 'branchId' => $s['branch'], 'paymentDate' => '2026-09-12', 'idempotencyKey' => 'pay-preview-then-post'], $s['headers'])->assertCreated();
        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '180.00')->assertJsonPath('data.paymentStatus', 'partial');
    }

    public function test_reversing_a_customer_payment_restores_ar_and_cash_without_deleting_the_payment(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '400.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $payment = $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '400.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-reverse-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '400.00']],
        ], $s['headers'])->assertCreated();
        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()->assertJsonPath('data.paymentStatus', 'paid');

        $reversed = $this->postJson("/api/v1/finance/customer-payments/{$payment->json('data.id')}/reverse", [], $s['headers'])->assertOk();
        $this->assertSame('reversed', $reversed->json('data.status'));
        $this->assertNotNull($reversed->json('data.reversalJournalEntryId'));

        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()->assertJsonPath('data.paymentStatus', 'unpaid')->assertJsonPath('data.remainingAmount', '400.00');
        $this->assertSame(0, DB::table('customer_payment_allocations')->where('tenant_id', $s['tenant'])->where('customer_payment_id', $payment->json('data.id'))->count());
        $this->assertSame(1, DB::table('customer_payment_allocation_history')->where('tenant_id', $s['tenant'])->where('customer_payment_id', $payment->json('data.id'))->count());

        $reversal = DB::table('journal_entries')->where('id', $reversed->json('data.reversalJournalEntryId'))->first();
        $lines = DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $reversal->id)->select('a.code', 'l.debit', 'l.credit')->get()->keyBy('code');
        $this->assertSame('400.00', $lines['1200']->debit, 'Reversal must debit AR back open.');
        $this->assertSame('400.00', $lines['1010']->credit, 'Reversal must credit Cash back out.');

        // Never delete the original payment; posting it again must be refused.
        $this->assertSame('reversed', DB::table('customer_payments')->where('id', $payment->json('data.id'))->value('status'));
        $this->postJson("/api/v1/finance/customer-payments/{$payment->json('data.id')}/reverse", [], $s['headers'])->assertUnprocessable();
    }

    public function test_tenant_and_branch_isolation_for_customers_accounts_and_payments(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '100.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $payment = $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '100.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-isolation-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '100.00']],
        ], $s['headers'])->assertCreated()->json('data.id');

        $other = $this->scenario();
        $this->getJson("/api/v1/finance/customer-payments/{$payment}", $other['headers'])->assertNotFound();
        $this->getJson('/api/v1/finance/customer-payments', $other['headers'])->assertOk()->assertJsonMissing(['id' => $payment]);
        // Tenant B cannot pay Tenant A's customer/invoice/account even by guessing raw ids.
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $other['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '1.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-cross-tenant-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '1.00']],
        ], $other['headers'])->assertUnprocessable();
    }

    public function test_permission_denied_without_customer_payments_create_permission(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '50.00');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        DB::table('users')->where('id', $s['owner'])->update(['role' => 'staff']);

        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '50.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-denied-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '50.00']],
        ], $s['headers'])->assertForbidden();
    }

    public function test_customer_receivables_list_orders_open_invoices_oldest_due_first_for_auto_allocation(): void
    {
        $s = $this->scenario();
        $newest = $this->postedInvoiceWithDueDate($s, '100.00', '2026-12-01');
        $oldest = $this->postedInvoiceWithDueDate($s, '50.00', '2026-01-01');
        $middle = $this->postedInvoiceWithDueDate($s, '75.00', '2026-06-01');

        $response = $this->getJson("/api/v1/finance/customers/{$s['customer']}/receivables", $s['headers'])->assertOk();
        $this->assertSame([$oldest, $middle, $newest], collect($response->json('data.openInvoices'))->pluck('id')->all());
        $this->assertSame('225.00', $response->json('data.outstanding'));

        $overview = $this->getJson('/api/v1/finance/customers-receivables', $s['headers'])->assertOk();
        $this->assertSame('225.00', collect($overview->json('data'))->firstWhere('customerId', $s['customer'])['outstanding']);
    }

    public function test_immediate_payment_ux_posts_invoice_and_collects_in_one_outer_transaction(): void
    {
        $s = $this->scenario();
        $product = $this->productPriced($s, '80.00');
        $invoiceId = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $product, 'quantity' => '1']]], $s['headers'])->assertCreated()->json('data.id');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);

        $this->postJson("/api/v1/finance/sales-invoices/{$invoiceId}/post-and-collect", [
            'postIdempotencyKey' => 'immediate-post-1', 'paymentDate' => '2026-09-12', 'amount' => '80.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'paymentIdempotencyKey' => 'immediate-pay-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '80.00']],
        ], $s['headers'])->assertOk();

        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()->assertJsonPath('data.status', 'posted')->assertJsonPath('data.paymentStatus', 'paid')->assertJsonPath('data.remainingAmount', '0.00');
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->where('source_id', $invoiceId)->count());
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'customer_payment')->count());

        // A failing settlement (bad location/method mismatch) must roll back the invoice post too.
        $product2 = $this->productPriced($s, '80.00');
        $invoice2 = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $product2, 'quantity' => '1']]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice2}/post-and-collect", [
            'postIdempotencyKey' => 'immediate-post-2', 'paymentDate' => '2026-09-12', 'amount' => '80.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => 999999, 'paymentIdempotencyKey' => 'immediate-pay-2',
            'allocations' => [['invoiceId' => $invoice2, 'amount' => '80.00']],
        ], $s['headers'])->assertUnprocessable();
        $this->assertSame('draft', DB::table('sales_invoices')->where('id', $invoice2)->value('status'), 'A failed collection must roll back the invoice posting too.');
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_id', $invoice2)->count());
    }

    /** §43 critical accounting regression: a Customer Payment must add exactly one Dr cash/bank / Cr AR effect and change nothing else. */
    public function test_critical_regression_customer_payment_never_touches_revenue_cogs_or_inventory(): void
    {
        $s = $this->scenario(tracked: true);
        $invoiceId = $this->postedInvoice($s, '100.00');
        $revenueBefore = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count();
        $cogsAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $s['tenant'])->where('code', '5000')->value('id');
        $cogsLinesBefore = DB::table('journal_entry_lines')->where('financial_account_id', $cogsAccountId)->count();
        $movementsBefore = DB::table('stock_movements')->where('tenant_id', $s['tenant'])->count();

        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '100.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-regression-1',
            'allocations' => [['invoiceId' => $invoiceId, 'amount' => '100.00']],
        ], $s['headers'])->assertCreated();

        $this->assertSame($revenueBefore, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count(), 'No new sales_invoice (revenue) journal.');
        $this->assertSame($cogsLinesBefore, DB::table('journal_entry_lines')->where('financial_account_id', $cogsAccountId)->count(), 'No new COGS line.');
        $this->assertSame($movementsBefore, DB::table('stock_movements')->where('tenant_id', $s['tenant'])->count(), 'No new stock movement.');
        $this->assertSame(0, DB::table('orders')->where('tenant_id', $s['tenant'])->count(), 'No POS order created.');
        $this->assertSame(0, DB::table('payments')->where('tenant_id', $s['tenant'])->count(), 'No POS payment created.');
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'customer_payment')->count(), 'Exactly one settlement journal.');
    }

    /** §44 critical end-to-end: Invoice 300 -> Cash 100 -> Bank 200 -> Paid, with Revenue/COGS/Inventory only ever touched at invoice posting. */
    public function test_critical_end_to_end_full_lifecycle_matches_the_documented_example(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '300.00');
        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()->assertJsonPath('data.receivableAmount', '300.00')->assertJsonPath('data.remainingAmount', '300.00');
        $revenueJournals = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count();

        [$cashMethod, $cashLocation] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-13', 'amount' => '100.00', 'paymentMethodId' => $cashMethod, 'financialLocationId' => $cashLocation, 'idempotencyKey' => 'e2e-pay-1', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '100.00']]], $s['headers'])->assertCreated();
        $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '200.00')->assertJsonPath('data.paymentStatus', 'partial');
        $this->assertSame($revenueJournals, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count());

        [$bankMethod, $bankLocation] = $this->bankMethodAndLocation($s);
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-14', 'amount' => '200.00', 'paymentMethodId' => $bankMethod, 'financialLocationId' => $bankLocation, 'idempotencyKey' => 'e2e-pay-2', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '200.00']]], $s['headers'])->assertCreated();
        $final = $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk();
        $this->assertSame('0.00', $final->json('data.remainingAmount'));
        $this->assertSame('paid', $final->json('data.paymentStatus'));
        $this->assertSame($revenueJournals, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count(), 'Revenue must never be recognized twice.');
        $this->assertSame(2, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'customer_payment')->count());
    }

    public function test_daily_closing_reflects_customer_payment_cash_once_on_its_own_receipt_date(): void
    {
        $s = $this->scenario();
        $invoiceId = $this->postedInvoice($s, '300.00');
        [$cashMethod, $cashLocation] = $this->cashMethodAndLocation($s['tenant']);
        [$bankMethod, $bankLocation] = $this->bankMethodAndLocation($s);

        $day = $this->getJson('/api/v1/finance/daily-closing?date=2026-09-15&branchId='.$s['branch'], $s['headers'])->assertOk();
        $this->assertSame('0.00', $day->json('data.cash.customerPaymentsCash'), 'The credit invoice alone must not add any expected cash.');

        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-15', 'amount' => '100.00', 'paymentMethodId' => $cashMethod, 'financialLocationId' => $cashLocation, 'idempotencyKey' => 'closing-pay-cash-1', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '100.00']]], $s['headers'])->assertCreated();
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-15', 'amount' => '200.00', 'paymentMethodId' => $bankMethod, 'financialLocationId' => $bankLocation, 'idempotencyKey' => 'closing-pay-bank-1', 'allocations' => [['invoiceId' => $invoiceId, 'amount' => '200.00']]], $s['headers'])->assertCreated();

        $after = $this->getJson('/api/v1/finance/daily-closing?date=2026-09-15&branchId='.$s['branch'], $s['headers'])->assertOk();
        $this->assertSame('100.00', $after->json('data.cash.customerPaymentsCash'), 'Only the cash receipt increases expected drawer cash; the bank receipt must not.');
        $this->assertSame('300.00', $after->json('data.operations.customerPaymentsTotal'));
    }

    // ---- scenario builders -------------------------------------------------

    private function scenario(bool $tracked = false): array
    {
        $suffix = (string) str()->uuid();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Sales P3', 'slug' => "sales-p3-{$suffix}", 'status' => 'active', 'tax_rate' => '0.000000', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Downtown', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => "sales-p3-{$suffix}@test.local", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner);
        $token = "sales-p3-{$suffix}";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'sales-p3', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
        $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'Damascus Tech Company'], $headers)->assertCreated()->json('data.id');

        return compact('tenant', 'branch', 'owner', 'headers', 'customer');
    }

    private function productPriced(array $s, string $price, ?string $suffix = null): int
    {
        $suffix ??= (string) str()->uuid();

        return (int) DB::table('products')->insertGetId(['tenant_id' => $s['tenant'], 'name' => 'Service '.$suffix, 'name_ar' => 'خدمة', 'sku' => "SVC-{$suffix}", 'price' => $price, 'is_active' => true, 'is_stock_tracked' => false, 'inventory_controlled' => false, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function postedInvoice(array $s, string $total, ?int $customerId = null): int
    {
        $product = $this->productPriced($s, $total);
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $customerId ?? $s['customer'], 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $product, 'quantity' => '1']]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'invoice-post-'.uniqid()], $s['headers'])->assertOk();

        return (int) $invoice;
    }

    private function postedInvoiceWithDueDate(array $s, string $total, string $dueDate): int
    {
        $product = $this->productPriced($s, $total);
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-01-01', 'dueDate' => $dueDate, 'lines' => [['productId' => $product, 'quantity' => '1']]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'invoice-post-'.uniqid()], $s['headers'])->assertOk();

        return (int) $invoice;
    }

    /** @return array{0:int,1:int} [paymentMethodId, financialLocationId] */
    private function cashMethodAndLocation(int $tenant): array
    {
        $methodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');

        return [$methodId, $locationId];
    }

    /** Creates a real Bank payment method through the Finance settings API, matching the seeded BANK financial location/account. */
    private function bankMethodAndLocation(array $s): array
    {
        $locationId = (int) DB::table('financial_locations')->where('tenant_id', $s['tenant'])->where('code', 'BANK')->value('id');
        $accountId = (int) DB::table('financial_locations')->where('id', $locationId)->value('financial_account_id');
        $methodId = (int) $this->postJson('/api/v1/finance/payment-methods', [
            'code' => 'BANKTRF', 'name' => 'Bank Transfer', 'type' => 'bank_transfer', 'financialAccountId' => $accountId, 'financialLocationId' => $locationId, 'isActive' => true,
        ], $s['headers'])->assertCreated()->json('data.id');

        return [$methodId, $locationId];
    }
}
