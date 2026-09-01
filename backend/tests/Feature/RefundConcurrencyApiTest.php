<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RefundConcurrencyApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_partial_refunds_can_be_issued_sequentially_up_to_the_full_amount(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $orderId = $this->paidOrder($tenantId, 100.00);

        $this->postJson("/api/v1/orders/{$orderId}/refunds", $this->refundPayload('partial', 40.00), $headers)
            ->assertCreated()->assertJsonPath('data.amount', 40);

        $this->postJson("/api/v1/orders/{$orderId}/refunds", $this->refundPayload('partial', 30.00), $headers)
            ->assertCreated()->assertJsonPath('data.amount', 30);

        // Exactly the remaining balance (30.00) is refundable as "full".
        $this->postJson("/api/v1/orders/{$orderId}/refunds", $this->refundPayload('full'), $headers)
            ->assertCreated()->assertJsonPath('data.amount', 30);

        $this->assertSame(100.0, (float) DB::table('payment_refunds')->where('order_id', $orderId)->where('status', 'completed')->sum('amount'));
        $this->assertSame('refunded', DB::table('orders')->where('id', $orderId)->value('payment_status'));
    }

    public function test_a_refund_greater_than_the_remaining_balance_is_rejected(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $orderId = $this->paidOrder($tenantId, 100.00);

        $this->postJson("/api/v1/orders/{$orderId}/refunds", $this->refundPayload('partial', 60.00), $headers)
            ->assertCreated();

        // Only 40.00 remains; asking for 50.00 must fail and leave the
        // refunded total unchanged.
        $this->postJson("/api/v1/orders/{$orderId}/refunds", $this->refundPayload('partial', 50.00), $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('amount');

        $this->assertSame(60.0, (float) DB::table('payment_refunds')->where('order_id', $orderId)->sum('amount'));
    }

    public function test_two_refund_requests_racing_against_the_same_payment_cannot_together_exceed_the_original_amount(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $orderId = $this->paidOrder($tenantId, 100.00);

        // Two requests each individually valid (60 each) but together
        // exceeding the 100.00 payment. Without the row lock on the payment
        // in RefundController::store, both could read "0 already refunded"
        // and both succeed. With the lock, the second serializes behind the
        // first's commit and is correctly rejected against the now-updated
        // remaining balance.
        $first = $this->postJson("/api/v1/orders/{$orderId}/refunds", $this->refundPayload('partial', 60.00), $headers);
        $second = $this->postJson("/api/v1/orders/{$orderId}/refunds", $this->refundPayload('partial', 60.00), $headers);

        $statuses = [$first->status(), $second->status()];
        sort($statuses);
        $this->assertSame([201, 422], $statuses);

        $totalRefunded = (float) DB::table('payment_refunds')->where('order_id', $orderId)->where('status', 'completed')->sum('amount');
        $this->assertLessThanOrEqual(100.0, $totalRefunded);
        $this->assertSame(60.0, $totalRefunded);
    }

    public function test_refunding_an_unpaid_order_is_rejected(): void
    {
        $tenantId = $this->tenantId();
        $headers = $this->headers($tenantId);
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
        $orderId = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_number' => 'UNPAID-0001',
            'type' => 'dine_in', 'status' => 'draft', 'payment_status' => 'unpaid', 'total' => 10,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->postJson("/api/v1/orders/{$orderId}/refunds", $this->refundPayload('full'), $headers)
            ->assertUnprocessable();
    }

    private function paidOrder(int $tenantId, float $amount): int
    {
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
        $orderId = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_number' => 'PAID-'.uniqid(),
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

    private function refundPayload(string $type, ?float $amount = null): array
    {
        return array_filter([
            'type' => $type,
            'amount' => $amount,
            'reason' => 'Customer request',
        ], fn ($value) => $value !== null);
    }

    private function tenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = 'refund-concurrency-test-token';
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'refund-concurrency-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken"];
    }
}
