<?php

namespace Tests\Feature;

use App\Services\DiscountEligibilityService;
use App\Services\PosPricingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

class DiscountEngineCorrectionsTest extends TestCase
{
    use DiscountEngineFixture, RefreshDatabase;

    public function test_nondefault_cap_blocks_legacy_apply_and_requires_review_for_contract_two(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $p = $this->policy($f, ['applicationMode' => 'manual', 'type' => 'fixed', 'value' => 10]);
        $this->settings($f, ['maximumTotalDiscountPercent' => 10]);
        $old = ['Authorization' => $f['headers']['Authorization']];
        $this->getJson('/api/v1/discount-capabilities', $old)->assertOk()->assertJsonPath('data.requiresPaymentQuote', true);
        $url = '/api/v1/orders/'.$f['order'];
        $this->postJson($url.'/discounts/apply', ['discountId' => $p], $old)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CLIENT_UPDATE_REQUIRED');
        $this->putJson($url.'/discount', ['type' => 'fixed', 'value' => 10], $old)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_AD_HOC_DISABLED');
        $this->postJson($url.'/discounts/apply', ['discountId' => $p], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_REVIEW_REQUIRED');
        $review = $this->preview($f, ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $p]]);
        $this->assertSame('2.00', $review['totals']['discountTotal']);
        $this->applyReview($f, $review);
        $quote = $this->quote($f, $f['cash']);
        $this->postJson($url.'/pay', $this->payData($f, $quote), $f['headers'])->assertOk()->assertJsonPath('data.payment.amount', 18);
        $this->assertDatabaseHas('orders', ['id' => $f['order'], 'discount_total' => '2.00']);
        $this->assertDatabaseCount('discount_usages', 1);
    }

    public function test_cap_change_blocks_existing_legacy_payment_without_partial_effects(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $p = $this->policy($f, ['applicationMode' => 'manual', 'type' => 'fixed', 'value' => 10]);
        $old = ['Authorization' => $f['headers']['Authorization']];
        $url = '/api/v1/orders/'.$f['order'];
        $this->postJson($url.'/discounts/apply', ['discountId' => $p], $old)->assertOk();
        $this->settings($f, ['maximumTotalDiscountPercent' => 10]);
        $before = (array) DB::table('orders')->find($f['order']);
        $this->postJson($url.'/pay', ['method' => 'cash', 'amount' => 100, 'idempotencyKey' => 'legacy-cap'], $old)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CLIENT_UPDATE_REQUIRED');
        $this->assertSame($before, (array) DB::table('orders')->find($f['order']));
        $this->noSettlement();
        $quote = $this->quote($f, $f['cash']);
        $this->assertSame('2.00', $quote['totals']['discountTotal']);
        DB::transaction(fn () => app(PosPricingService::class)->recalculateOrder($f['tenant'], $f['order']));
        $this->assertSame('2.00', DB::table('orders')->find($f['order'])->discount_total);
    }

    public function test_non_single_settings_require_quote_even_without_automatic_or_saved_engine_rows(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $this->settings($f, ['combinationMode' => 'disjoint_items']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', ['method' => 'cash', 'paymentMethodId' => $f['cash'], 'amount' => 100, 'idempotencyKey' => 'no-quote'], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'PAYMENT_QUOTE_REQUIRED');
        $this->noSettlement();
    }

    public function test_cap_invalidates_quotes_but_completed_legacy_payment_and_operation_replay_survive(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $p = $this->policy($f, ['applicationMode' => 'manual', 'type' => 'fixed', 'value' => 10]);
        $review = $this->preview($f, ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $p]]);
        $saved = $this->applyReview($f, $review, 'cap-operation');
        $quote = $this->quote($f, $f['cash']);
        $this->settings($f, ['maximumTotalDiscountPercent' => 10]);
        $this->assertSame($saved, $this->applyReview($f, $review, 'cap-operation'));
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote), $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        $this->noSettlement();
        $legacy = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $old = ['Authorization' => $legacy['headers']['Authorization']];
        $data = ['method' => 'cash', 'amount' => 100, 'idempotencyKey' => 'legacy-completed'];
        $url = '/api/v1/orders/'.$legacy['order'].'/pay';
        $paid = $this->postJson($url, $data, $old)->assertOk()->json('data');
        $this->settings($legacy, ['maximumTotalDiscountPercent' => 1]);
        $this->postJson($url, $data, $old)->assertOk()->assertJsonPath('data', $paid);
        $this->assertDatabaseCount('payments', 1);
    }

    public function test_per_unit_uses_quantity_contributions_and_persists_payment_receipt_allocations(): void
    {
        $f = $this->fixture();
        $this->lines($f, [['1.000', '100.00', '100.00'], ['10.000', '1.00', '10.00']]);
        $p = $this->policy($f, ['scope' => 'product', 'type' => 'fixed', 'fixedAmountBasis' => 'per_unit', 'value' => 1, 'targetProductIds' => $f['products']]);
        $quote = $this->quote($f, $f['cash']);
        $this->assertSame('11.00', $quote['totals']['discountTotal']);
        $expected = [['orderItemId' => $f['items'][0], 'amount' => '1.00'], ['orderItemId' => $f['items'][1], 'amount' => '10.00']];
        $this->assertSame($expected, $quote['discounts'][0]['allocations']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote), $f['headers'])->assertOk()->assertJsonPath('data.payment.amount', 99);
        $this->getJson('/api/v1/orders/'.$f['order'].'/receipt', $f['headers'])->assertOk()->assertJsonPath('data.discountTotal', 11)->assertJsonPath('data.total', 99)->assertJsonPath('data.discounts.0.allocations', $expected);
        $this->assertSame(['1.00', '10.00'], DB::table('order_discount_allocations')->where('order_id', $f['order'])->orderBy('order_item_id')->pluck('amount')->all());
        $this->assertDatabaseHas('discount_usages', ['discount_id' => $p, 'order_id' => $f['order']]);
        $this->assertSame((string) DB::table('journal_entry_lines')->sum('debit'), (string) DB::table('journal_entry_lines')->sum('credit'));
    }

    public function test_per_unit_positive_tiny_line_is_reserved_against_overlapping_policy(): void
    {
        $f = $this->fixture();
        $this->lines($f, [['1.000', '100.00', '100.00'], ['1.000', '0.01', '0.01']]);
        $this->settings($f, ['combinationMode' => 'disjoint_items']);
        $p = $this->policy($f, ['scope' => 'product', 'type' => 'fixed', 'fixedAmountBasis' => 'per_unit', 'value' => 1, 'targetProductIds' => $f['products']]);
        $this->policy($f, ['scope' => 'product', 'value' => 100, 'targetProductIds' => [$f['products'][1]]]);
        $result = $this->resolution($f);
        $this->assertSame('1.01', $result['totals']['discountTotal']);
        $this->assertSame([$p], array_column($result['discounts'], 'discountId'));
        $this->assertSame(['1.00', '0.01'], array_column($result['discounts'][0]['allocations'], 'amount'));
    }

    public function test_per_unit_fractional_contributions_policy_cap_global_budget_and_remainder(): void
    {
        $f = $this->fixture();
        $this->lines($f, [['1.500', '100.00', '150.00'], ['0.250', '1.00', '0.25']]);
        $p = $this->policy($f, ['scope' => 'product', 'type' => 'fixed', 'fixedAmountBasis' => 'per_unit', 'value' => '2.01', 'targetProductIds' => $f['products']]);
        $r = $this->resolution($f);
        $this->assertSame('3.27', $r['totals']['discountTotal']);
        $this->assertSame(['3.02', '0.25'], array_column($r['discounts'][0]['allocations'], 'amount'));
        DB::table('discounts')->where('id', $p)->update(['maximum_discount_amount' => '1.00']);
        $r = $this->resolution($f);
        $this->assertSame(['0.92', '0.08'], array_column($r['discounts'][0]['allocations'], 'amount'));
        $this->settings($f, ['maximumTotalDiscountPercent' => '0.1000']);
        $r = $this->resolution($f);
        $this->assertSame('0.15', $r['totals']['discountTotal']);
        $this->assertSame(['0.14', '0.01'], array_column($r['discounts'][0]['allocations'], 'amount'));
        $this->settings($f, ['maximumTotalDiscountPercent' => null]);
        DB::table('discounts')->where('id', $p)->update(['value' => '0.01', 'maximum_discount_amount' => null]);
        $this->lines($f, [['0.400', '100.00', '40.00'], ['0.400', '1.00', '0.40']]);
        $r = $this->resolution($f);
        $this->assertSame('0.01', $r['totals']['discountTotal']);
        $this->assertSame([['orderItemId' => $f['items'][0], 'amount' => '0.01']], $r['discounts'][0]['allocations']);
    }

    public function test_bundle_aggregate_rounding_preserves_one_bundle_and_exact_persisted_amount(): void
    {
        $f = $this->fixture();
        $this->lines($f, [['2.000', '1.00', '2.00'], ['2.000', '1.00', '2.00']]);
        $p = $this->policy($f, ['scope' => 'bundle', 'value' => 100, 'bundleRequirements' => [['productId' => $f['products'][0], 'quantity' => '0.333'], ['productId' => $f['products'][1], 'quantity' => '0.333']]]);
        $legacy = app(DiscountEligibilityService::class)->assertApplicable($f['tenant'], DB::table('discounts')->find($p), DB::table('orders')->find($f['order']));
        $this->assertSame('0.67', $legacy['amount']);
        $quote = $this->quote($f, $f['cash']);
        $this->assertSame('0.67', $quote['totals']['discountTotal']);
        $expected = [['orderItemId' => $f['items'][0], 'amount' => '0.34'], ['orderItemId' => $f['items'][1], 'amount' => '0.33']];
        $this->assertSame($expected, $quote['discounts'][0]['allocations']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote), $f['headers'])->assertOk()->assertJsonPath('data.payment.amount', 3.33);
        $this->getJson('/api/v1/orders/'.$f['order'].'/receipt', $f['headers'])->assertOk()->assertJsonPath('data.discountTotal', 0.67)->assertJsonPath('data.discounts.0.allocations', $expected);
        $this->assertSame('0.67', (string) DB::table('order_discount_allocations')->where('order_id', $f['order'])->sum('amount'));
    }

    public function test_bundle_exact_weights_handle_component_round_up_caps_and_subcent_components(): void
    {
        $f = $this->fixture();
        $this->lines($f, [['2.000', '1.00', '2.00'], ['2.000', '1.00', '2.00']]);
        $p = $this->policy($f, ['scope' => 'bundle', 'value' => 100, 'bundleRequirements' => [['productId' => $f['products'][0], 'quantity' => '0.337'], ['productId' => $f['products'][1], 'quantity' => '0.337']]]);
        $r = $this->resolution($f);
        $this->assertSame('0.67', $r['totals']['discountTotal']);
        $this->assertSame(['0.34', '0.33'], array_column($r['discounts'][0]['allocations'], 'amount'));
        DB::table('discount_bundle_requirements')->where('discount_id', $p)->update(['quantity' => '0.004']);
        $this->assertSame('0.01', $this->resolution($f)['totals']['discountTotal']);
        DB::table('discount_bundle_requirements')->where('discount_id', $p)->update(['quantity' => '0.333']);
        DB::table('discounts')->where('id', $p)->update(['maximum_discount_amount' => '0.51']);
        $this->assertSame(['0.26', '0.25'], array_column($this->resolution($f)['discounts'][0]['allocations'], 'amount'));
        $this->settings($f, ['maximumTotalDiscountPercent' => 10]);
        $this->assertSame('0.40', $this->resolution($f)['totals']['discountTotal']);
    }

    private function lines(array $f, array $lines): void
    {
        foreach ($lines as $i => [$quantity, $price, $total]) {
            DB::table('order_items')->where('id', $f['items'][$i])->update(['quantity' => $quantity, 'unit_price' => $price, 'total' => $total]);
        }
        $subtotal = (string) DB::table('order_items')->where('order_id', $f['order'])->sum('total');
        DB::table('orders')->where('id', $f['order'])->update(['subtotal' => $subtotal, 'total' => $subtotal]);
    }

    private function noSettlement(): void
    {
        foreach (['payments', 'discount_usages', 'sale_consumptions', 'stock_movements', 'journal_entries'] as $table) {
            $this->assertSame(0, DB::table($table)->count(), $table);
        }
    }
}
