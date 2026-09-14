<?php

namespace Tests\Feature;

use App\Services\FinancialIntegrityService;
use Database\Seeders\FinanceOperationsDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FinanceOperationsDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_connected_finance_demo_is_idempotent_and_closes_its_operational_period(): void
    {
        $this->travelTo('2026-09-01 12:00:00');
        try {
            app(FinanceOperationsDemoSeeder::class)->run();
            $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618-finance-demo')->value('id');
            $this->assertGreaterThan(0, $tenant);

            // 2 original header-only demo suppliers + 3 added for Purchasing
            // Phase 1's realistic line-based examples (packaging, telecom,
            // equipment servicing) — see FinanceOperationsDemoSeeder::purchasingLineItems().
            $this->assertSame(5, DB::table('suppliers')->where('tenant_id', $tenant)->count());
            $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-BEAN-2026-07')->where('status', 'partially_paid')->count());
            $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-BEAN-UNPAID-2026-08')->where('status', 'posted')->count());
            $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-DAIRY-PAID-2026-07')->where('status', 'paid')->count());
            $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-DAIRY-OVERDUE-2026-07')->where('status', 'posted')->whereDate('due_date', '<', '2026-09-01')->count());

            // Purchasing Phase 1 — real line-item purchase invoices (see
            // FinanceOperationsDemoSeeder::purchasingLineItems()). Each one
            // must carry exactly one supplier_invoice_lines row.
            foreach ([
                'DEMO-BEANS-LINES-2026-08' => 'posted',
                'DEMO-MILK-LINES-2026-08' => 'partially_paid',
                'DEMO-PKG-LINES-2026-08' => 'posted',
                'DEMO-NET-LINES-2026-08' => 'posted',
                'DEMO-MAINT-LINES-2026-08' => 'posted',
            ] as $invoiceNumber => $status) {
                $invoiceId = DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', $invoiceNumber)->where('status', $status)->value('id');
                $this->assertNotNull($invoiceId, "$invoiceNumber must exist with status $status.");
                $this->assertSame(1, DB::table('supplier_invoice_lines')->where('tenant_id', $tenant)->where('supplier_invoice_id', $invoiceId)->count(), "$invoiceNumber must have exactly one line.");
            }

            // Purchasing Phase 2 — Goods Receipts, through PurchaseReceivingService
            // only (see FinanceOperationsDemoSeeder::receiveInvoice()). Three
            // receipt-status scenarios: beans fully received across two
            // receipts, milk left partially received, packaging left with
            // zero receipts — proving a posted invoice with no receipt yet
            // is a normal state, not an error.
            $beansInvoiceId = (int) DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-BEANS-LINES-2026-08')->value('id');
            $milkInvoiceId = (int) DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-MILK-LINES-2026-08')->value('id');
            $packagingInvoiceId = (int) DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-PKG-LINES-2026-08')->value('id');
            $this->assertSame('received', DB::table('supplier_invoices')->where('id', $beansInvoiceId)->value('receipt_status'));
            $this->assertSame('partially_received', DB::table('supplier_invoices')->where('id', $milkInvoiceId)->value('receipt_status'));
            // receipt_status is only ever written by recomputeReceiptStatus(),
            // which runs when a receipt is posted — an invoice nobody has
            // ever tried to receive against correctly stays null at the raw
            // column level (the Purchasing Center API layer is what
            // presents that as "not_received" for display purposes).
            $this->assertNull(DB::table('supplier_invoices')->where('id', $packagingInvoiceId)->value('receipt_status'));
            $this->assertSame(2, DB::table('purchase_receipts')->where('tenant_id', $tenant)->where('supplier_invoice_id', $beansInvoiceId)->where('status', 'posted')->count());
            $this->assertSame(1, DB::table('purchase_receipts')->where('tenant_id', $tenant)->where('supplier_invoice_id', $milkInvoiceId)->where('status', 'posted')->count());
            $this->assertSame(0, DB::table('purchase_receipts')->where('tenant_id', $tenant)->where('supplier_invoice_id', $packagingInvoiceId)->count());

            $beansItemId = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'DEMO-BEANS')->value('id');
            $milkItemId = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'DEMO-MILK')->value('id');
            $packagingItemId = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'DEMO-PACKAGING')->value('id');
            $this->assertSame(0, DB::table('stock_movements')->where('inventory_item_id', $packagingItemId)->count(), 'An unreceived Purchasing invoice must never move physical stock.');
            $this->assertSame(2, DB::table('stock_movements')->where('inventory_item_id', $beansItemId)->where('type', 'stock_in')->where('reference_type', 'purchase_receipt_line')->count());
            $this->assertSame(1, DB::table('stock_movements')->where('inventory_item_id', $milkItemId)->where('type', 'stock_in')->where('reference_type', 'purchase_receipt_line')->count());

            // The critical Phase 2 regression invariant: receiving never
            // posts a journal — every journal on these two invoices is still
            // exactly the one AP-liability entry from SupplierInvoiceService.
            $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'supplier_invoice')->where('source_id', $beansInvoiceId)->count());
            $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'supplier_invoice')->where('source_id', $milkInvoiceId)->count());
            // None of the three Goods Receipt stock_in movements posted a
            // journal (the pre-existing waste/stock_count_variance demo
            // movements elsewhere in this seeder correctly still do — this
            // checks only the receipt-sourced movements stay non-posting).
            $receiptMovementIds = DB::table('stock_movements')->where('tenant_id', $tenant)->where('reference_type', 'purchase_receipt_line')->pluck('id');
            $this->assertSame(3, $receiptMovementIds->count());
            $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'inventory_movement')->whereIn('source_id', $receiptMovementIds)->count());
            $this->assertSame(1, DB::table('financial_reconciliations')->where('tenant_id', $tenant)->where('status', 'completed')->count());
            $this->assertSame(1, DB::table('daily_closings')->where('tenant_id', $tenant)->where('business_date', '2026-09-01')->where('status', 'closed')->count());
            $this->assertSame(1, DB::table('accounting_periods')->where('tenant_id', $tenant)->where('status', 'closed')->count());
            $this->assertSame('PASS', app(FinancialIntegrityService::class)->inspect($tenant)['status']);

            $counts = [
                'suppliers' => DB::table('suppliers')->where('tenant_id', $tenant)->count(),
                'invoices' => DB::table('supplier_invoices')->where('tenant_id', $tenant)->count(),
                'invoice_lines' => DB::table('supplier_invoice_lines')->where('tenant_id', $tenant)->count(),
                'payments' => DB::table('supplier_payments')->where('tenant_id', $tenant)->count(),
                'allocations' => DB::table('payment_allocations')->where('tenant_id', $tenant)->count(),
                'reconciliations' => DB::table('financial_reconciliations')->where('tenant_id', $tenant)->count(),
                'closings' => DB::table('daily_closings')->where('tenant_id', $tenant)->count(),
                'periods' => DB::table('accounting_periods')->where('tenant_id', $tenant)->count(),
                'journals' => DB::table('journal_entries')->where('tenant_id', $tenant)->count(),
                'purchase_receipts' => DB::table('purchase_receipts')->where('tenant_id', $tenant)->count(),
                'purchase_receipt_lines' => DB::table('purchase_receipt_lines')->where('tenant_id', $tenant)->count(),
                'stock_movements' => DB::table('stock_movements')->where('tenant_id', $tenant)->count(),
            ];

            app(FinanceOperationsDemoSeeder::class)->run();

            foreach ($counts as $table => $count) {
                $actual = match ($table) {
                    'suppliers' => DB::table('suppliers')->where('tenant_id', $tenant)->count(),
                    'invoices' => DB::table('supplier_invoices')->where('tenant_id', $tenant)->count(),
                    'invoice_lines' => DB::table('supplier_invoice_lines')->where('tenant_id', $tenant)->count(),
                    'payments' => DB::table('supplier_payments')->where('tenant_id', $tenant)->count(),
                    'allocations' => DB::table('payment_allocations')->where('tenant_id', $tenant)->count(),
                    'reconciliations' => DB::table('financial_reconciliations')->where('tenant_id', $tenant)->count(),
                    'closings' => DB::table('daily_closings')->where('tenant_id', $tenant)->count(),
                    'periods' => DB::table('accounting_periods')->where('tenant_id', $tenant)->count(),
                    'journals' => DB::table('journal_entries')->where('tenant_id', $tenant)->count(),
                    'purchase_receipts' => DB::table('purchase_receipts')->where('tenant_id', $tenant)->count(),
                    'purchase_receipt_lines' => DB::table('purchase_receipt_lines')->where('tenant_id', $tenant)->count(),
                    'stock_movements' => DB::table('stock_movements')->where('tenant_id', $tenant)->count(),
                };
                $this->assertSame($count, $actual, $table.' must remain idempotent.');
            }
        } finally {
            $this->travelBack();
        }
    }
}
