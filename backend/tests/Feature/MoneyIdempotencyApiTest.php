<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * PosApiSmokeTest already covers the golden-path payment/refund idempotent
 * replay inside a full checkout flow. These tests isolate the edge cases
 * called out specifically in docs/finance/FINANCE_IMPLEMENTATION_PLAN.md:
 * cross-tenant key reuse must be safe, and reusing a key for a genuinely
 * different business request must be rejected rather than silently
 * returning the wrong resource.
 */
class MoneyIdempotencyApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_two_tenants_may_safely_reuse_the_identical_idempotency_key_for_payments(): void
    {
        $tenantA = $this->tenantId();
        $tenantB = $this->otherTenant();
        $orderA = $this->unpaidOrder($tenantA, 25.00);
        $orderB = $this->unpaidOrder($tenantB, 25.00);

        $payA = $this->postJson("/api/v1/orders/{$orderA}/pay", ['method' => 'cash', 'amount' => 25.00, 'idempotencyKey' => 'shared-key-123'], $this->headers($tenantA))
            ->assertOk();
        $payB = $this->postJson("/api/v1/orders/{$orderB}/pay", ['method' => 'cash', 'amount' => 25.00, 'idempotencyKey' => 'shared-key-123'], $this->headers($tenantB))
            ->assertOk();

        $this->assertNotSame($payA->json('data.payment.id'), $payB->json('data.payment.id'));
        $this->assertSame(2, DB::table('payments')->where('idempotency_key', 'shared-key-123')->count());
    }

    public function test_reusing_a_payment_idempotency_key_for_a_different_order_is_rejected(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $orderOne = $this->unpaidOrder($tenantId, 10.00);
        $orderTwo = $this->unpaidOrder($tenantId, 10.00);

        $this->postJson("/api/v1/orders/{$orderOne}/pay", ['method' => 'cash', 'amount' => 10.00, 'idempotencyKey' => 'reuse-key'], $headers)
            ->assertOk();

        $this->postJson("/api/v1/orders/{$orderTwo}/pay", ['method' => 'cash', 'amount' => 10.00, 'idempotencyKey' => 'reuse-key'], $headers)
            ->assertStatus(409);

        $this->assertSame(1, DB::table('payments')->where('idempotency_key', 'reuse-key')->count());
    }

    public function test_reusing_a_payment_idempotency_key_with_a_changed_payload_is_rejected(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $orderId = $this->unpaidOrder($tenantId, 10.00);

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => 10.00, 'idempotencyKey' => 'changed-payment'], $headers)
            ->assertOk();

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'card', 'amount' => 10.00, 'idempotencyKey' => 'changed-payment'], $headers)
            ->assertStatus(409);
        $this->assertSame(1, DB::table('payments')->where('idempotency_key', 'changed-payment')->count());
    }

    public function test_reusing_a_refund_idempotency_key_for_a_different_order_is_rejected(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $orderOne = $this->paidOrder($tenantId, 50.00);
        $orderTwo = $this->paidOrder($tenantId, 50.00);

        $this->postJson("/api/v1/orders/{$orderOne}/refunds", ['type' => 'full', 'reason' => 'A', 'idempotencyKey' => 'refund-reuse'], $headers)
            ->assertCreated();

        $this->postJson("/api/v1/orders/{$orderTwo}/refunds", ['type' => 'full', 'reason' => 'B', 'idempotencyKey' => 'refund-reuse'], $headers)
            ->assertStatus(409);

        $this->assertSame(1, DB::table('payment_refunds')->where('idempotency_key', 'refund-reuse')->count());
    }

    public function test_reusing_a_refund_idempotency_key_with_a_changed_payload_is_rejected(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $orderId = $this->paidOrder($tenantId, 50.00);

        $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'partial', 'amount' => 10.00, 'reason' => 'First reason', 'idempotencyKey' => 'changed-refund'], $headers)
            ->assertCreated();

        $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'partial', 'amount' => 11.00, 'reason' => 'Changed request', 'idempotencyKey' => 'changed-refund'], $headers)
            ->assertStatus(409);
        $this->assertSame(1, DB::table('payment_refunds')->where('idempotency_key', 'changed-refund')->count());
    }

    public function test_replaying_an_order_creation_request_with_the_same_key_returns_the_original_order(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
        $productId = (int) DB::table('products')->where('tenant_id', $tenantId)->where('name', 'Cappuccino')->value('id');
        $modifiers = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->join('modifier_options', 'modifier_options.modifier_group_id', '=', 'modifier_groups.id')
            ->where('product_modifier_group.product_id', $productId)
            ->where('modifier_groups.is_required', true)
            ->where('modifier_options.is_default', true)
            ->select(['modifier_groups.id as groupId', 'modifier_options.id as optionId'])
            ->get()
            ->map(fn ($modifier) => ['groupId' => $modifier->groupId, 'optionId' => $modifier->optionId])
            ->all();

        $payload = [
            'branchId' => $branchId,
            'orderType' => 'takeaway',
            'items' => [['productId' => $productId, 'quantity' => 1, 'modifiers' => $modifiers]],
            'idempotencyKey' => 'order-create-key-1',
        ];

        $first = $this->postJson('/api/v1/orders', $payload, $headers)->assertCreated();
        $replay = $this->postJson('/api/v1/orders', $payload, $headers)->assertOk();

        $this->assertSame($first->json('data.id'), $replay->json('data.id'));
        $this->assertSame(1, DB::table('orders')->where('idempotency_key', 'order-create-key-1')->count());
    }

    public function test_reusing_an_order_creation_idempotency_key_with_changed_items_is_rejected(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
        $productId = (int) DB::table('products')->where('tenant_id', $tenantId)->where('name', 'Cappuccino')->value('id');
        $modifiers = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->join('modifier_options', 'modifier_options.modifier_group_id', '=', 'modifier_groups.id')
            ->where('product_modifier_group.product_id', $productId)
            ->where('modifier_groups.is_required', true)
            ->where('modifier_options.is_default', true)
            ->select(['modifier_groups.id as groupId', 'modifier_options.id as optionId'])
            ->get()
            ->map(fn ($modifier) => ['groupId' => $modifier->groupId, 'optionId' => $modifier->optionId])
            ->all();

        $payload = ['branchId' => $branchId, 'orderType' => 'takeaway', 'items' => [['productId' => $productId, 'quantity' => 1, 'modifiers' => $modifiers]], 'idempotencyKey' => 'changed-order'];
        $this->postJson('/api/v1/orders', $payload, $headers)->assertCreated();
        $payload['items'][0]['quantity'] = 2;
        $this->postJson('/api/v1/orders', $payload, $headers)->assertStatus(409);
        $this->assertSame(1, DB::table('orders')->where('idempotency_key', 'changed-order')->count());
    }

    public function test_a_payment_amount_below_the_order_total_is_rejected_and_does_not_consume_the_idempotency_key(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $orderId = $this->unpaidOrder($tenantId, 40.00);

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => 10.00, 'idempotencyKey' => 'short-pay'], $headers)
            ->assertUnprocessable();

        $this->assertSame(0, DB::table('payments')->where('idempotency_key', 'short-pay')->count());

        // The same key can still be used once the request is corrected.
        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => 40.00, 'idempotencyKey' => 'short-pay'], $headers)
            ->assertOk();
        $this->assertSame(1, DB::table('payments')->where('idempotency_key', 'short-pay')->count());
    }

    private function unpaidOrder(int $tenantId, float $total): int
    {
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');

        return (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_number' => 'IDEMP-'.uniqid(),
            'type' => 'dine_in', 'status' => 'draft', 'payment_status' => 'unpaid',
            'subtotal' => $total, 'discount_total' => 0, 'tax_total' => 0, 'total' => $total,
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function paidOrder(int $tenantId, float $amount): int
    {
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
        $orderId = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_number' => 'IDEMP-PAID-'.uniqid(),
            'type' => 'dine_in', 'status' => 'paid', 'payment_status' => 'paid', 'total' => $amount,
            'closed_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('payments')->insert([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_id' => $orderId,
            'method' => 'cash', 'amount' => $amount, 'currency' => 'SYP', 'status' => 'completed',
            'paid_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);

        return $orderId;
    }

    private function tenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function otherTenant(): int
    {
        static $tenantId = null;
        if ($tenantId !== null) {
            return $tenantId;
        }
        $tenantId = (int) DB::table('tenants')->insertGetId(['name' => 'Idempotency Tenant B', 'slug' => 'idempotency-tenant-b', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Branch B', 'currency' => 'SYP', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('users')->insert(['tenant_id' => $tenantId, 'name' => 'Owner B', 'email' => 'owner-b@example.test', 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return $tenantId;
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = "money-idempotency-test-{$tenantId}";
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'money-idempotency-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken"];
    }
}
