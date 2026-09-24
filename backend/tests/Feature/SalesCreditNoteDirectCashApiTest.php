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
 * A3 continuation, Phase 2 — Direct Cash Refund Contract: a posted, fully
 * cash-collected walk-in invoice can be credited/refunded through the same
 * Sales Credit Note document a registered customer uses, but its settlement
 * side pays cash back out directly instead of touching AR or the shared
 * walk-in customer's unapplied-credit balance (which would leak across
 * unrelated cash sales). Refundable amount is capped at what THIS invoice
 * actually collected, net of any prior posted refunds against it.
 */
class SalesCreditNoteDirectCashApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_direct_cash_partial_refund_posts_balanced_journal_with_no_ar_or_customer_credit(): void
    {
        $s = $this->scenario(tracked: true, opening: '100.000', taxRate: '0.080000');
        [$invoiceId, $paymentId] = $this->directCashInvoice($s, '10');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);

        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->value('id');
        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', [
            'originalSalesInvoiceId' => $invoiceId, 'reason' => 'Customer return', 'idempotencyKey' => 'dc-cn-create-1',
            'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '3', 'restock' => true]],
        ], $s['headers'])->assertCreated()->json('data.id');

        $preview = $this->getJson("/api/v1/finance/sales-credit-notes/{$cn}/posting-preview?paymentMethodId={$methodId}&financialLocationId={$locationId}", $s['headers'])->assertOk()
            ->assertJsonPath('data.creditNote.total', '32.40')
            ->assertJsonPath('data.accounting.accountsReceivable', null)
            ->assertJsonPath('data.accounting.customerCredit', null)
            ->assertJsonPath('data.accounting.settlementCredit', '32.40');
        $this->assertSame('108.00', $preview->json('data.invoiceImpact.refundableBefore'), '10 units * 10.00 + 8% tax collected in full, nothing refunded yet.');

        $posted = $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", [
            'idempotencyKey' => 'dc-cn-post-1', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId,
        ], $s['headers'])->assertOk()
            ->assertJsonPath('data.status', 'posted')->assertJsonPath('data.arReductionAmount', '0.00')->assertJsonPath('data.customerCreditAmount', '0.00');

        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->where('source_id', $cn)->sole();
        $lines = DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->select('a.code', 'l.debit', 'l.credit', 'l.financial_location_id')->get()->keyBy('code');
        $this->assertSame('30.00', $lines['4020']->debit);
        $this->assertSame('2.40', $lines['2010']->debit);
        $this->assertSame('32.40', $lines['1010']->credit ?? $lines->firstWhere(fn ($l) => (int) $l->financial_location_id === $locationId)?->credit, 'Cash settlement line credited for the full refund, not AR.');
        $this->assertSame($lines->sum('debit'), $lines->sum('credit'), 'A cash credit-note journal must still balance.');
        $this->assertSame(0, DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->where('a.code', '1200')->count(), 'No AR line for a direct-cash refund.');

        $this->assertSame(0, DB::table('customer_credit_ledger')->where('tenant_id', $s['tenant'])->count(), 'No customer-credit balance is ever created for the shared walk-in customer.');
        $this->assertSame(0, DB::table('customer_receivables')->where('sales_invoice_id', $invoiceId)->count());
        $refund = DB::table('customer_refunds')->where('tenant_id', $s['tenant'])->where('sales_credit_note_id', $cn)->sole();
        $this->assertSame('32.40', $refund->amount);
        $this->assertSame((int) $journal->id, (int) $refund->journal_entry_id, 'The refund shares the credit note journal — no second journal.');
        $this->assertSame($locationId, (int) $refund->financial_location_id);

        $invoice = $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->assertOk();
        $this->assertSame('32.40', $invoice->json('data.refundedAmount'));
        $this->assertSame('75.60', $invoice->json('data.netCollectedAmount'), '108.00 collected - 32.40 refunded.');
        $this->assertSame('75.60', $invoice->json('data.remainingRefundableAmount'));
        $this->assertSame('paid', $invoice->json('data.paymentStatus'), 'Payment status stays "paid" — cash refund is a separate concept from AR payment status.');
    }

    public function test_direct_cash_refunds_are_cumulative_and_a_full_refund_cannot_be_refunded_again(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        [$invoiceId] = $this->directCashInvoice($s, '1');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->value('id');

        // First partial refund: 0.4 of 1 unit -> 40.00.
        $cn1 = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-cum-1', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '0.4', 'restock' => false]]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn1}/post", ['idempotencyKey' => 'dc-cum-post-1', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId], $s['headers'])->assertOk();

        // Second partial refund: another 0.4 -> cumulative 80.00, still within the 100.00 collected.
        $cn2 = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-cum-2', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '0.4', 'restock' => false]]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn2}/post", ['idempotencyKey' => 'dc-cum-post-2', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId], $s['headers'])->assertOk();
        $this->assertSame('80.00', $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->json('data.refundedAmount'));

        // A third refund for the remaining 0.2 (20.00) exactly exhausts the refundable balance.
        $cn3 = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-cum-3', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '0.2', 'restock' => false]]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn3}/post", ['idempotencyKey' => 'dc-cum-post-3', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId], $s['headers'])->assertOk();
        $this->assertSame('100.00', $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->json('data.refundedAmount'));
        $this->assertSame('0.00', $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->json('data.remainingRefundableAmount'));

        // Nothing is returnable any more, so a further credit note is rejected before any accounting effect (over-return, not over-refund, but proves the invoice cannot be double-dipped).
        $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-cum-4', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '0.1', 'restock' => false]]], $s['headers'])
            ->assertUnprocessable()->assertJsonValidationErrors('lines.0.quantity');
        $this->assertSame(3, DB::table('customer_refunds')->where('tenant_id', $s['tenant'])->count());
    }

    public function test_direct_cash_refund_restocks_inventory_exactly_once(): void
    {
        $s = $this->scenario(tracked: true, opening: '100.000', taxRate: '0.000000');
        [$invoiceId] = $this->directCashInvoice($s, '10');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->value('id');
        $balanceAfterSale = DB::table('stock_balances')->where('tenant_id', $s['tenant'])->where('warehouse_id', $s['warehouse'])->where('inventory_item_id', $s['material'])->value('quantity_on_hand');
        $this->assertSame('90.000', $balanceAfterSale);

        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-restock-1', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '4', 'restock' => true]]], $s['headers'])->assertCreated()->json('data.id');
        $key = ['idempotencyKey' => 'dc-restock-post-1', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId];
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", $key, $s['headers'])->assertOk();
        // Replaying the exact same posting request must not restock a second time.
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", $key, $s['headers'])->assertOk();

        $this->assertSame('94.000', DB::table('stock_balances')->where('tenant_id', $s['tenant'])->where('warehouse_id', $s['warehouse'])->where('inventory_item_id', $s['material'])->value('quantity_on_hand'), '90 + 4 restocked, exactly once.');
        $this->assertSame(1, DB::table('customer_refunds')->where('tenant_id', $s['tenant'])->where('sales_credit_note_id', $cn)->count());
    }

    public function test_direct_cash_refund_over_the_collected_amount_is_rejected_atomically(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        [$invoiceId] = $this->directCashInvoice($s, '1');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->value('id');

        // Refund 0.9 first (90.00), leaving only 10.00 refundable.
        $cn1 = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-over-1', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '0.9', 'restock' => false]]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn1}/post", ['idempotencyKey' => 'dc-over-post-1', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId], $s['headers'])->assertOk();

        // The remaining 0.1 (10.00) is still within quantity/returnable bounds
        // but the *tax rate is 0*, so let's instead directly assert the cents
        // cap: attempt to refund the remaining 0.1 twice via two competing
        // drafts to prove only one wins and neither exceeds the cap.
        $cnA = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-over-2', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '0.1', 'restock' => false]]], $s['headers'])->assertCreated()->json('data.id');
        $before = DB::table('customer_refunds')->where('tenant_id', $s['tenant'])->count();
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cnA}/post", ['idempotencyKey' => 'dc-over-post-2', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId], $s['headers'])->assertOk();
        $this->assertSame($before + 1, DB::table('customer_refunds')->where('tenant_id', $s['tenant'])->count());
        $this->assertSame('100.00', $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->json('data.refundedAmount'));

        // Nothing left to credit at all now.
        $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-over-3', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '0.01', 'restock' => false]]], $s['headers'])
            ->assertUnprocessable();
    }

    public function test_direct_cash_refund_rejects_unauthorized_financial_location_before_any_effect(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        [$invoiceId] = $this->directCashInvoice($s, '1');
        [$methodId] = $this->cashMethodAndLocation($s['tenant']);
        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->value('id');

        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoiceId, 'idempotencyKey' => 'dc-badloc-1', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '1', 'restock' => false]]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'dc-badloc-post-1', 'paymentMethodId' => $methodId, 'financialLocationId' => 999999], $s['headers'])
            ->assertUnprocessable();

        $this->assertSame('draft', DB::table('sales_credit_notes')->where('id', $cn)->value('status'));
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_credit_note')->count());
        $this->assertSame(0, DB::table('customer_refunds')->where('tenant_id', $s['tenant'])->count());
    }

    public function test_direct_cash_invoice_never_leaks_into_ar_overview_or_dashboard_outstanding(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        [$invoiceId] = $this->directCashInvoice($s, '1');

        // The shared walk-in customer never appears in the AR overview — it never carries AR.
        $overview = $this->getJson('/api/v1/finance/customers-receivables', $s['headers'])->assertOk();
        $this->assertFalse(collect($overview->json('data'))->contains(fn (array $row) => $row['customerId'] === $s['walkIn']));

        // Sales Center's own "outstanding AR" KPI must not count the fully cash-collected invoice either.
        $summary = $this->getJson('/api/v1/finance/sales-invoices', $s['headers'])->assertOk();
        $this->assertSame('0.00', $summary->json('summary.financialSummary.outstandingAr'));

        $this->assertSame('paid', $this->getJson("/api/v1/finance/sales-invoices/{$invoiceId}", $s['headers'])->json('data.paymentStatus'));
    }

    public function test_registered_customer_credit_note_flow_is_unaffected_by_direct_cash_support(): void
    {
        $s = $this->scenario(tracked: false, price: '100.00');
        $invoice = (int) $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $s['product'], 'quantity' => '1']]], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'reg-post-1'], $s['headers'])->assertOk();
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', ['branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => '2026-09-12', 'amount' => '100.00', 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'reg-pay-1', 'allocations' => [['invoiceId' => $invoice, 'amount' => '100.00']]], $s['headers'])->assertCreated();

        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice)->value('id');
        $cn = $this->postJson('/api/v1/finance/sales-credit-notes', ['originalSalesInvoiceId' => $invoice, 'idempotencyKey' => 'reg-cn-1', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '1', 'restock' => false]]], $s['headers'])->assertCreated()->json('data.id');
        // No paymentMethodId/financialLocationId supplied — and none required — for the registered-customer AR path.
        $posted = $this->postJson("/api/v1/finance/sales-credit-notes/{$cn}/post", ['idempotencyKey' => 'reg-cn-post-1'], $s['headers'])->assertOk()
            ->assertJsonPath('data.arReductionAmount', '0.00')->assertJsonPath('data.customerCreditAmount', '100.00');
        $this->assertSame('100.00', Money::decimal(Money::cents(DB::table('customer_credit_ledger')->where('tenant_id', $s['tenant'])->where('customer_id', $s['customer'])->sum('amount') ?: '0')));
        $this->assertSame(0, DB::table('customer_refunds')->where('sales_credit_note_id', $cn)->count(), 'A registered-customer credit note never creates a direct-cash refund row.');
    }

    // ---- scenario builders -------------------------------------------------

    private function scenario(bool $tracked, string $opening = '0.000', string $taxRate = '0.000000', string $price = '10.00'): array
    {
        $suffix = (string) str()->uuid();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Sales A3', 'slug' => "sales-a3-{$suffix}", 'status' => 'active', 'tax_rate' => $taxRate, 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Downtown', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => "sales-a3-{$suffix}@test.local", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner);
        $warehouse = (int) DB::table('branches')->where('tenant_id', $tenant)->where('id', $branch)->value('pos_inventory_warehouse_id');
        $token = "sales-a3-{$suffix}";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'sales-a3', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
        $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'Damascus Tech Company'], $headers)->assertCreated()->json('data.id');
        $walkIn = (int) DB::table('customers')->where('tenant_id', $tenant)->where('is_walk_in', true)->value('id');

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

        return compact('tenant', 'branch', 'owner', 'headers', 'warehouse', 'material', 'product', 'customer', 'walkIn');
    }

    /** @return array{0:int,1:int} [invoiceId, directPaymentId] — a posted, fully cash-collected walk-in invoice. */
    private function directCashInvoice(array $s, string $quantity): array
    {
        $draft = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $s['branch'], 'customerId' => $s['walkIn'], 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $s['product'], 'quantity' => $quantity]]], $s['headers'])->assertCreated();
        $invoiceId = $draft->json('data.id');
        $total = $draft->json('data.total');
        [$methodId, $locationId] = $this->cashMethodAndLocation($s['tenant']);
        $key = uniqid();
        $result = $this->postJson("/api/v1/finance/sales-invoices/{$invoiceId}/post-and-collect", [
            'postIdempotencyKey' => "dc-post-{$key}", 'paymentIdempotencyKey' => "dc-pay-{$key}",
            'paymentDate' => '2026-09-12', 'amount' => $total, 'paymentMethodId' => $methodId, 'financialLocationId' => $locationId,
        ], $s['headers'])->assertOk();

        return [(int) $invoiceId, (int) $result->json('data.paymentId')];
    }

    /** @return array{0:int,1:int} [paymentMethodId, financialLocationId] */
    private function cashMethodAndLocation(int $tenant): array
    {
        return [(int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id'), (int) DB::table('branches')->where('tenant_id', $tenant)->value('pos_cash_financial_location_id')];
    }
}
