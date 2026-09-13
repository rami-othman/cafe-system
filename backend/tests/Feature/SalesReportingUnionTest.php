<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Phase 5 — the mandatory no-double-counting proofs (docs spec §31-33) for
 * the `finance/reports/sales-profitability` union endpoint: POS orders +
 * posted Manual Sales Invoices, net of posted Sales Credit Notes, with
 * Customer Payments/Refunds affecting cash collection only — never Revenue
 * a second time.
 */
class SalesReportingUnionTest extends TestCase
{
    use RefreshDatabase;

    public function test_pos_plus_manual_union_never_double_counts_revenue_or_cash(): void
    {
        $s = $this->scenario();
        $date = now()->subDays(3)->toDateString();

        // POS Sale = 500 Cash.
        $orderId = $this->posOrder($s, '500.00', $date);
        $this->posPayment($s, $orderId, '500.00', $date);

        // Manual Invoice = 300 (3 units @ 100, so a later 1-unit credit note is exactly 100).
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => $date,
            'lines' => [['productId' => $s['product'], 'quantity' => '3']],
        ], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'union-post-1'], $s['headers'])->assertOk();

        // §32: Customer Payment = 300 Cash settles the invoice.
        [$cashMethod, $cashLocation] = $this->cashMethodAndLocation($s['tenant']);
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => $date, 'amount' => '300.00',
            'paymentMethodId' => $cashMethod, 'financialLocationId' => $cashLocation, 'idempotencyKey' => 'union-pay-1',
            'allocations' => [['invoiceId' => $invoice, 'amount' => '300.00']],
        ], $s['headers'])->assertCreated();

        $report = fn () => $this->getJson('/api/v1/finance/reports/sales-profitability?dateFrom='.$date.'&dateTo='.$date.'&branchId='.$s['branch'].'&comparison=none', $s['headers'])->assertOk()->json('data');

        // §32 proof: Revenue = 800 (500 POS + 300 manual), Cash collected = 800 — never 1100 (500+300+300 payment double-counted as new revenue).
        $r1 = $report();
        $this->assertSame('800.00', $r1['kpis']['netSales']['value'], '§32: Revenue must be 800, not 1100.');
        $this->assertSame('800.00', $r1['kpis']['cashCollected']['value'], '§32: Cash collected must be 800.');
        $pos = collect($r1['salesBySource'])->firstWhere('name', 'pos');
        $manual = collect($r1['salesBySource'])->firstWhere('name', 'manual_invoice');
        $this->assertSame('500.00', $pos['netSales']);
        $this->assertSame('300.00', $manual['netSales']);

        // §31/§33: Credit Note = 100 (1 of 3 units) against the (already fully paid) invoice — entire 100 becomes unapplied customer credit, never touching cash by itself.
        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice)->value('id');
        $creditNote = $this->postJson('/api/v1/finance/sales-credit-notes', [
            'originalSalesInvoiceId' => $invoice, 'creditDate' => $date, 'reason' => 'Partial return', 'idempotencyKey' => 'union-cn-1',
            'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '1', 'restock' => false]],
        ], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$creditNote}/post", ['idempotencyKey' => 'union-cn-post-1'], $s['headers'])->assertOk()
            ->assertJsonPath('data.total', '100.00')->assertJsonPath('data.customerCreditAmount', '100.00');

        // §31 proof: Net Sales = 700 (500 POS + 300 manual - 100 credit note) — never 800 or 900.
        $r2 = $report();
        $this->assertSame('700.00', $r2['kpis']['netSales']['value'], '§31: Net Sales must be 700, not 800 or 900.');
        $this->assertSame('800.00', $r2['kpis']['cashCollected']['value'], 'A Credit Note by itself must not change cash collected.');

        // §33: Customer Refund = 100 Cash settles the customer credit.
        $this->postJson('/api/v1/finance/customer-refunds', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'refundDate' => $date, 'amount' => '100.00',
            'paymentMethodId' => $cashMethod, 'financialLocationId' => $cashLocation, 'idempotencyKey' => 'union-refund-1',
        ], $s['headers'])->assertCreated();

        // §33 proof: Net Revenue stays 700/200 (manual side) — the refund never reduces revenue a second time; only cash collected drops by 100.
        $r3 = $report();
        $this->assertSame('700.00', $r3['kpis']['netSales']['value'], '§33: Refund must not reduce Net Revenue a second time.');
        $this->assertSame('700.00', $r3['kpis']['cashCollected']['value'], '§33: Cash collected must drop by exactly the 100 refund (800 -> 700).');
    }

    /** Product quantities are the union of POS + Manual, minus Credit Note returns — never derived from the GL. */
    public function test_product_performance_unions_pos_and_manual_quantities_net_of_credit_note_returns(): void
    {
        $s = $this->scenario();
        $date = now()->subDays(2)->toDateString();

        // POS: 5 units of the shared product.
        $orderId = $this->posOrder($s, '500.00', $date);
        DB::table('order_items')->insert(['tenant_id' => $s['tenant'], 'order_id' => $orderId, 'product_id' => $s['product'], 'product_name' => 'Consulting', 'quantity' => '5.000', 'unit_price' => '100.00', 'discount_total' => '0.00', 'total' => '500.00', 'status' => 'served', 'created_at' => now(), 'updated_at' => now()]);
        $this->posPayment($s, $orderId, '500.00', $date);

        // Manual Invoice: 3 units of the same product.
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => $date,
            'lines' => [['productId' => $s['product'], 'quantity' => '3']],
        ], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'union-qty-post-1'], $s['headers'])->assertOk();

        // Credit Note: returns 1 of the 3 manual units.
        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice)->value('id');
        $creditNote = $this->postJson('/api/v1/finance/sales-credit-notes', [
            'originalSalesInvoiceId' => $invoice, 'creditDate' => $date, 'reason' => 'Partial return', 'idempotencyKey' => 'union-qty-cn-1',
            'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '1', 'restock' => false]],
        ], $s['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/sales-credit-notes/{$creditNote}/post", ['idempotencyKey' => 'union-qty-cn-post-1'], $s['headers'])->assertOk();

        $data = $this->getJson('/api/v1/finance/reports/sales-profitability?dateFrom='.$date.'&dateTo='.$date.'&branchId='.$s['branch'].'&comparison=none', $s['headers'])->assertOk()->json('data');
        $products = collect($data['products']);
        $this->assertCount(1, $products, 'POS and Manual lines for the same product must merge into one row, not two.');
        $row = $products->first();
        $this->assertEquals(7.0, $row['quantity'], 'Quantity = 5 POS + 3 manual - 1 returned = 7, never derived from the GL.');
        $this->assertSame('700.00', $row['netSales']);
    }

    private function scenario(): array
    {
        $suffix = (string) str()->uuid();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Sales P5 Union', 'slug' => "sales-p5u-{$suffix}", 'status' => 'active', 'tax_rate' => '0.000000', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Downtown', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => "sales-p5u-{$suffix}@test.local", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner);
        $token = "sales-p5u-{$suffix}";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'sales-p5u', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
        $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'Damascus Tech Company'], $headers)->assertCreated()->json('data.id');
        $product = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Consulting', 'name_ar' => 'استشارة', 'sku' => "SVC-{$suffix}", 'price' => '100.00', 'is_active' => true, 'is_stock_tracked' => false, 'inventory_controlled' => false, 'created_at' => now(), 'updated_at' => now()]);

        return compact('tenant', 'branch', 'owner', 'headers', 'customer', 'product');
    }

    private function posOrder(array $s, string $total, string $date): int
    {
        return (int) DB::table('orders')->insertGetId([
            'tenant_id' => $s['tenant'], 'branch_id' => $s['branch'], 'order_number' => 'ORD-'.uniqid(),
            'type' => 'dine_in', 'status' => 'closed', 'payment_status' => 'paid',
            'subtotal' => $total, 'discount_total' => '0.00', 'tax_total' => '0.00', 'service_total' => '0.00', 'total' => $total,
            'opened_at' => $date.' 10:00:00', 'closed_at' => $date.' 10:05:00', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function posPayment(array $s, int $orderId, string $amount, string $date): void
    {
        DB::table('payments')->insert([
            'tenant_id' => $s['tenant'], 'branch_id' => $s['branch'], 'order_id' => $orderId,
            'method' => 'cash', 'amount' => $amount, 'status' => 'completed', 'paid_at' => $date.' 10:05:00',
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    /** @return array{0:int,1:int} [paymentMethodId, financialLocationId] */
    private function cashMethodAndLocation(int $tenant): array
    {
        return [(int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id'), (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id')];
    }
}
