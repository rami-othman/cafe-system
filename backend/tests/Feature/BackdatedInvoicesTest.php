<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

final class BackdatedInvoicesTest extends TestCase
{
    use DailyClosingFixtures;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-28 09:00:00', 'UTC'));
    }

    public function test_manual_sales_invoice_requires_a_reason_on_save_and_preserves_creation_time(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'backdated-sales');
        $customer = (int) $this->postJson('/api/v1/finance/customers', ['name' => 'عميل الاختبار'], $headers)->assertCreated()->json('data.id');
        $product = (int) DB::table('products')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'اختبار', 'name_ar' => 'اختبار', 'sku' => 'BACKDATE-'.uniqid(),
            'price' => '10.00', 'is_active' => true, 'is_stock_tracked' => false,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $payload = ['branchId' => $branch, 'customerId' => $customer, 'invoiceDate' => '2026-09-20',
            'lines' => [['productId' => $product, 'quantity' => '1']]];

        $this->postJson('/api/v1/finance/sales-invoices', $payload, $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('backdateReason');
        $created = $this->postJson('/api/v1/finance/sales-invoices', $payload + ['backdateReason' => 'طلب العميل تسجيل البيع السابق'], $headers)
            ->assertCreated()->json('data');
        $this->assertDatabaseHas('sales_invoices', ['id' => $created['id'], 'invoice_date' => '2026-09-20',
            'backdate_reason' => 'طلب العميل تسجيل البيع السابق']);
        $this->assertSame('2026-09-28', substr((string) DB::table('sales_invoices')->where('id', $created['id'])->value('created_at'), 0, 10));
    }

    public function test_purchase_reason_is_checked_on_save_and_again_on_post(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'backdated-purchase');
        $supplier = $this->supplierId($tenant);
        $payload = [
            'branchId' => $branch, 'supplierId' => $supplier, 'invoiceNumber' => 'BACKDATE-001',
            'invoiceDate' => '2026-09-20', 'dueDate' => '2026-09-28',
            'invoiceType' => 'inventory', 'subtotal' => '30.00',
        ];
        $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('backdateReason');
        $created = $this->postJson('/api/v1/finance/supplier-invoices', $payload + [
            'backdateReason' => 'فاتورة واردة بعد تاريخ الشراء',
        ], $headers)->assertCreated()->json('data');
        $this->assertDatabaseHas('supplier_invoices', [
            'id' => $created['id'], 'backdate_reason' => 'فاتورة واردة بعد تاريخ الشراء',
        ]);
        DB::table('daily_closings')->insert([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'business_date' => '2026-09-20',
            'reference' => 'BACKDATE-CLOSED', 'status' => 'closed', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->postJson("/api/v1/finance/supplier-invoices/{$created['id']}/post", ['idempotencyKey' => 'backdated-post'], $headers)
            ->assertOk()->assertJsonPath('warnings.0.code', 'DAY_ALREADY_CLOSED');
        $this->assertDatabaseHas('journal_entries', [
            'tenant_id' => $tenant, 'source_type' => 'supplier_invoice',
            'source_id' => $created['id'], 'entry_date' => '2026-09-20',
        ]);
        $legacy = $this->postJson('/api/v1/finance/supplier-invoices', [
            ...$payload, 'invoiceNumber' => 'BACKDATE-LEGACY', 'invoiceDate' => '2026-09-28',
        ], $headers)->assertCreated()->json('data.id');
        DB::table('supplier_invoices')->where('id', $legacy)->update(['invoice_date' => '2026-09-20', 'backdate_reason' => null]);
        $this->postJson("/api/v1/finance/supplier-invoices/{$legacy}/post", ['idempotencyKey' => 'legacy-post'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('backdateReason');
    }
}
