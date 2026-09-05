<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Phase 4 — ShiftController::close() now uses ShiftCashSummaryService, the
 * single authoritative cash formula: opening + cash sales - cash refunds.
 * Card/other non-cash payments and refunds never affect the drawer figure.
 */
class ShiftCashSummaryApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_expected_cash_is_opening_plus_cash_sales_minus_cash_refunds(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $shift = $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 100], $headers)->assertCreated();
        $shiftId = $shift->json('data.id');

        // Two cash sales summing to 500.00 (paid exactly, no tax/discount noise
        // by paying the order's own computed total each time).
        $this->payOrder($tenant, $branchId, $shiftId, $headers, quantity: 1, method: 'cash', amountOverride: '300.00');
        $orderId2 = $this->payOrder($tenant, $branchId, $shiftId, $headers, quantity: 1, method: 'cash', amountOverride: '200.00');

        // A 50.00 cash refund against the second sale.
        $this->postJson("/api/v1/orders/{$orderId2}/refunds", ['type' => 'partial', 'amount' => 50, 'reason' => 'Shift cash test refund', 'idempotencyKey' => 'shift-cash-refund-1'], $headers)->assertCreated();

        $closed = $this->postJson("/api/v1/shifts/{$shiftId}/close", ['closingCash' => 545], $headers)->assertOk();

        $this->assertSame(550.0, (float) $closed->json('data.expectedCash'));
        $this->assertSame(545.0, (float) $closed->json('data.closingCash'));
        $this->assertSame(-5.0, (float) $closed->json('data.cashDifference'));
    }

    public function test_card_sales_and_card_refunds_are_excluded_from_the_cash_drawer_figure(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);
        $bankAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1030')->value('id');
        $cardMethodId = $this->postJson('/api/v1/finance/payment-methods', ['code' => 'CARD', 'name' => 'Card', 'type' => 'card', 'financialAccountId' => $bankAccountId, 'isActive' => true], $headers)
            ->assertCreated()->json('data.id');

        $shift = $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 100], $headers)->assertCreated();
        $shiftId = $shift->json('data.id');

        $this->payOrder($tenant, $branchId, $shiftId, $headers, quantity: 1, method: 'cash', amountOverride: '80.00');
        $cardOrderId = $this->payOrder($tenant, $branchId, $shiftId, $headers, quantity: 1, method: 'card', amountOverride: '500.00', paymentMethodId: $cardMethodId);
        $this->postJson("/api/v1/orders/{$cardOrderId}/refunds", ['type' => 'full', 'reason' => 'Card refund excluded', 'idempotencyKey' => 'shift-card-refund-1'], $headers)->assertCreated();

        $closed = $this->postJson("/api/v1/shifts/{$shiftId}/close", ['closingCash' => 180], $headers)->assertOk();

        // Only the 80.00 cash sale moves the drawer; the 500.00 card sale and
        // its full refund must not appear on either side of the formula.
        $this->assertSame(180.0, (float) $closed->json('data.expectedCash'));
        $this->assertSame(0.0, (float) $closed->json('data.cashDifference'));
    }

    public function test_multiple_cash_payments_and_refunds_accumulate_correctly_with_decimal_precision(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $shift = $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => '50.25'], $headers)->assertCreated();
        $shiftId = $shift->json('data.id');

        $this->payOrder($tenant, $branchId, $shiftId, $headers, quantity: 1, method: 'cash', amountOverride: '10.10');
        $this->payOrder($tenant, $branchId, $shiftId, $headers, quantity: 1, method: 'cash', amountOverride: '10.15');
        $orderId3 = $this->payOrder($tenant, $branchId, $shiftId, $headers, quantity: 1, method: 'cash', amountOverride: '10.20');
        $this->postJson("/api/v1/orders/{$orderId3}/refunds", ['type' => 'partial', 'amount' => 3.05, 'reason' => 'Precision test A', 'idempotencyKey' => 'shift-precision-1'], $headers)->assertCreated();
        $this->postJson("/api/v1/orders/{$orderId3}/refunds", ['type' => 'partial', 'amount' => 2.05, 'reason' => 'Precision test B', 'idempotencyKey' => 'shift-precision-2'], $headers)->assertCreated();

        // 50.25 + (10.10+10.15+10.20) - (3.05+2.05) = 75.60
        $closed = $this->postJson("/api/v1/shifts/{$shiftId}/close", ['closingCash' => '75.60'], $headers)->assertOk();
        $this->assertSame(75.6, (float) $closed->json('data.expectedCash'));
        $this->assertSame(0.0, (float) $closed->json('data.cashDifference'));
    }

    public function test_shift_cash_is_tenant_and_branch_isolated(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $downtown = $this->downtownBranchId($tenant);
        $mainBranch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Main Branch')->value('id');

        $shiftDowntown = $this->postJson('/api/v1/shifts/current', ['branchId' => $downtown, 'openingCash' => 0], $headers)->assertCreated();
        $shiftMain = $this->postJson('/api/v1/shifts/current', ['branchId' => $mainBranch, 'openingCash' => 0], $headers)->assertCreated();

        $this->payOrder($tenant, $downtown, $shiftDowntown->json('data.id'), $headers, quantity: 1, method: 'cash', amountOverride: '40.00');
        $this->payOrder($tenant, $mainBranch, $shiftMain->json('data.id'), $headers, quantity: 1, method: 'cash', amountOverride: '999.00');

        $closedDowntown = $this->postJson("/api/v1/shifts/{$shiftDowntown->json('data.id')}/close", ['closingCash' => 40], $headers)->assertOk();
        $this->assertSame(40.0, (float) $closedDowntown->json('data.expectedCash'));
    }

    private function payOrder(int $tenant, int $branchId, int $shiftId, array $headers, int $quantity, string $method, string $amountOverride, ?int $paymentMethodId = null): int
    {
        $product = DB::table('products')->where('tenant_id', $tenant)->where('name', 'Cappuccino')->first();
        $modifiers = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->join('modifier_options', 'modifier_options.modifier_group_id', '=', 'modifier_groups.id')
            ->where('product_modifier_group.product_id', $product->id)
            ->where('modifier_groups.is_required', true)
            ->where('modifier_options.is_default', true)
            ->select(['modifier_groups.id as groupId', 'modifier_options.id as optionId'])
            ->get()
            ->map(fn ($modifier) => ['groupId' => $modifier->groupId, 'optionId' => $modifier->optionId])
            ->all();

        $order = $this->postJson('/api/v1/orders', [
            'branchId' => $branchId, 'shiftId' => $shiftId, 'orderType' => 'takeaway',
            'items' => [['productId' => $product->id, 'quantity' => $quantity, 'modifiers' => $modifiers]],
        ], $headers)->assertCreated();
        $orderId = $order->json('data.id');

        // Force the order to the exact amount this test needs to reason about
        // (bypassing the catalog price + 8% tax noise), matching how a
        // cashier can charge a manually-adjusted total at the register.
        DB::table('orders')->where('id', $orderId)->update(['subtotal' => $amountOverride, 'discount_total' => 0, 'tax_total' => 0, 'total' => $amountOverride]);

        $payload = ['method' => $method, 'amount' => $amountOverride, 'idempotencyKey' => 'shift-test-pay-'.uniqid()];
        if ($paymentMethodId !== null) {
            $payload['paymentMethodId'] = $paymentMethodId;
        }
        $this->postJson("/api/v1/orders/{$orderId}/pay", $payload, $headers)->assertOk();

        return $orderId;
    }

    private function downtownBranchId(int $tenant): int
    {
        return (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id');
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = "shift-cash-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'shift-cash-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
