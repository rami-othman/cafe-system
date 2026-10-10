<?php

namespace Tests\Feature;

use App\Services\PosPricingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

/**
 * Automatic promotions, public rollout: a cafe opts in with automaticEnabled
 * and promotions are applied by the V3 engine under the Cafe Discount Policy.
 * The fixture order is two 10.00 lines (products A and B), subtotal 20.00.
 */
class DiscountAutomaticPromotionsTest extends TestCase
{
    use DiscountEngineFixture;
    use RefreshDatabase;

    /** A cafe that opted in; the testing-only isolated authority is off. */
    private function automaticCafe(array $policy = []): array
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $this->settings($f, array_replace(['automaticEnabled' => true], $policy));

        return $f;
    }

    private function promotion(array $f, array $changes = []): int
    {
        return $this->policy($f, array_replace(['applicationMode' => 'automatic', 'name' => 'Promotion'], $changes));
    }

    private function manual(array $f, array $changes = []): int
    {
        return $this->policy($f, array_replace(['applicationMode' => 'manual', 'name' => 'Manual'], $changes));
    }

    private function applied(array $result): array
    {
        return array_map(fn (array $d): array => [$d['discountId'], $d['source'], $d['amount']], $result['discounts']);
    }

    private function recalculate(array $f): object
    {
        return DB::transaction(fn () => app(PosPricingService::class)->recalculateOrder($f['tenant'], $f['order']));
    }

    public function test_a_cafe_opts_in_and_capabilities_open_while_other_cafes_stay_off(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $this->getJson('/api/v1/discount-capabilities', $f['headers'])->assertOk()
            ->assertJsonPath('data.engineReady', true)
            ->assertJsonPath('data.automaticPolicyCreationAvailable', true)
            ->assertJsonPath('data.automaticEnabled', false);
        // Promotions can be prepared before the cafe turns them on; they do nothing yet.
        $promotion = $this->promotion($f, ['value' => 10]);
        $this->assertSame('0.00', $this->recalculate($f)->discount_total);
        $this->assertDatabaseCount('order_discounts', 0);

        $this->settings($f, ['automaticEnabled' => true]);
        $this->getJson('/api/v1/discount-capabilities', $f['headers'])->assertOk()->assertJsonPath('data.automaticEnabled', true)->assertJsonPath('data.requiresPaymentQuote', true);
        $this->assertSame('2.00', $this->recalculate($f)->discount_total);
        $this->assertSame([[$promotion, 'automatic', '2.00']], $this->applied($this->resolution($f)));

        // Another cafe is unaffected.
        $other = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $this->promotion($other, ['value' => 50]);
        $this->assertSame([], $this->resolution($other)['discounts']);
        $this->assertSame(1, DB::table('tenant_discount_settings')->where('automatic_enabled', true)->count());
    }

    public function test_one_discount_policy_picks_the_best_promotion_or_the_highest_priority(): void
    {
        $f = $this->automaticCafe();
        $small = $this->promotion($f, ['value' => 10, 'priority' => 9]);
        $large = $this->promotion($f, ['value' => 25, 'priority' => 1]);
        $this->promotion($f, ['value' => 0, 'priority' => 10]);
        $this->assertSame([[$large, 'automatic', '5.00']], $this->applied($this->resolution($f)));

        $this->settings($f, ['conflictResolution' => 'priority']);
        // The zero-value promotion has the top priority but never applies.
        $this->assertSame([[$small, 'automatic', '2.00']], $this->applied($this->resolution($f)));
    }

    public function test_promotions_combine_under_the_cafe_policy_and_follow_the_total_cap(): void
    {
        $f = $this->automaticCafe(['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 3, 'stackingMode' => 'same_item_allowed', 'allowOrderAfterItemDiscounts' => true]);
        $item = $this->promotion($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]]]);
        $order = $this->promotion($f, ['value' => 10]);
        $result = $this->resolution($f);
        // Item stage first (5.00 of A), then 10% of the remaining 15.00.
        $this->assertSame([[$item, 'automatic', '5.00'], [$order, 'automatic', '1.50']], $this->applied($result));
        $this->assertSame([1, 2], array_column($result['discounts'], 'sequence'));

        $this->settings($f, ['maximumTotalDiscountPercent' => '30']);
        $capped = $this->resolution($f);
        $this->assertSame('6.00', $capped['totals']['discountTotal']);
        $this->assertTrue(end($capped['discounts'])['capped']);

        // Without order-after-items, only the better single level remains.
        $this->settings($f, ['allowOrderAfterItemDiscounts' => false, 'maximumTotalDiscountPercent' => null]);
        $this->assertSame([[$item, 'automatic', '5.00']], $this->applied($this->resolution($f)));
    }

    public function test_an_explicit_discount_is_never_displaced_by_a_promotion(): void
    {
        $f = $this->automaticCafe();
        $promotion = $this->promotion($f, ['value' => 50]);
        $manual = $this->manual($f, ['value' => 10]);
        $this->assertSame([[$promotion, 'automatic', '10.00']], $this->applied($this->resolution($f)));
        // One discount per order: the cashier's choice wins even though it saves less.
        $this->assertSame([[$manual, 'configured_manual', '2.00']], $this->applied($this->resolution($f, ['source' => 'configured_manual', 'discountId' => $manual])));

        $this->settings($f, ['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 2, 'stackingMode' => 'same_item_allowed']);
        $both = $this->resolution($f, [['source' => 'configured_manual', 'discountId' => $manual]]);
        $this->assertSame([[$manual, 'configured_manual', '2.00'], [$promotion, 'automatic', '9.00']], $this->applied($both));
        $this->assertSame([], $both['excluded']);

        // An exclusive promotion cannot join an explicit discount.
        DB::table('discounts')->where('id', $promotion)->update(['combination_behavior' => 'exclusive']);
        $this->assertSame([[$manual, 'configured_manual', '2.00']], $this->applied($this->resolution($f, [['source' => 'configured_manual', 'discountId' => $manual]])));
        // Alone it still applies.
        $this->assertSame([[$promotion, 'automatic', '10.00']], $this->applied($this->resolution($f)));
    }

    public function test_ineligible_promotions_are_skipped_silently(): void
    {
        $f = $this->automaticCafe(['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 5, 'stackingMode' => 'same_item_allowed']);
        $this->promotion($f, ['value' => 50, 'endDate' => '2026-01-01']);
        $this->promotion($f, ['value' => 50, 'isActive' => false]);
        $this->promotion($f, ['value' => 50, 'minimumOrderAmount' => 100]);
        $this->promotion($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [DB::table('products')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Not in cart', 'price' => 5, 'is_active' => true, 'is_stock_tracked' => false])]]);
        $valid = $this->promotion($f, ['value' => 5]);
        $result = $this->resolution($f);
        $this->assertSame([[$valid, 'automatic', '1.00']], $this->applied($result));
        $this->assertSame([], $result['excluded']);
        $this->assertSame([], $result['reasons']);
    }

    public function test_cart_changes_apply_and_remove_promotions_automatically(): void
    {
        $f = $this->automaticCafe();
        $promotion = $this->promotion($f, ['value' => 10, 'minimumOrderAmount' => 25]);
        $this->assertSame('0.00', $this->recalculate($f)->discount_total);
        DB::table('order_items')->where('id', $f['items'][0])->update(['quantity' => 2, 'total' => '20.00']);
        $order = $this->recalculate($f);
        $this->assertSame('3.00', $order->discount_total);
        $this->assertSame('27.00', $order->total);
        $this->assertDatabaseHas('order_discounts', ['order_id' => $f['order'], 'discount_id' => $promotion, 'source' => 'automatic']);
        DB::table('order_items')->where('id', $f['items'][0])->update(['quantity' => 1, 'total' => '10.00']);
        $this->assertSame('0.00', $this->recalculate($f)->discount_total);
        $this->assertDatabaseCount('order_discounts', 0);
        // Promotions are never saved as the cashier's intent.
        $this->assertDatabaseCount('order_discount_intents', 0);
    }

    public function test_a_reviewed_set_saves_only_explicit_intents(): void
    {
        $f = $this->automaticCafe(['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 2, 'stackingMode' => 'same_item_allowed']);
        $promotion = $this->promotion($f, ['value' => 10]);
        $manual = $this->manual($f, ['value' => 20]);
        $review = $this->preview($f, ['action' => 'set', 'intents' => [['source' => 'configured_manual', 'discountId' => $manual]]]);
        $this->assertSame([$manual, $promotion], array_column($review['discounts'], 'discountId'));
        $state = $this->applyReview($f, $review, 'set-with-promotion');
        $this->assertEquals([['source' => 'configured_manual', 'discountId' => $manual]], $state['explicitIntents']);
        $this->assertSame(['configured_manual', 'automatic'], array_column($state['discounts'], 'source'));
        $this->assertSame('5.60', $state['totals']['discountTotal']);
    }

    public function test_a_manager_suppresses_a_promotion_with_a_reason_and_can_undo_it(): void
    {
        $f = $this->automaticCafe();
        $promotion = $this->promotion($f, ['value' => 10]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'suppress', 'discountId' => $promotion, 'reason' => ' '], $f['headers'])->assertUnprocessable();
        $state = $this->applyReview($f, $this->preview($f, ['action' => 'suppress', 'discountId' => $promotion, 'reason' => 'Customer declined']), 'suppress');
        $this->assertSame([], $state['discounts']);
        $this->assertSame('Customer declined', $state['suppressions'][0]['reason']);
        $this->assertSame('Promotion', $state['suppressions'][0]['name']);
        $this->assertSame('DISCOUNT_SUPPRESSED', $this->resolution($f)['reasons'][0]['code']);
        $this->assertSame('0.00', $this->recalculate($f)->discount_total);
        $undo = $this->applyReview($f, $this->preview($f, ['action' => 'undo', 'discountId' => $promotion]), 'undo');
        $this->assertSame('2.00', $undo['totals']['discountTotal']);
    }

    public function test_a_tender_restricted_promotion_waits_for_the_payment_method(): void
    {
        $f = $this->automaticCafe();
        $promotion = $this->promotion($f, ['value' => 10, 'paymentMethodIds' => [$f['cash']]]);
        $pending = $this->resolution($f);
        $this->assertSame([], $pending['discounts']);
        $this->assertTrue($pending['provisional']);
        $this->assertSame('DISCOUNT_TENDER_PENDING', $pending['reasons'][0]['code']);
        $this->assertSame([[$promotion, 'automatic', '2.00']], $this->applied($this->quote($f, $f['cash'])));
        $this->assertSame([], $this->quote($f, $f['card'])['discounts']);
    }

    public function test_payment_settles_the_quoted_promotion_once_and_respects_its_usage_limit(): void
    {
        $f = $this->automaticCafe();
        $promotion = $this->promotion($f, ['value' => 10, 'usageLimit' => 1]);
        $quote = $this->quote($f, $f['cash']);
        $this->assertSame('18.00', $quote['totals']['total']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote, 'auto-pay'), $f['headers'])->assertOk();
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote, 'auto-pay'), $f['headers'])->assertOk();
        $this->assertDatabaseCount('payments', 1);
        $this->assertSame('18.00', DB::table('payments')->value('amount'));
        $this->assertSame(1, DB::table('discount_usages')->where('discount_id', $promotion)->count());
        $this->assertSame('automatic', DB::table('order_discounts')->where('order_id', $f['order'])->value('source'));

        // The limit is reached: the next order no longer qualifies.
        $row = (array) DB::table('orders')->find($f['order']);
        unset($row['id']);
        $row = array_replace($row, ['order_number' => uniqid('NEXT-'), 'status' => 'draft', 'payment_status' => 'unpaid', 'closed_at' => null, 'discount_total' => '0.00', 'total' => '20.00']);
        $next = DB::table('orders')->insertGetId($row);
        DB::table('order_items')->insert(['tenant_id' => $f['tenant'], 'order_id' => $next, 'product_id' => $f['products'][0], 'product_name' => 'Next', 'quantity' => 2, 'unit_price' => '10.00', 'total' => '20.00']);
        $this->assertSame([], $this->resolution(array_replace($f, ['order' => $next]))['discounts']);
    }

    public function test_a_new_or_edited_promotion_makes_an_open_quote_stale(): void
    {
        $f = $this->automaticCafe();
        $quote = $this->quote($f, $f['cash']);
        $this->assertSame('20.00', $quote['totals']['total']);
        $this->promotion($f, ['value' => 10]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote, 'stale'), $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        $this->assertDatabaseCount('payments', 0);
        $fresh = $this->quote($f, $f['cash']);
        $this->assertSame('18.00', $fresh['totals']['total']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $fresh, 'fresh'), $f['headers'])->assertOk();
    }

    public function test_many_promotions_resolve_deterministically_within_the_candidate_limit(): void
    {
        $f = $this->automaticCafe(['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 10, 'stackingMode' => 'same_item_allowed']);
        for ($i = 1; $i <= 12; $i++) {
            $this->promotion($f, ['type' => 'fixed', 'value' => $i / 10]);
        }
        $first = $this->resolution($f);
        $this->assertCount(8, $first['discounts']);
        // The eight largest (0.50 .. 1.20) are kept; the total stays within the subtotal.
        $this->assertSame('6.80', $first['totals']['discountTotal']);
        $this->assertSame($first['fingerprint'], $this->resolution($f)['fingerprint']);
    }

    public function test_legacy_clients_are_blocked_once_promotions_are_on(): void
    {
        $f = $this->automaticCafe();
        $this->promotion($f, ['value' => 10]);
        $old = ['Authorization' => $f['headers']['Authorization']];
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', ['method' => 'cash', 'amount' => 100, 'idempotencyKey' => 'old'], $old)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CLIENT_UPDATE_REQUIRED');
        $this->assertDatabaseCount('payments', 0);
    }

    public function test_rollback_migration_refuses_while_a_cafe_has_promotions_on(): void
    {
        $this->automaticCafe();
        $migration = require database_path('migrations/2026_10_13_000001_allow_automatic_discounts.php');
        try {
            $migration->down();
            $this->fail('Rollback must refuse while automatic promotions are enabled.');
        } catch (\RuntimeException $exception) {
            $this->assertStringContainsString('Automatic promotions are enabled', $exception->getMessage());
        }
        $this->assertSame(1, DB::table('tenant_discount_settings')->where('automatic_enabled', true)->count());
    }
}
