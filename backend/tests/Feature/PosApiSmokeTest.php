<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PosApiSmokeTest extends TestCase
{
    use RefreshDatabase;

    public function test_pos_order_flow_can_be_completed(): void
    {
        $this->seed();
        $headers = $this->headers();

        $branchId = DB::table('branches')->where('name', 'Downtown')->value('id');
        $productId = DB::table('products')->where('name', 'Cappuccino')->value('id');

        // TenantAccessSeeder now seeds 4 branches ("Main Branch" first, by
        // id) — assert Downtown is present rather than assuming array
        // position, which is the same stale-seed-drift issue already fixed
        // in DiscountManagementApiTest's branch-count assertion.
        $this->getJson('/api/v1/branches', $headers)
            ->assertOk()
            ->assertJsonFragment(['name' => 'Downtown']);

        $this->getJson("/api/v1/pos/state?branchId={$branchId}", $headers)
            ->assertOk()
            ->assertJsonPath('data.terminal.status', 'closed');

        $this->getJson('/api/v1/customers?search=Jane', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.tier', 'vip');

        $this->getJson("/api/v1/menu/products/{$productId}?branchId={$branchId}", $headers)
            ->assertOk()
            ->assertJsonPath('data.name', 'Cappuccino');

        $shift = $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branchId,
            'openingCash' => 0,
        ], $headers)
            ->assertCreated();

        $modifiers = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->join('modifier_options', 'modifier_options.modifier_group_id', '=', 'modifier_groups.id')
            ->where('product_modifier_group.product_id', $productId)
            ->where('modifier_groups.is_required', true)
            ->where('modifier_options.is_default', true)
            ->select([
                'modifier_groups.id as groupId',
                'modifier_options.id as optionId',
            ])
            ->get()
            ->map(fn ($modifier) => [
                'groupId' => $modifier->groupId,
                'optionId' => $modifier->optionId,
            ])
            ->all();

        $order = $this->postJson('/api/v1/orders', [
            'branchId' => $branchId,
            'shiftId' => $shift->json('data.id'),
            'orderType' => 'dine_in',
            'tableId' => DB::table('cafe_tables')->where('branch_id', $branchId)->value('id'),
            'items' => [
                [
                    'productId' => $productId,
                    'quantity' => 5,
                    'modifiers' => $modifiers,
                ],
            ],
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.status', 'draft');

        $orderId = $order->json('data.id');

        $this->getJson("/api/v1/discounts/available?orderId={$orderId}", $headers)
            ->assertOk()
            ->assertJsonPath('data.0.code', 'OPEN10');

        $discounted = $this->postJson("/api/v1/orders/{$orderId}/discounts/apply", [
            'code' => 'OPEN10',
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.discount.code', 'OPEN10');

        $this->getJson("/api/v1/orders/{$orderId}/payment-summary?amountReceived=30", $headers)
            ->assertOk()
            ->assertJsonPath('data.changeDue', round(30 - $discounted->json('data.totals.total'), 2));

        $payment = $this->postJson("/api/v1/orders/{$orderId}/pay", [
            'method' => 'cash',
            'amount' => 30,
            'idempotencyKey' => 'pos-smoke-pay-1',
        ], $headers)
            ->assertOk()
            ->assertJsonPath('data.payment.status', 'completed');

        // Replaying the exact same payment request (same idempotency key)
        // must return the original payment, not create a second one.
        $replayedPayment = $this->postJson("/api/v1/orders/{$orderId}/pay", [
            'method' => 'cash',
            'amount' => 30,
            'idempotencyKey' => 'pos-smoke-pay-1',
        ], $headers)
            ->assertOk();
        $this->assertSame($payment->json('data.payment.id'), $replayedPayment->json('data.payment.id'));
        $this->assertSame(1, DB::table('payments')->where('order_id', $orderId)->count());

        // A payment freezes the normal order workflow. The only permitted
        // money-changing follow-up is the explicit refund endpoint below.
        $this->patchJson("/api/v1/orders/{$orderId}", ['note' => 'late edit'], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/orders/{$orderId}/items", ['productId' => $productId, 'quantity' => 1, 'modifiers' => $modifiers], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/orders/{$orderId}/hold", [], $headers)->assertUnprocessable();
        $this->putJson("/api/v1/orders/{$orderId}/discount", ['type' => 'fixed', 'value' => 1], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/orders/{$orderId}/discounts/apply", ['code' => 'OPEN10'], $headers)->assertUnprocessable();
        $this->deleteJson("/api/v1/orders/{$orderId}/discounts", [], $headers)->assertUnprocessable();

        $this->getJson("/api/v1/orders/{$orderId}/receipt", $headers)
            ->assertOk()
            ->assertJsonPath('data.title', 'Cafe System 618');

        $this->postJson("/api/v1/orders/{$orderId}/print", [
            'type' => 'receipt',
        ], $headers)
            ->assertAccepted()
            ->assertJsonPath('data.status', 'queued');

        $this->postJson("/api/v1/orders/{$orderId}/refunds", [
            'type' => 'partial',
            'amount' => 5,
            'reason' => 'Customer Request',
            'managerNotes' => 'Approved from POS refund flow.',
            'idempotencyKey' => 'pos-smoke-refund-1',
        ], $headers)
            ->assertCreated()
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.paymentId', $payment->json('data.payment.id'));

        $this->getJson("/api/v1/orders/{$orderId}", $headers)
            ->assertOk()
            ->assertJsonPath('data.refunds.0.amount', 5);

        // A paid (and now partially-refunded) order must not be cancellable
        // through the normal cancel endpoint.
        $this->deleteJson("/api/v1/orders/{$orderId}", [], $headers)
            ->assertUnprocessable();
        $afterCancelAttempt = $this->getJson("/api/v1/orders/{$orderId}", $headers)->assertOk();
        $this->assertNotSame('cancelled', $afterCancelAttempt->json('data.status'));
        $this->assertDatabaseHas('payments', ['order_id' => $orderId, 'deleted_at' => null]);
    }

    public function test_unauthenticated_pos_requests_are_rejected(): void
    {
        $this->getJson('/api/v1/branches')->assertUnauthorized();
        $this->getJson('/api/v1/orders')->assertUnauthorized();
        $this->postJson('/api/v1/orders/1/pay', ['method' => 'cash', 'amount' => 1])->assertUnauthorized();
    }

    public function test_cross_tenant_pos_access_is_isolated(): void
    {
        $this->seed();
        $headers = $this->headers();

        $otherTenantId = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other Cafe',
            'slug' => 'other-cafe',
            'status' => 'active',
            'plan' => 'starter',
            'currency' => 'SYP',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $otherBranchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $otherTenantId,
            'name' => 'Other Branch',
            'currency' => 'SYP',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $otherOrderId = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $otherTenantId,
            'branch_id' => $otherBranchId,
            'order_number' => 'OTHER-0001',
            'type' => 'dine_in',
            'status' => 'draft',
            'payment_status' => 'unpaid',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // A token issued for tenant A must not be able to read tenant B's data.
        $this->getJson('/api/v1/branches', $headers)
            ->assertOk()
            ->assertJsonMissing(['name' => 'Other Branch']);

        $this->getJson("/api/v1/orders/{$otherOrderId}", $headers)
            ->assertNotFound();

        // The authenticated tenant also cannot create a tenant-A order that
        // points at a tenant-B branch through a guessed raw ID.
        $localProductId = (int) DB::table('products')->where('tenant_id', $this->tenantId())->value('id');
        $this->postJson('/api/v1/orders', [
            'branchId' => $otherBranchId,
            'orderType' => 'takeaway',
            'items' => [['productId' => $localProductId, 'quantity' => 1]],
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('branchId');
    }

    private function headers(): array
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = 'pos-smoke-test-token';
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'pos-smoke-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken"];
    }

    private function tenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }
}
