<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SalesInvoicePhaseOneApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_draft_sales_invoice_uses_server_price_and_tax_and_has_zero_finance_inventory_and_pos_effect(): void
    {
        $tenant = $this->tenant('sales-draft'); $headers = $this->headers($tenant); $branch = $this->branch($tenant); $product = $this->product($tenant, 'Latte', '12.50');
        $customer = $this->postJson('/api/v1/finance/customers', ['name' => 'Damascus Tech Company', 'defaultCreditTermsDays' => 30], $headers)->assertCreated()->json('data.id');
        $before = ['journals' => DB::table('journal_entries')->where('tenant_id', $tenant)->count(), 'moves' => DB::table('stock_movements')->where('tenant_id', $tenant)->count(), 'orders' => DB::table('orders')->where('tenant_id', $tenant)->count(), 'payments' => DB::table('payments')->where('tenant_id', $tenant)->count()];
        $created = $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $branch, 'customerId' => $customer, 'invoiceDate' => '2026-09-12', 'idempotencyKey' => 'sales-draft-1', 'lines' => [['productId' => $product, 'quantity' => '2', 'unitPrice' => '999.99', 'total' => '9999.99']]], $headers)
            ->assertCreated()->assertJsonPath('data.status', 'draft')->assertJsonPath('data.subtotal', '25.00')->assertJsonPath('data.taxTotal', '2.00')->assertJsonPath('data.total', '27.00')->assertJsonPath('data.dueDate', '2026-10-12')->assertJsonPath('data.accountingStatus', 'unposted')->assertJsonPath('data.inventoryStatus', 'not_consumed');
        $id = $created->json('data.id');
        $this->assertMatchesRegularExpression('/^SI-2026-\d{6}$/', $created->json('data.invoiceNumber'));
        $this->assertSame('12.50', $created->json('data.lines.0.unitPrice'));
        $this->assertSame(1, DB::table('sales_invoices')->where('id', $id)->count());
        $this->assertSame(1, DB::table('sales_invoice_lines')->where('sales_invoice_id', $id)->count());
        $this->assertSame($before['journals'], DB::table('journal_entries')->where('tenant_id', $tenant)->count());
        $this->assertSame($before['moves'], DB::table('stock_movements')->where('tenant_id', $tenant)->count());
        $this->assertSame($before['orders'], DB::table('orders')->where('tenant_id', $tenant)->count());
        $this->assertSame($before['payments'], DB::table('payments')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('sales_invoice_costs')->where('sales_invoice_id', $id)->count());
        $this->assertSame(1, DB::table('activity_logs')->where('tenant_id', $tenant)->where('entity_type', 'sales_invoice')->where('entity_id', $id)->where('action', 'sales.invoice.created')->count());
    }

    public function test_create_is_idempotent_drafts_are_editable_and_cancellable_but_never_postable(): void
    {
        $tenant = $this->tenant('sales-idempotency'); $headers = $this->headers($tenant); $branch = $this->branch($tenant); $customer = $this->customer($headers, 'Al Noor Offices'); $product = $this->product($tenant, 'Cappuccino', '10.00');
        $payload = ['branchId' => $branch, 'customerId' => $customer, 'invoiceDate' => '2026-09-12', 'idempotencyKey' => 'same-click', 'lines' => [['productId' => $product, 'quantity' => '1']]];
        $first = $this->postJson('/api/v1/finance/sales-invoices', $payload, $headers)->assertCreated()->json('data.id');
        $second = $this->postJson('/api/v1/finance/sales-invoices', $payload, $headers)->assertCreated()->json('data.id');
        $this->assertSame($first, $second); $this->assertSame(1, DB::table('sales_invoices')->where('tenant_id', $tenant)->count());
        $this->patchJson("/api/v1/finance/sales-invoices/{$first}", ['lines' => [['productId' => $product, 'quantity' => '3']]], $headers)->assertOk()->assertJsonPath('data.total', '32.40')->assertJsonPath('data.allowedActions.canPost', true);
        $this->postJson("/api/v1/finance/sales-invoices/{$first}/cancel", ['reason' => 'Customer requested revision'], $headers)->assertOk()->assertJsonPath('data.status', 'cancelled')->assertJsonPath('data.allowedActions.canPost', false);
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_id', $first)->count());
    }

    public function test_customer_and_product_tenant_isolation_and_protected_walk_in_behavior_are_enforced(): void
    {
        $tenantA = $this->tenant('sales-a'); $headersA = $this->headers($tenantA); $productA = $this->product($tenantA, 'Cake Slice', '8.00');
        $tenantB = $this->tenant('sales-b'); $headersB = $this->headers($tenantB); $customerB = $this->customer($headersB, 'Tenant B Customer'); $branchB = $this->branch($tenantB);
        $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $branchB, 'customerId' => $customerB, 'invoiceDate' => '2026-09-12', 'lines' => [['productId' => $productA, 'quantity' => '1']]], $headersB)->assertUnprocessable()->assertJsonValidationErrors('lines.0.productId');
        $walkIn = (int) DB::table('customers')->where('tenant_id', $tenantA)->where('is_walk_in', true)->value('id');
        $this->patchJson("/api/v1/finance/customers/{$walkIn}", ['isActive' => false], $headersA)->assertUnprocessable()->assertJsonValidationErrors('isActive');
        $this->assertSame(1, DB::table('sales_account_mappings')->where('tenant_id', $tenantA)->where('mapping_key', 'sales.accounts_receivable')->count());
        $this->assertSame('1200', DB::table('financial_accounts as a')->join('sales_account_mappings as m', 'm.financial_account_id', '=', 'a.id')->where('m.tenant_id', $tenantA)->where('m.mapping_key', 'sales.accounts_receivable')->value('a.code'));
    }

    private function tenant(string $slug): int { $id = (int) DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'status' => 'active', 'tax_rate' => '0.080000', 'created_at' => now(), 'updated_at' => now()]); DB::table('branches')->insert(['tenant_id' => $id, 'name' => 'Central', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); app(FinancialSetupService::class)->ensureForTenant($id); return $id; }
    private function branch(int $tenant): int { return (int) DB::table('branches')->where('tenant_id', $tenant)->value('id'); }
    private function headers(int $tenant): array { $user = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Sales Owner', 'email' => "sales-owner-{$tenant}@test.local", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); $token = "sales-token-{$tenant}"; DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'sales-test', 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]); return ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant]; }
    private function customer(array $headers, string $name): int { return (int) $this->postJson('/api/v1/finance/customers', ['name' => $name], $headers)->assertCreated()->json('data.id'); }
    private function product(int $tenant, string $name, string $price): int { return (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'name_ar' => $name, 'sku' => 'S-'.uniqid(), 'price' => $price, 'is_active' => true, 'is_stock_tracked' => false, 'created_at' => now(), 'updated_at' => now()]); }
}
