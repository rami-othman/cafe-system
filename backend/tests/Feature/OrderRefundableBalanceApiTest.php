<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class OrderRefundableBalanceApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_order_detail_returns_the_authoritative_refundable_balance(): void
    {
        $tenant = $this->tenantId();
        $order = $this->paidOrder($tenant, 100.00);

        $this->getJson("/api/v1/orders/{$order}", $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.refundedAmount', 0)
            ->assertJsonPath('data.refundableAmount', 100);
    }

    public function test_unpaid_order_returns_zero_refundable_balance(): void
    {
        $tenant = $this->tenantId();
        $order = $this->unpaidOrder($tenant, 100.00);

        $this->getJson("/api/v1/orders/{$order}", $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.refundedAmount', 0)
            ->assertJsonPath('data.refundableAmount', 0);
    }

    public function test_partially_refunded_order_returns_only_the_remaining_balance(): void
    {
        $tenant = $this->tenantId();
        $order = $this->paidOrder($tenant, 100.00);
        $payment = DB::table('payments')->where('order_id', $order)->value('id');
        $this->refund($tenant, $order, (int) $payment, 20.00, 'partial-balance-key');

        $this->getJson("/api/v1/orders/{$order}", $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.refundedAmount', 20)
            ->assertJsonPath('data.refundableAmount', 80);
    }

    public function test_fully_refunded_order_returns_zero_refundable_balance(): void
    {
        $tenant = $this->tenantId();
        $order = $this->paidOrder($tenant, 100.00);
        $payment = DB::table('payments')->where('order_id', $order)->value('id');
        $this->refund($tenant, $order, (int) $payment, 100.00, 'full-balance-key');

        $this->getJson("/api/v1/orders/{$order}", $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.refundedAmount', 100)
            ->assertJsonPath('data.refundableAmount', 0);
    }

    public function test_order_list_does_not_query_payment_or_refund_balances_per_row(): void
    {
        $tenant = $this->tenantId();
        $this->paidOrder($tenant, 100.00);
        $this->paidOrder($tenant, 80.00);

        DB::flushQueryLog();
        DB::enableQueryLog();
        $response = $this->getJson('/api/v1/orders', $this->headers($tenant));
        $queries = DB::getQueryLog();
        DB::disableQueryLog();

        $paymentQueries = array_values(array_filter(
            $queries,
            static fn (array $query): bool => preg_match(
                '/\\b(?:payments|payment_refunds)\\b/i',
                $query['query'],
            ) === 1,
        ));

        $response->assertOk();
        $this->assertCount(0, $paymentQueries);
    }

    public function test_order_detail_keeps_tenant_and_branch_authorization(): void
    {
        $tenant = $this->tenantId();
        $foreignTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Foreign balance tenant',
            'slug' => 'foreign-balance-tenant',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $foreignBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $foreignTenant,
            'name' => 'Foreign branch',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $foreignOrder = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $foreignTenant,
            'branch_id' => $foreignBranch,
            'order_number' => 'FOREIGN-BALANCE-1',
            'type' => 'takeaway',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total' => 100,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->getJson("/api/v1/orders/{$foreignOrder}", $this->headers($tenant))
            ->assertNotFound();
    }

    private function paidOrder(int $tenant, float $amount): int
    {
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('is_active', true)->value('id');
        $order = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_number' => 'BALANCE-'.uniqid(),
            'type' => 'takeaway',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total' => $amount,
            'closed_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('payments')->insert([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_id' => $order,
            'method' => 'cash',
            'amount' => $amount,
            'currency' => 'SYP',
            'status' => 'completed',
            'paid_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $order;
    }

    private function unpaidOrder(int $tenant, float $amount): int
    {
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('is_active', true)->value('id');

        return (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_number' => 'UNPAID-BALANCE-'.uniqid(),
            'type' => 'takeaway',
            'status' => 'draft',
            'payment_status' => 'unpaid',
            'total' => $amount,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function refund(int $tenant, int $order, int $payment, float $amount, string $key): void
    {
        $branch = (int) DB::table('orders')->where('id', $order)->value('branch_id');
        DB::table('payment_refunds')->insert([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_id' => $order,
            'payment_id' => $payment,
            'refund_number' => 'BALANCE-REFUND-'.uniqid(),
            'type' => $amount === 100.00 ? 'full' : 'partial',
            'amount' => $amount,
            'reason' => 'Balance fixture',
            'manager_notes' => null,
            'status' => 'completed',
            'idempotency_key' => $key,
            'idempotency_hash' => hash('sha256', $key),
            'refunded_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function tenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function headers(int $tenant): array
    {
        $user = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        $token = 'order-balance-'.$tenant;
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'order-balance-test'],
            ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
    }
}
