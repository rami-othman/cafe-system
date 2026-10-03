<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/** Payment terms (cash / credit / Sham Cash), the per-invoice warehouse, and the backdate reason supplied at post time. */
final class SalesInvoiceTermsTest extends TestCase
{
    use DailyClosingFixtures;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-28 09:00:00', 'UTC'));
    }

    private function scenario(): array
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'terms');
        $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'عميل الشروط'], $headers)->assertCreated()->json('data.id');
        $product = (int) DB::table('products')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'اختبار', 'name_ar' => 'اختبار', 'sku' => 'TERMS-'.uniqid(),
            'price' => '50.00', 'is_active' => true, 'is_stock_tracked' => false, 'created_at' => now(), 'updated_at' => now(),
        ]);

        return ['tenant' => $tenant, 'branch' => $this->branchId($tenant), 'headers' => $headers, 'customer' => $customer, 'product' => $product];
    }

    private function draft(array $s, array $extra = []): array
    {
        return $this->postJson('/api/v1/finance/sales-invoices', array_merge([
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-09-28',
            'lines' => [['productId' => $s['product'], 'quantity' => '1']],
        ], $extra), $s['headers'])->assertCreated()->json('data');
    }

    private function method(int $tenant, string $type): array
    {
        $m = DB::table('payment_methods')->where('tenant_id', $tenant)->where('type', $type)->where('is_active', true)->first();
        $this->assertNotNull($m, "payment method of type {$type} must be seeded");

        $location = $m->financial_location_id ?: DB::table('branches')->where('tenant_id', $tenant)->value('pos_cash_financial_location_id');

        return [(int) $m->id, $location ? (int) $location : null];
    }

    public function test_due_date_only_matters_for_credit(): void
    {
        $s = $this->scenario();
        $credit = $this->draft($s, ['paymentTerms' => 'credit', 'dueDate' => '2026-10-20']);
        $this->assertSame('credit', $credit['paymentTerms']);
        $this->assertSame('2026-10-20', $credit['dueDate']);

        $cash = $this->draft($s, ['paymentTerms' => 'cash', 'dueDate' => '2026-10-20']);
        $this->assertSame('cash', $cash['paymentTerms']);
        $this->assertSame('2026-09-28', $cash['dueDate'], 'a cash invoice is due on its own date');
    }

    public function test_cash_named_customer_cannot_be_posted_on_credit_and_must_pay_in_full(): void
    {
        $s = $this->scenario();
        $inv = $this->draft($s, ['paymentTerms' => 'cash']);
        $this->postJson("/api/v1/finance/sales-invoices/{$inv['id']}/post", ['idempotencyKey' => 'terms-plain-post'], $s['headers'])->assertUnprocessable();
        $this->assertSame('draft', DB::table('sales_invoices')->where('id', $inv['id'])->value('status'));

        [$cashMethod, $location] = $this->method($s['tenant'], 'cash');
        $payload = ['postIdempotencyKey' => 'terms-cash-post', 'paymentIdempotencyKey' => 'terms-cash-pay', 'paymentDate' => '2026-09-28',
            'paymentMethodId' => $cashMethod, 'financialLocationId' => $location,
            'allocations' => [['invoiceId' => $inv['id'], 'amount' => $inv['total']]]];
        $this->postJson("/api/v1/finance/sales-invoices/{$inv['id']}/post-and-collect", $payload + ['amount' => '1.00'], $s['headers'])
            ->assertUnprocessable()->assertJsonValidationErrors('amount');
        $this->assertSame('draft', DB::table('sales_invoices')->where('id', $inv['id'])->value('status'), 'a short payment must not post the invoice');
    }

    public function test_sham_cash_invoice_requires_the_transaction_number_and_uses_the_sham_method(): void
    {
        $s = $this->scenario();
        [$shamMethod, $shamLocation] = $this->method($s['tenant'], 'sham_cash');
        [$cashMethod, $cashLocation] = $this->method($s['tenant'], 'cash');
        $inv = $this->draft($s, ['paymentTerms' => 'sham_cash']);
        $base = ['postIdempotencyKey' => 'terms-sham-post', 'paymentIdempotencyKey' => 'terms-sham-pay', 'paymentDate' => '2026-09-28', 'amount' => $inv['total'],
            'allocations' => [['invoiceId' => $inv['id'], 'amount' => $inv['total']]]];

        $this->postJson("/api/v1/finance/sales-invoices/{$inv['id']}/post-and-collect", $base + ['paymentMethodId' => $cashMethod, 'financialLocationId' => $cashLocation], $s['headers'])->assertUnprocessable();
        $this->postJson("/api/v1/finance/sales-invoices/{$inv['id']}/post-and-collect", $base + ['paymentMethodId' => $shamMethod, 'financialLocationId' => $shamLocation], $s['headers'])
            ->assertUnprocessable()->assertJsonValidationErrors('reference');
        $this->postJson("/api/v1/finance/sales-invoices/{$inv['id']}/post-and-collect", $base + ['paymentMethodId' => $shamMethod, 'financialLocationId' => $shamLocation, 'reference' => 'SH-778899'], $s['headers'])->assertOk();

        $this->assertSame('SH-778899', DB::table('customer_payments')->where('tenant_id', $s['tenant'])->where('payment_method_id', $shamMethod)->value('external_reference'));
        $this->assertEquals($inv['total'], DB::table('journal_entry_lines')->where('tenant_id', $s['tenant'])->where('financial_location_id', $shamLocation)->sum('debit'), 'the money lands in the Sham Cash box');
    }

    public function test_backdated_draft_without_reason_can_be_posted_with_one_supplied_at_post_time(): void
    {
        $s = $this->scenario();
        $inv = $this->draft($s, ['invoiceDate' => '2026-09-20', 'backdateReason' => 'x-initial', 'paymentTerms' => 'credit']);
        DB::table('sales_invoices')->where('id', $inv['id'])->update(['backdate_reason' => null]);

        $this->postJson("/api/v1/finance/sales-invoices/{$inv['id']}/post", ['idempotencyKey' => 'terms-bd-1'], $s['headers'])
            ->assertUnprocessable()->assertJsonValidationErrors('backdateReason');
        $this->postJson("/api/v1/finance/sales-invoices/{$inv['id']}/post", ['idempotencyKey' => 'terms-bd-2', 'backdateReason' => 'تسجيل متأخر بطلب الإدارة'], $s['headers'])->assertOk();
        $this->assertSame('تسجيل متأخر بطلب الإدارة', DB::table('sales_invoices')->where('id', $inv['id'])->value('backdate_reason'));
    }

    public function test_invoice_warehouse_must_be_active_and_belong_to_the_branch(): void
    {
        $s = $this->scenario();
        $otherBranch = (int) DB::table('branches')->insertGetId(['tenant_id' => $s['tenant'], 'name' => 'فرع آخر', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $foreign = (int) DB::table('warehouses')->insertGetId(['tenant_id' => $s['tenant'], 'branch_id' => $otherBranch, 'name' => 'مستودع غريب', 'code' => 'FW-'.uniqid(), 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $own = (int) DB::table('warehouses')->insertGetId(['tenant_id' => $s['tenant'], 'branch_id' => $s['branch'], 'name' => 'مستودع الفرع', 'code' => 'OW-'.uniqid(), 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        $this->postJson('/api/v1/finance/sales-invoices', [
            'branchId' => $s['branch'], 'customerId' => $s['customer'], 'invoiceDate' => '2026-09-28', 'warehouseId' => $foreign,
            'lines' => [['productId' => $s['product'], 'quantity' => '1']],
        ], $s['headers'])->assertUnprocessable()->assertJsonValidationErrors('warehouseId');

        $inv = $this->draft($s, ['warehouseId' => $own]);
        $this->assertSame($own, $inv['warehouseId']);
    }

    public function test_purchase_invoice_due_date_is_required_for_credit_only(): void
    {
        $s = $this->scenario();
        $supplier = $this->supplierId($s['tenant']);
        $base = ['branchId' => $s['branch'], 'supplierId' => $supplier, 'invoiceDate' => '2026-09-28', 'invoiceType' => 'inventory', 'subtotal' => '30.00'];

        $this->postJson('/api/v1/finance/supplier-invoices', $base + ['invoiceNumber' => 'TERMS-P1', 'paymentTerms' => 'credit'], $s['headers'])
            ->assertUnprocessable()->assertJsonValidationErrors('dueDate');
        $cash = $this->postJson('/api/v1/finance/supplier-invoices', $base + ['invoiceNumber' => 'TERMS-P2', 'paymentTerms' => 'cash'], $s['headers'])->assertCreated()->json('data');
        $this->assertSame('cash', $cash['paymentTerms']);
        $this->assertSame('2026-09-28', $cash['dueDate']);
        $sham = $this->postJson('/api/v1/finance/supplier-invoices', $base + ['invoiceNumber' => 'TERMS-P3', 'paymentTerms' => 'sham_cash', 'paymentReference' => 'SH-1'], $s['headers'])->assertCreated()->json('data');
        $this->assertSame('SH-1', $sham['paymentReference']);
    }

    public function test_sham_purchase_lets_the_user_choose_which_sham_cash_box_pays(): void
    {
        $s = $this->scenario();
        $supplier = $this->supplierId($s['tenant']);
        [$firstMethod, $firstLocation] = $this->method($s['tenant'], 'sham_cash');

        // A second Sham Cash box with its own location and payment method.
        $location = (array) DB::table('financial_locations')->where('id', $firstLocation)->first();
        unset($location['id']);
        foreach (['code', 'name', 'name_ar', 'name_en'] as $column) {
            if (array_key_exists($column, $location) && $location[$column] !== null) {
                $location[$column] .= ' 2';
            }
        }
        $secondLocation = (int) DB::table('financial_locations')->insertGetId($location);
        $method = (array) DB::table('payment_methods')->where('id', $firstMethod)->first();
        unset($method['id']);
        foreach (['code', 'name', 'name_ar', 'name_en'] as $column) {
            if (array_key_exists($column, $method) && $method[$column] !== null) {
                $method[$column] .= ' 2';
            }
        }
        $method['financial_location_id'] = $secondLocation;
        $secondMethod = (int) DB::table('payment_methods')->insertGetId($method);

        $invoice = $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $s['branch'], 'supplierId' => $supplier, 'invoiceDate' => '2026-09-28', 'invoiceType' => 'inventory',
            'subtotal' => '30.00', 'invoiceNumber' => 'SHAM-CHOICE', 'paymentTerms' => 'sham_cash', 'paymentReference' => 'SH-CH-1',
        ], $s['headers'])->assertCreated()->json('data');

        $preview = $this->getJson("/api/v1/finance/purchases/{$invoice['id']}/posting-preview", $s['headers'])->assertOk();
        $preview->assertJsonPath('data.cashSourceMode', 'sham_cash');
        $this->assertEqualsCanonicalizing([$firstMethod, $secondMethod], array_column($preview->json('data.shamCashMethods'), 'id'));

        $this->postJson("/api/v1/finance/purchases/{$invoice['id']}/post", [
            'idempotencyKey' => 'sham-choice-post', 'paymentMethodId' => $secondMethod,
        ], $s['headers'])->assertOk();
        $this->assertSame($secondMethod, (int) DB::table('supplier_payments')->where('tenant_id', $s['tenant'])->value('payment_method_id'));
        $this->assertGreaterThan(0, (float) DB::table('journal_entry_lines')->where('tenant_id', $s['tenant'])->where('financial_location_id', $secondLocation)->sum('credit'), 'the chosen Sham Cash box is the one that pays');
        $this->assertEquals(0, DB::table('journal_entry_lines')->where('tenant_id', $s['tenant'])->where('financial_location_id', $firstLocation)->sum('credit'));
    }

    public function test_a_posted_credit_purchase_can_be_paid_in_parts_from_its_own_page(): void
    {
        $s = $this->scenario();
        $supplier = $this->supplierId($s['tenant']);
        [$methodId, $locationId] = $this->method($s['tenant'], 'sham_cash');
        $invoice = $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $s['branch'], 'supplierId' => $supplier, 'invoiceDate' => '2026-09-28', 'invoiceType' => 'inventory',
            'subtotal' => '100.00', 'invoiceNumber' => 'PAY-FROM-PAGE', 'paymentTerms' => 'credit', 'dueDate' => '2026-10-28',
        ], $s['headers'])->assertCreated()->json('data');
        $this->postJson("/api/v1/finance/purchases/{$invoice['id']}/post", ['idempotencyKey' => 'pay-page-post', 'paidAmount' => '0.00'], $s['headers'])->assertOk();

        $show = $this->getJson("/api/v1/finance/purchases/{$invoice['id']}", $s['headers'])->assertOk();
        $this->assertContains('pay', $show->json('data.allowedActions'));
        $show->assertJsonPath('data.remainingAmount', '100.00');

        $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplier, 'branchId' => $s['branch'], 'paymentDate' => '2026-09-28', 'amount' => '40.00',
            'paymentMethodId' => $methodId, 'financialLocationId' => $locationId, 'idempotencyKey' => 'pay-page-1',
            'allocations' => [['invoiceId' => $invoice['id'], 'amount' => '40.00']],
        ], $s['headers'])->assertCreated();

        $after = $this->getJson("/api/v1/finance/purchases/{$invoice['id']}", $s['headers'])->assertOk();
        $after->assertJsonPath('data.paidAmount', '40.00')->assertJsonPath('data.remainingAmount', '60.00');
        $this->assertCount(1, $after->json('data.payments'));
        $this->assertContains('pay', $after->json('data.allowedActions'));
    }
}
