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

        $branchId = DB::table('branches')->where('name', 'Downtown')->value('id');
        $productId = DB::table('products')->where('name', 'Cappuccino')->value('id');

        $this->getJson('/api/v1/branches')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Downtown');

        $state = $this->getJson("/api/v1/pos/state?branchId={$branchId}")
            ->assertOk()
            ->assertJsonPath('data.terminal.status', 'open');

        $this->getJson('/api/v1/customers?search=Jane')
            ->assertOk()
            ->assertJsonPath('data.0.tier', 'vip');

        $this->getJson("/api/v1/menu/products/{$productId}?branchId={$branchId}")
            ->assertOk()
            ->assertJsonPath('data.name', 'Cappuccino');

        $shiftId = $state->json('data.currentShift.id');

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
            'shiftId' => $shiftId,
            'orderType' => 'dine_in',
            'tableId' => DB::table('cafe_tables')->where('branch_id', $branchId)->value('id'),
            'items' => [
                [
                    'productId' => $productId,
                    'quantity' => 5,
                    'modifiers' => $modifiers,
                ],
            ],
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'draft');

        $orderId = $order->json('data.id');

        $this->getJson("/api/v1/discounts/available?orderId={$orderId}")
            ->assertOk()
            ->assertJsonFragment(['code' => 'LUNCH10']);

        $discounted = $this->postJson("/api/v1/orders/{$orderId}/discounts/apply", [
            'code' => 'LUNCH10',
        ])
            ->assertOk()
            ->assertJsonPath('data.discount.code', 'LUNCH10');

        $this->getJson("/api/v1/orders/{$orderId}/payment-summary?amountReceived=30")
            ->assertOk()
            ->assertJsonPath('data.changeDue', round(30 - $discounted->json('data.totals.total'), 2));

        $payment = $this->postJson("/api/v1/orders/{$orderId}/pay", [
            'method' => 'cash',
            'amount' => 30,
        ])
            ->assertOk()
            ->assertJsonPath('data.payment.status', 'completed');

        $this->getJson("/api/v1/orders/{$orderId}/receipt")
            ->assertOk()
            ->assertJsonPath('data.title', 'Cafe System 618');

        $this->postJson("/api/v1/orders/{$orderId}/print", [
            'type' => 'receipt',
        ])
            ->assertAccepted()
            ->assertJsonPath('data.status', 'queued');

        $this->postJson("/api/v1/orders/{$orderId}/refunds", [
            'type' => 'partial',
            'amount' => 5,
            'reason' => 'Customer Request',
            'managerNotes' => 'Approved from POS refund flow.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.paymentId', $payment->json('data.payment.id'));

        $this->getJson("/api/v1/orders/{$orderId}")
            ->assertOk()
            ->assertJsonPath('data.refunds.0.amount', 5);
    }
}
