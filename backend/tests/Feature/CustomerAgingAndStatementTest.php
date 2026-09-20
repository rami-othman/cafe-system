<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryPostingService;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Phase 5 — AR Aging / Customer Statement. Reproduces the docs spec's
 * mandatory Day 1-5 scenario (§30) end to end through the real posting APIs
 * (Sales Invoice, Customer Payment x2, Sales Credit Note, Customer Refund)
 * and proves every day's Revenue/AR/COGS/Cash figure and the customer
 * statement's running balance, which must reconcile to
 * AR outstanding - customer credit balance at every cutoff.
 *
 * Dates are relative to now() (never hardcoded calendar dates) so this test
 * never becomes a time-bomb as real time passes it (see the pre-existing
 * `overdue` staleness this phase diagnosed in CustomerPaymentApiTest).
 */
class CustomerAgingAndStatementTest extends TestCase
{
    use RefreshDatabase;

    public function test_day_1_to_5_scenario_matches_the_documented_ar_and_credit_reconciliation(): void
    {
        $s = $this->scenario();
        $day1 = now()->subDays(10)->toDateString();
        $day2 = now()->subDays(9)->toDateString();
        $day3 = now()->subDays(8)->toDateString();
        $day4 = now()->subDays(7)->toDateString();
        $day5 = now()->subDays(6)->toDateString();

        // Day 1: Manual credit Sales Invoice = 300 (3 units @ 100), COGS = 90 (3 * 30/unit).
        $invoice = $this->postJson('/api/v1/finance/sales-invoices', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => $day1, 'dueDate' => now()->addDays(30)->toDateString(),
            'lines' => [['productId' => $s['product'], 'quantity' => '3']],
        ], $s['headers'])->assertCreated()->json('data.id');
        $posted = $this->postJson("/api/v1/finance/sales-invoices/{$invoice}/post", ['idempotencyKey' => 'p5-post-1'], $s['headers'])->assertOk();
        $this->assertSame('300.00', $posted->json('data.total'));
        $this->assertSame('unpaid', $posted->json('data.paymentStatus'));
        $line = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice)->sole();
        $this->assertSame('90.00', $line->cogs_total, 'Day 1: COGS = 90.');
        $journal = DB::table('journal_entries')->where('tenant_id', $s['tenant'])->where('source_type', 'sales_invoice')->where('source_id', $invoice)->sole();
        $arLine = DB::table('journal_entry_lines as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')->where('l.journal_entry_id', $journal->id)->where('a.code', '1200')->sole();
        $this->assertSame('300.00', $arLine->debit, 'Day 1: AR = 300.');
        $closing1 = $this->closing($s, $day1);
        $this->assertSame('0.00', $closing1['cash']['customerPaymentsCash'], 'Day 1: Cash = 0 (credit invoice never moves cash).');

        [$cashMethod, $cashLocation] = $this->cashMethodAndLocation($s['tenant'], $s['branch']);
        [$bankMethod, $bankLocation] = $this->bankMethodAndLocation($s);

        // Day 2: Customer pays Cash = 100 -> AR = 200.
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => $day2, 'amount' => '100.00',
            'paymentMethodId' => $cashMethod, 'financialLocationId' => $cashLocation, 'idempotencyKey' => 'p5-pay-1',
            'allocations' => [['invoiceId' => $invoice, 'amount' => '100.00']],
        ], $s['headers'])->assertCreated();
        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '200.00');
        $closing2 = $this->closing($s, $day2);
        $this->assertSame('100.00', $closing2['cash']['customerPaymentsCash'], 'Day 2: cash collection = 100.');
        $this->assertSame('0.00', $closing2['sales']['netSales'], 'Day 2: a later cash receipt is never counted as new sales.');

        // Day 3: Customer pays Bank = 200 -> AR = 0.
        $this->postJson('/api/v1/finance/customer-payments', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'paymentDate' => $day3, 'amount' => '200.00',
            'paymentMethodId' => $bankMethod, 'financialLocationId' => $bankLocation, 'idempotencyKey' => 'p5-pay-2',
            'allocations' => [['invoiceId' => $invoice, 'amount' => '200.00']],
        ], $s['headers'])->assertCreated();
        $this->getJson("/api/v1/finance/sales-invoices/{$invoice}", $s['headers'])->assertOk()->assertJsonPath('data.remainingAmount', '0.00')->assertJsonPath('data.paymentStatus', 'paid');
        $closing3 = $this->closing($s, $day3);
        $this->assertSame('0.00', $closing3['cash']['customerPaymentsCash'], 'Day 3: bank receipt must not move physical cash.');

        // Day 4: Credit Note = 100 (1 of 3 units), COGS reversal = 30. Invoice
        // already fully paid, so the entire 100 becomes unapplied customer
        // credit (ar_reduction is capped at the 0 outstanding balance).
        $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice)->value('id');
        $creditNote = $this->postJson('/api/v1/finance/sales-credit-notes', [
            'originalSalesInvoiceId' => $invoice, 'creditDate' => $day4, 'reason' => 'Return 1 unit', 'idempotencyKey' => 'p5-cn-1',
            'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '1', 'restock' => true]],
        ], $s['headers'])->assertCreated()->json('data.id');
        $postedCredit = $this->postJson("/api/v1/finance/sales-credit-notes/{$creditNote}/post", ['idempotencyKey' => 'p5-cn-post-1'], $s['headers'])->assertOk();
        $this->assertSame('100.00', $postedCredit->json('data.total'), 'Day 4: Credit Note total = 100.');
        $this->assertSame('0.00', $postedCredit->json('data.arReductionAmount'), 'Day 4: AR already 0, nothing left to reduce.');
        $this->assertSame('100.00', $postedCredit->json('data.customerCreditAmount'), 'Day 4: entire 100 becomes customer credit.');
        $creditLine = DB::table('sales_credit_note_lines')->where('sales_credit_note_id', $creditNote)->sole();
        $this->assertSame('30.00', $creditLine->cogs_total, 'Day 4: COGS reversal = 30.');
        $closing4 = $this->closing($s, $day4);
        $this->assertSame('0.00', $closing4['cash']['customerPaymentsCash'], 'Day 4: a Credit Note by itself never moves cash.');
        $this->assertSame('0.00', $closing4['cash']['customerRefundsCash']);

        // Day 5: Customer Refund Cash = 100 -> Customer Credit = 0, cash outflow = 100.
        $this->postJson('/api/v1/finance/customer-refunds', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'refundDate' => $day5, 'amount' => '100.00',
            'paymentMethodId' => $cashMethod, 'financialLocationId' => $cashLocation, 'idempotencyKey' => 'p5-refund-1',
        ], $s['headers'])->assertCreated();
        $availableCredit = $this->getJson("/api/v1/finance/customers/{$s['customer']}/credit", $s['headers'])->assertOk()->json('data.availableCredit');
        $this->assertSame('0.00', $availableCredit, 'Day 5: Customer Credit = 0 after the refund consumes it.');
        $closing5 = $this->closing($s, $day5);
        $this->assertSame('100.00', $closing5['cash']['customerRefundsCash'], 'Day 5: cash outflow = 100.');

        // The customer statement is the single reconciling proof: opening 0,
        // then +300 (invoice), -100 (payment), -200 (payment), -100 (credit
        // note, its full total — see FinancialReportQueryService::customerStatement()),
        // +100 (refund) = running balance 300, 200, 0, -100, 0 exactly.
        $statement = $this->getJson('/api/v1/finance/reports/customer-statement?customerId='.$s['customer'].'&dateFrom='.$day1.'&dateTo='.$day5, $s['headers'])->assertOk()->json('data');
        $this->assertSame('0.00', $statement['openingBalance']);
        $balances = array_column($statement['lines'], 'runningBalance');
        $this->assertSame(['300.00', '200.00', '0.00', '-100.00', '0.00'], $balances);
        $this->assertSame('0.00', $statement['closingBalance']);

        // AR aging as of Day 3 (fully paid, nothing outstanding) is empty; as
        // of Day 1 (before any payment) the full 300 sits in the current
        // bucket for a same-day-or-later due date.
        $agingDay1 = $this->getJson('/api/v1/finance/reports/customer-aging?asOfDate='.$day1, $s['headers'])->assertOk()->json('data');
        $this->assertSame('300.00', $agingDay1['totals']['totalOutstanding']);
        $agingDay3 = $this->getJson('/api/v1/finance/reports/customer-aging?asOfDate='.$day3, $s['headers'])->assertOk()->json('data');
        $this->assertSame('0.00', $agingDay3['totals']['totalOutstanding']);
    }

    private function closing(array $s, string $date): array
    {
        return $this->getJson('/api/v1/finance/daily-closing?date='.$date.'&branchId='.$s['branch'], $s['headers'])->assertOk()->json('data');
    }

    private function scenario(): array
    {
        $suffix = (string) str()->uuid();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Sales P5', 'slug' => "sales-p5-{$suffix}", 'status' => 'active', 'tax_rate' => '0.000000', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Downtown', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => "sales-p5-{$suffix}@test.local", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner);
        $warehouse = (int) DB::table('branches')->where('tenant_id', $tenant)->where('id', $branch)->value('pos_inventory_warehouse_id');
        $token = "sales-p5-{$suffix}";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $owner, 'name' => 'sales-p5', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
        $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'Damascus Tech Company'], $headers)->assertCreated()->json('data.id');

        $material = (int) DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee Beans', 'name_ar' => 'Coffee Beans', 'name_en' => 'Coffee Beans', 'sku' => "MAT-{$suffix}", 'catalog_identity' => "mat-{$suffix}", 'item_type' => 'raw_material', 'unit' => 'piece', 'minimum_stock' => '0.000', 'reorder_level' => '0.000', 'cost_per_unit' => '30.0000', 'latest_unit_cost' => '30.0000', 'is_active' => true, 'created_by' => $owner, 'updated_by' => $owner, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('inventory_item_warehouses')->insert(['tenant_id' => $tenant, 'inventory_item_id' => $material, 'warehouse_id' => $warehouse, 'created_at' => now(), 'updated_at' => now()]);
        app(InventoryPostingService::class)->post(Request::create('/stock-in', 'POST'), $tenant, ['warehouseId' => $warehouse, 'branchId' => $branch, 'itemId' => $material, 'type' => 'stock_in', 'quantity' => '100.000', 'unit' => 'piece', 'unitCost' => '30.0000', 'idempotencyKey' => "opening-{$suffix}"], $owner);
        $product = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Cappuccino', 'name_ar' => 'Cappuccino', 'sku' => "PROD-{$suffix}", 'price' => '100.00', 'is_active' => true, 'is_stock_tracked' => true, 'inventory_controlled' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = (int) DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => '100.00', 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $recipe = (int) DB::table('variant_recipes')->insertGetId(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('variant_recipe_components')->insert(['tenant_id' => $tenant, 'variant_recipe_id' => $recipe, 'inventory_item_id' => $material, 'quantity' => '1.000000', 'unit_code' => 'piece', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);

        return compact('tenant', 'branch', 'owner', 'headers', 'warehouse', 'material', 'product', 'customer');
    }

    /** @return array{0:int,1:int} [paymentMethodId, financialLocationId] */
    private function cashMethodAndLocation(int $tenant, int $branch): array
    {
        // The branch-specific drawer (CASH-DRAWER-BR-{branch}), not the
        // legacy tenant-wide CASH-DRAWER — see FinancialSetupService::
        // ensureBranchCashDrawer. A branch-scoped customer payment must use
        // a location that belongs to that branch.
        return [(int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id'), (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER-BR-'.$branch)->value('id')];
    }

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
