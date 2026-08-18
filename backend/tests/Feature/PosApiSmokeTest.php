<?php

namespace Tests\Feature;

use App\Services\PosPricingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class PosApiSmokeTest extends TestCase
{
    use RefreshDatabase;

    public function test_pos_pricing_uses_signed_modifier_minor_units_and_accepts_exact_zero_only(): void
    {
        $this->seed();
        $product = DB::table('products')->where('name', 'Cappuccino')->first();
        DB::table('products')->where('id', $product->id)->update(['price' => '5.00']);
        $required = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->join('modifier_options', 'modifier_options.modifier_group_id', '=', 'modifier_groups.id')
            ->where('product_modifier_group.product_id', $product->id)
            ->where('modifier_groups.is_required', true)
            ->where('modifier_options.is_default', true)
            ->select('modifier_options.id as option_id')
            ->get();
        DB::table('modifier_options')->whereIn('id', $required->pluck('option_id'))->update(['price_delta' => '0.00']);
        $plus = $this->modifier($product->tenant_id, $product->id, 'Plus', '1.00');
        $zero = $this->modifier($product->tenant_id, $product->id, 'Zero', '0.00');
        $minus = $this->modifier($product->tenant_id, $product->id, 'Minus', '-1.00');
        $quarter = $this->modifier($product->tenant_id, $product->id, 'Quarter', '0.25');
        $halfOff = $this->modifier($product->tenant_id, $product->id, 'Half Off', '-0.50');
        $fiveOff = $this->modifier($product->tenant_id, $product->id, 'Five Off', '-5.00');
        $sixOff = $this->modifier($product->tenant_id, $product->id, 'Six Off', '-6.00');
        $pricing = app(PosPricingService::class);
        $price = fn (array $ids): array => $pricing->priceItem($product->tenant_id, $product->id, 1, [
            ...$required->map(fn (object $option): array => ['optionId' => $option->option_id])->all(),
            ...array_map(fn (int $id): array => ['optionId' => $id], $ids),
        ]);

        $this->assertSame(6.0, $price([$plus])['unit_price']);
        $this->assertSame(5.0, $price([$zero])['unit_price']);
        $this->assertSame(4.0, $price([$minus])['unit_price']);
        $this->assertSame(4.75, $price([$plus, $minus, $quarter, $halfOff])['unit_price']);
        $this->assertSame(0.0, $price([$fiveOff])['unit_price']);

        try {
            $price([$sixOff]);
            $this->fail('A negative final POS price must be rejected.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('modifiers', $exception->errors());
        }
    }

    public function test_pos_order_flow_can_be_completed(): void
    {
        $this->seed();

        $branchId = DB::table('branches')->where('name', 'Downtown')->value('id');
        $productId = DB::table('products')->where('name', 'Cappuccino')->value('id');

        $this->getJson('/api/v1/menu/categories')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Coffee');

        $this->getJson('/api/v1/menu/products')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Espresso');

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
            ->assertJsonPath('data.name', 'Cappuccino')
            ->assertJsonPath('data.modifierGroups.0.name', 'Temperature');

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

        DB::table('modifier_options')->whereIn('id', collect($modifiers)->pluck('optionId'))->update(['price_delta' => -100]);
        $this->postJson('/api/v1/orders', [
            'branchId' => $branchId, 'shiftId' => $shiftId, 'orderType' => 'dine_in',
            'tableId' => DB::table('cafe_tables')->where('branch_id', $branchId)->value('id'),
            'items' => [['productId' => $productId, 'quantity' => 1, 'modifiers' => $modifiers]],
        ])->assertUnprocessable()->assertJsonValidationErrors('modifiers');
        DB::table('modifier_options')->whereIn('id', collect($modifiers)->pluck('optionId'))->update(['price_delta' => 0]);

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

    private function modifier(int $tenantId, int $productId, string $name, string $delta): int
    {
        $now = now();
        $groupId = DB::table('modifier_groups')->insertGetId([
            'tenant_id' => $tenantId, 'name' => $name, 'selection_type' => 'single', 'group_type' => 'add_on',
            'is_required' => false, 'min_selections' => 0, 'max_selections' => 1, 'allow_quantity' => false,
            'is_active' => true, 'created_at' => $now, 'updated_at' => $now,
        ]);
        DB::table('product_modifier_group')->insert([
            'tenant_id' => $tenantId, 'product_id' => $productId, 'modifier_group_id' => $groupId,
            'sort_order' => $groupId, 'created_at' => $now, 'updated_at' => $now,
        ]);

        return DB::table('modifier_options')->insertGetId([
            'tenant_id' => $tenantId, 'modifier_group_id' => $groupId, 'name' => $name,
            'price_delta' => $delta, 'cost_delta' => 0, 'is_default' => false, 'is_active' => true,
            'is_available' => true, 'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now,
        ]);
    }
}
