<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryPostingService;
use App\Services\FinancialSetupService;
use App\Support\Money;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Phase 4 — Sales Credit Notes / Returns / Customer Refunds. Posted Sales
 * Invoices stay immutable (§1): a Credit Note is a separate, linked
 * document that reverses Revenue/Tax/AR (always) and COGS/Inventory (only
 * for restocked, accepted lines — ADR-01). AR never goes negative: any
 * credit beyond the invoice's outstanding balance becomes unapplied
 * customer credit, settled later by a separate Customer Refund that never
 * re-touches Revenue/COGS/Inventory.
 */
class SalesCreditNoteApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_partial_return_with_restock_reverses_revenue_tax_ar_cogs_and_inventory_proportionally(): void
    {
        $s = $this->scenario(tracked: true, opening: '100.000', taxRate: '0.080000');
        $invoice = $this->postedInvoice($s, '10');

        $preview = $this->postJson("/api/v1/finance/sales-credit-notes", $this->creditPayload($s, $invoice, 3, restock: true), $s['headers'])->assertCreated();
        $creditNoteId = $preview->json('data.id');

        $before = $this->snapshot($s['tenant']);
        $previewData = $this->getJson("/api/v1/finance/sales-credit-notes/{$creditNoteId}/posting-preview", $s['headers'])->assertOk()
            ->assertJsonPath('data.creditNote.subtotal', '30.00')->assertJsonPath('data.creditNote.total', '32.40')
            ->assertJsonPath('data.accounting.accountsReceivableCredit', '32.40')->assertJsonPath('data.accounting.customerCreditCredit', '0.00');
        $this->assertSame($before, $this->snapshot($s['tenant']), 'Preview must make zero state changes.');

        $posted = $this->postJson("/api/v1/finance/sales-credit-notes/{$creditNoteId}/post", ['idempotencyKey' => 'cn-post-1'], $s['headers'])->assertOk()
            ->assertJsonPath('data.status', 'posted')->assertJsonPath('data.arReductionAmount', '32.40')->assertJsonPath('data.customerCreditAmount', '0.00');
        $this->assertSame($previewData->json('data.creditNote'), ['subtotal' => $posted->json('data.subtotal'), 'tax' => $posted->json('data.taxTotal'), 'total' => $posted->json('data.total')], 'Preview and post must agree.');

        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->where('source_id', $creditNoteId)->sole();
        $lines = DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->select('a.code', 'l.debit', 'l.credit')->get()->keyBy('code');
        $this->assertSame('30.00', $lines['4020']->debit, 'Sales Returns debit = 3/10 of 100.00 subtotal.');
        $this->assertSame('2.40', $lines['2010']->debit, 'Tax reversal = 3/10 of 8.00 tax.');
        $this->assertSame('32.40', $lines['1200']->credit);
        $this->assertSame('6.00', $lines['5000']->credit, 'COGS reversal uses the ORIGINAL 2.00 unit cost, not any later WAC: 3 units * 2.00.');
        $this->assertSame('6.00', $lines['1100']->debit);

        $this->assertSame('93.000', DB::table('stock_balances')->where('tenant_id', $s['tenant'])->where('warehouse_id', $s['warehouse'])->where('inventory_item_id', $s['material'])->value('quantity_on_hand'), '100 opening - 10 sold + 3 restocked by this credit note.');

        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()
            ->assertJsonPath('data.remainingAmount', '75.60')->assertJsonPath('data.paymentStatus', 'unpaid')->assertJsonPath('data.creditStatus', 'partially_credited')
            ->assertJsonPath('data.creditNotes.0.creditNoteNumber', $posted->json('data.creditNoteNumber'));
    }

    public function test_over_return_is_rejected_at_create_and_cumulative_quantity_is_enforced_across_posted_notes(): void
    {
        $s = $this->scenario(tracked: true, opening: '100.000', taxRate: '0.080000');
        $invoice = $this->postedInvoice($s, '10');

        $cn1 = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 4, restock: true), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn1}/post", ['idempotencyKey' => 'cn-over-1'], $s['headers'])->assertOk();

        // Only 6 remain returnable (10 - 4); creating a draft for 7 is rejected immediately at create time.
        $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 7, restock: true), $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('lines.0.quantity');

        $cn2 = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 6, restock: true), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn2}/post", ['idempotencyKey' => 'cn-over-2'], $s['headers'])->assertOk();
        $this->assertSame('0.000', collect($this->getJson("/api/v1/finance/sales-invoices/{$invoice}/returnable-lines", $s['headers'])->assertOk()->json('data'))->first()['returnable']);
    }

    /** §23 mandatory concurrency scenario: two drafts both computed against the same returnable(10) snapshot; only one of two 6+6 posting attempts may succeed. */
    public function test_two_drafts_racing_for_the_same_returnable_balance_only_one_post_succeeds(): void
    {
        $s = $this->scenario(tracked: true, opening: '100.000', taxRate: '0.080000');
        $invoice = $this->postedInvoice($s, '10');

        // Both drafts are created while the full 10 units are still returnable (simulating two concurrent users).
        $draftA = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 6, restock: true), $s['headers'])->assertCreated()->json('data.id');
        $draftB = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 6, restock: true), $s['headers'])->assertCreated()->json('data.id');

        $this->postJson("/api/v1/finance/sales-credit-notes/{$draftA}/post", ['idempotencyKey' => 'cn-race-a'], $s['headers'])->assertOk();
        // The authoritative, lock-protected check at posting time (not the create-time snapshot) now rejects draftB: only 4 remain.
        $this->postJson("/api/v1/finance/sales-credit-notes/{$draftB}/post", ['idempotencyKey' => 'cn-race-b'], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('lines');

        $this->assertSame(1, DB::table('sales_credit_notes')->where('tenant_id', $s['tenant'])->where('status', 'posted')->count());
        $this->assertSame('96.000', DB::table('stock_balances')->where('tenant_id', $s['tenant'])->where('warehouse_id', $s['warehouse'])->where('inventory_item_id', $s['material'])->value('quantity_on_hand'), '100 opening - 10 sold + 6 restocked (draftA only) = 96; draftB never restocked anything.');
    }

    public function test_full_return_leaves_invoice_posted_but_fully_credited(): void
    {
        $s = $this->scenario(tracked: false);
        $invoice = $this->postedInvoice($s, '2');
        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 2, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-full-1'], $s['headers'])->assertOk();

        $result = $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk();
        $this->assertSame('posted', $result->json('data.status'), 'A fully credited invoice must remain posted, never mutated into cancelled.');
        $this->assertSame('fully_credited', $result->json('data.creditStatus'));
        $this->assertSame('0.00', $result->json('data.remainingAmount'));
    }

    public function test_service_line_credit_creates_no_stock_movement_or_cogs(): void
    {
        $s = $this->scenario(tracked: false);
        $invoice = $this->postedInvoice($s, '1');
        $movementsBefore = DB::table('stock_movements')->where('tenant_id', $s['tenant'])->count();

        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 1, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-service-1'], $s['headers'])->assertOk();

        $this->assertSame($movementsBefore, DB::table('stock_movements')->where('tenant_id', $s['tenant'])->count(), 'A service credit must never create a stock movement.');
        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->where('source_id', $cn)->sole();
        $this->assertSame(0, DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->whereIn('a.code', ['5000', '1100'])->count(), 'No COGS/Inventory lines for a service credit.');
    }

    public function test_no_restock_disposition_reverses_revenue_and_tax_only_without_touching_cogs_or_inventory(): void
    {
        $s = $this->scenario(tracked: true, opening: '100.000', taxRate: '0.080000');
        $invoice = $this->postedInvoice($s, '10');
        $balanceBefore = DB::table('stock_balances')->where('tenant_id', $s['tenant'])->where('warehouse_id', $s['warehouse'])->where('inventory_item_id', $s['material'])->value('quantity_on_hand');

        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 2, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-norestock-1'], $s['headers'])->assertOk();

        $this->assertSame($balanceBefore, DB::table('stock_balances')->where('tenant_id', $s['tenant'])->where('warehouse_id', $s['warehouse'])->where('inventory_item_id', $s['material'])->value('quantity_on_hand'), 'Damaged/no-restock goods must not silently return to sellable stock.');
        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->where('source_id', $cn)->sole();
        $this->assertSame(0, DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->whereIn('a.code', ['5000', '1100'])->count());
    }

    public function test_partially_paid_invoice_credit_note_reduces_outstanding_only(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        $invoice = $this->postedInvoice($s, '3'); // 300.00 at 100.00/unit
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-17', 'amount' => '100.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'cn-pp-pay-1', 'allocations' => [['invoiceId' => $invoice, 'amount' => '100.00']]], $s['headers'])->assertCreated();
        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '200.00');

        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 1.5, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $posted = $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-pp-1'], $s['headers'])->assertOk()
            ->assertJsonPath('data.arReductionAmount', '150.00')->assertJsonPath('data.customerCreditAmount', '0.00');

        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '50.00')->assertJsonPath('data.paymentStatus', 'partial');
        $this->assertSame('0.00', $this->creditBalance($s));
    }

    public function test_credit_exceeding_outstanding_splits_between_ar_reduction_and_customer_credit(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        $invoice = $this->postedInvoice($s, '3'); // 300.00
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-17', 'amount' => '250.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'cn-ex-pay-1', 'allocations' => [['invoiceId' => $invoice, 'amount' => '250.00']]], $s['headers'])->assertCreated();

        // Outstanding is now 50.00; credit 1 full unit (100.00) -> 50 reduces AR, 50 becomes customer credit.
        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 1, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $posted = $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-ex-1'], $s['headers'])->assertOk()
            ->assertJsonPath('data.arReductionAmount', '50.00')->assertJsonPath('data.customerCreditAmount', '50.00');

        // Outstanding is fully cleared (payment + credit), but only 250 was ever actually PAID — payment status stays "partial" (§37 keeps payment/credit status distinct); credit status is what explains the rest.
        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '0.00')->assertJsonPath('data.paymentStatus', 'partial')->assertJsonPath('data.creditStatus', 'partially_credited');
        $this->assertSame('50.00', $this->creditBalance($s));

        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->where('source_id', $cn)->sole();
        $lines = DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->select('a.code', 'l.credit')->get()->keyBy('code');
        $this->assertSame('50.00', $lines['1200']->credit);
        $this->assertSame('50.00', $lines['2020']->credit, 'Excess-over-outstanding credits the Customer Credit Balance liability account, never a negative AR.');
    }

    /** §43 critical paid-invoice test: Invoice 300, Payment 300, Credit Note 100 -> AR stays 0, Customer Credit 100, then Refund 100 settles it with zero further P&L impact. */
    public function test_critical_paid_invoice_then_credit_then_refund_matches_the_documented_example(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        $invoice = $this->postedInvoice($s, '3'); // 300.00
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-17', 'amount' => '300.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'cn-paid-pay-1', 'allocations' => [['invoiceId' => $invoice, 'amount' => '300.00']]], $s['headers'])->assertCreated();
        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()->assertJsonPath('data.paymentStatus', 'paid')->assertJsonPath('data.remainingAmount', '0.00');

        $revenueJournalsBefore = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count();

        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 1, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $posted = $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-paid-1'], $s['headers'])->assertOk()
            ->assertJsonPath('data.arReductionAmount', '0.00')->assertJsonPath('data.customerCreditAmount', '100.00');

        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '0.00')->assertJsonPath('data.paymentStatus', 'paid');
        $this->assertSame('100.00', $this->creditBalance($s));
        $this->assertSame($revenueJournalsBefore, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count(), 'Revenue must never be recognized/reversed via the original invoice a second time.');

        // Now settle the credit with a bank refund.
        $preview = $this->postJson('/api/v1/finance/customer-refunds/preview', ['customerId' => $s['customer'], 'amount' => '100.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId], $s['headers'])->assertOk()
            ->assertJsonPath('data.availableCredit', '100.00')->assertJsonPath('data.availableCreditAfter', '0.00')
            ->assertJsonPath('data.accounting.debitAccountCode', '2020')->assertJsonPath('data.accounting.creditAccountCode', '1010');

        $journalsBeforeRefund = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->count();
        $refund = $this->postJson('/api/v1/finance/customer-refunds', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'refundDate' => '2026-09-18', 'amount' => '100.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'refund-paid-1'], $s['headers'])->assertCreated();

        $this->assertSame('0.00', $this->creditBalance($s));
        $this->assertSame($journalsBeforeRefund + 1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->count(), 'Exactly one new journal for the refund.');
        $refundJournal = DB::table('journal_entries')->where('id', $refund->json('data.journalEntryId'))->first();
        $refundLines = DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $refundJournal->id)->select('a.code', 'l.debit', 'l.credit')->get()->keyBy('code');
        $this->assertSame('100.00', $refundLines['2020']->debit);
        $this->assertSame('100.00', $refundLines['1010']->credit);

        // No additional Revenue/COGS/Inventory/AR impact from the refund itself.
        $this->assertSame($revenueJournalsBefore, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->count());
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->count());
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'customer_refund')->count());
        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '0.00');
    }

    public function test_refund_amount_exceeding_available_credit_is_rejected(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        $invoice = $this->postedInvoice($s, '1');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-17', 'amount' => '100.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'cn-ref-pay-1', 'allocations' => [['invoiceId' => $invoice, 'amount' => '100.00']]], $s['headers'])->assertCreated();
        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 1, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-ref-1'], $s['headers'])->assertOk();
        $this->assertSame('100.00', $this->creditBalance($s));

        $this->postJson('/api/v1/finance/customer-refunds', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'refundDate' => '2026-09-18', 'amount' => '150.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'refund-over-1'], $s['headers'])
            ->assertUnprocessable()->assertJsonValidationErrors('amount');
        $this->assertSame('100.00', $this->creditBalance($s));
    }

    public function test_credit_note_idempotency_and_posted_immutability(): void
    {
        $s = $this->scenario(tracked: false);
        $invoice = $this->postedInvoice($s, '2');
        $payload = $this->creditPayload($s, $invoice, 1, restock: false);
        $payload['idempotencyKey'] = 'cn-idem-create-1';
        $first = $this->postJson('/api/v1/finance/sales-credit-notes', $payload, $s['headers'])->assertCreated();
        $this->postJson('/api/v1/finance/sales-credit-notes', $payload, $s['headers'])->assertCreated()->assertJsonPath('data.id', $first->json('data.id'));
        $this->assertSame(1, DB::table('sales_credit_notes')->where('tenant_id', $s['tenant'])->where('idempotency_key', 'cn-idem-create-1')->count());

        $cn = $first->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-idem-post-1'], $s['headers'])->assertOk();
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-idem-post-1'], $s['headers'])->assertOk();
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->where('source_id', $cn)->count());
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/cancel", [], $s['headers'])->assertUnprocessable();
    }

    public function test_tenant_and_branch_isolation_for_credit_notes_and_refunds(): void
    {
        $s = $this->scenario(tracked: false);
        $invoice = $this->postedInvoice($s, '2');
        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 1, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-iso-1'], $s['headers'])->assertOk();

        $other = $this->scenario(tracked: false);
        $this->getJson("/api/v1/finance/sales-credit-notes/{$cn}", $other['headers'])->assertNotFound();
        // Tenant B cannot credit Tenant A's invoice even by guessing the id — the cross-tenant lookup itself 404s before any line validation runs.
        $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoice, 'lines' => [['originalSalesInvoiceLineId' => 1, 'quantity' => '1']]], $other['headers'])->assertNotFound();
    }

    public function test_permission_denied_without_sales_credit_notes_create_permission(): void
    {
        $s = $this->scenario(tracked: false);
        $invoice = $this->postedInvoice($s, '1');
        DB::table('users')->where('id', $s['owner'])->update(['role' => 'staff']);
        $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 1, restock: false), $s['headers'])->assertForbidden();
    }

    public function test_daily_closing_reflects_customer_refund_cash_once_on_its_own_date(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        $invoice = $this->postedInvoice($s, '1');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-17', 'amount' => '100.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'cn-dc-pay-1', 'allocations' => [['invoiceId' => $invoice, 'amount' => '100.00']]], $s['headers'])->assertCreated();
        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 1, restock: false), $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-dc-1'], $s['headers'])->assertOk();

        $before = $this->getJson('/api/v1/finance/daily-closing?date=2026-09-19&branchId='.$s['branch'], $s['headers'])->assertOk();
        $this->assertSame('0.00', $before->json('data.cash.customerRefundsCash'), 'The Credit Note itself must not move cash.');

        $this->postJson('/api/v1/finance/customer-refunds', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'refundDate' => '2026-09-19', 'amount' => '100.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'refund-dc-1'], $s['headers'])->assertCreated();

        $after = $this->getJson('/api/v1/finance/daily-closing?date=2026-09-19&branchId='.$s['branch'], $s['headers'])->assertOk();
        $this->assertSame('100.00', $after->json('data.cash.customerRefundsCash'));
        $this->assertSame('100.00', $after->json('data.operations.customerRefundsTotal'));
    }

    /** §42 critical accounting test: 50% of a tracked line, proportional revenue/tax/COGS reversal, not hardcoded assumptions. */
    public function test_critical_accounting_half_quantity_return_reverses_proportional_amounts(): void
    {
        $s = $this->scenario(tracked: true, opening: '100.000', taxRate: '0.080000');
        $invoice = $this->postedInvoice($s, '10'); // 100.00 subtotal, 8.00 tax, 20.00 cogs (10 units * 2.00 cost)
        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', $this->creditPayload($s, $invoice, 5, restock: true), $s['headers'])->assertCreated()->json('data.id');
        $posted = $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'cn-half-1'], $s['headers'])->assertOk();
        $this->assertSame('50.00', $posted->json('data.subtotal'));
        $this->assertSame('4.00', $posted->json('data.taxTotal'));
        $this->assertSame('54.00', $posted->json('data.arReductionAmount'));
        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->where('source_id', $cn)->sole();
        $this->assertSame('10.00', DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->where('a.code', '5000')->value('credit'), 'COGS reversal = 5 units * original 2.00 cost = 10.00.');
    }

    // ---- scenario builders -------------------------------------------------

    private function scenario(bool $tracked, string $opening = '0.000', string $taxRate = '0.000000', string $price = '10.00'): array
    {
        $suffix = (string) str()->uuid();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Sales P4', 'slug' => "sales-p4-{$suffix}", 'status' => 'active', 'tax_rate' => $taxRate, 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Downtown', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => "sales-p4-{$suffix}@test.local", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner);
        $warehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branch}-MAIN")->value('id');
        $token = "sales-p4-{$suffix}";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'sales-p4', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
        $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'Damascus Tech Company'], $headers)->assertCreated()->json('data.id');

        $material = null;
        if ($tracked) {
            $material = (int) DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee Beans', 'name_ar' => 'Coffee Beans', 'name_en' => 'Coffee Beans', 'sku' => "MAT-{$suffix}", 'catalog_identity' => "mat-{$suffix}", 'item_type' => 'raw_material', 'unit' => 'piece', 'minimum_stock' => '0.000', 'reorder_level' => '0.000', 'cost_per_unit' => '2.0000', 'latest_unit_cost' => '2.0000', 'is_active' => true, 'created_by' => $owner, 'updated_by' => $owner, 'created_at' => now(), 'updated_at' => now()]);
            DB::table('inventory_item_warehouses')->insert(['tenant_id' => $tenant, 'inventory_item_id' => $material, 'warehouse_id' => $warehouse, 'created_at' => now(), 'updated_at' => now()]);
            app(InventoryPostingService::class)->post(Request::create('/stock-in', 'POST'), $tenant, ['warehouseId' => $warehouse, 'branchId' => $branch, 'itemId' => $material, 'type' => 'stock_in', 'quantity' => $opening, 'unit' => 'piece', 'unitCost' => '2.0000', 'idempotencyKey' => "opening-{$suffix}"], $owner);
        }
        $product = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => $tracked ? 'Cappuccino' : 'Meeting Room', 'name_ar' => $tracked ? 'Cappuccino' : 'Meeting Room', 'sku' => "PROD-{$suffix}", 'price' => $price, 'is_active' => true, 'is_stock_tracked' => $tracked, 'inventory_controlled' => $tracked, 'created_at' => now(), 'updated_at' => now()]);
        if ($tracked) {
            $variant = (int) DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => $price, 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
            $recipe = (int) DB::table('variant_recipes')->insertGetId(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'created_at' => now(), 'updated_at' => now()]);
            DB::table('variant_recipe_components')->insert(['tenant_id' => $tenant, 'variant_recipe_id' => $recipe, 'inventory_item_id' => $material, 'quantity' => '1.000000', 'unit_code' => 'piece', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);
        }

        return compact('tenant', 'branch', 'owner', 'headers', 'warehouse', 'material', 'product', 'customer');
    }

    private function postedInvoice(array $s, string $quantity): int
    {
        $invoice = (int) $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-09-17', 'lines' => [['productId' => $s['product'], 'quantity' => $quantity]]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'invoice-post-'.uniqid()], $s['headers'])->assertOk();

        return $invoice;
    }

    private function creditPayload(array $s, int $invoiceId, int|float $quantity, bool $restock): array
    {
        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->value('id');

        return ['originalSalesInvoiceId' => $invoiceId, 'reason' => 'Customer return', 'idempotencyKey' => 'cn-create-'.uniqid(), 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => (string) $quantity, 'restock' => $restock]]];
    }

    /** @return array{0:int,1:int} [paymentMethodId, financialLocationId] */
    private function cashMethodAndLocation(int $tenant): array
    {
        return [(int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id'), (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id')];
    }

    private function creditBalance(array $s): string
    {
        return Money::decimal(Money::cents(DB::table('customer_credit_ledger')->where('tenant_id', $s['tenant'])->where('customer_id', $s['customer'])->sum('amount') ?: '0'));
    }

    private function snapshot(int $tenant): array
    {
        return [
            'creditNotes' => DB::table('sales_credit_notes')->where('tenant_id', $tenant)->count(),
            'journals' => DB::table('journal_entries')->where('tenant_id', $tenant)->count(),
            'movements' => DB::table('stock_movements')->where('tenant_id', $tenant)->count(),
            'ledger' => DB::table('customer_credit_ledger')->where('tenant_id', $tenant)->count(),
        ];
    }
}
