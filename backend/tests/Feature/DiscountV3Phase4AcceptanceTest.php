<?php

namespace Tests\Feature;

use App\Services\DiscountSettingsService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

/**
 * Discount System V3 Phase 4: end-to-end acceptance of flows the earlier
 * phases only covered in pieces (coupon retention across a full POS edit
 * cycle, expiry between review and payment, and dormant policy values).
 */
class DiscountV3Phase4AcceptanceTest extends TestCase
{
    use DiscountEngineFixture;
    use RefreshDatabase;

    private function multi(array $f, array $changes = []): void
    {
        $this->settings($f, array_replace(['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 5, 'stackingMode' => 'same_item_allowed', 'allowCouponWithConfigured' => true], $changes));
    }

    private function manual(array $f, array $changes = []): int
    {
        return $this->policy($f, array_replace(['applicationMode' => 'manual'], $changes));
    }

    private function coupon(array $f, string $code, array $changes = []): int
    {
        return $this->policy($f, array_replace(['applicationMode' => 'code', 'code' => $code], $changes));
    }

    private function state(array $f): array
    {
        return $this->getJson('/api/v1/orders/'.$f['order'].'/discount-state', $f['headers'])->assertOk()->json('data');
    }

    private function applied(): array
    {
        return DB::table('order_discounts')->orderBy('application_sequence')->pluck('discount_id')->map(fn ($v) => (int) $v)->all();
    }

    private function setIntents(array $f, array $intents, string $identity): array
    {
        return $this->applyReview($f, $this->preview($f, ['action' => 'set', 'intents' => $intents]), $identity);
    }

    public function test_coupon_survives_adding_and_removing_a_configured_discount_then_is_revoked_with_the_coupon(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $couponA = $this->coupon($f, 'ABCD2', ['value' => 10]);
        $configuredB = $this->manual($f, ['value' => 20]);
        $saved = ['source' => 'code', 'discountId' => $couponA];
        $b = ['source' => 'configured_manual', 'discountId' => $configuredB];

        // Coupon A typed once.
        $this->setIntents($f, [['source' => 'code', 'code' => 'abcd2']], 'p4-a');
        $this->assertSame([$couponA], $this->applied());

        // Add configured B: the POS re-sends A from the saved state by id.
        $this->assertEquals([['source' => 'code', 'discountId' => $couponA]], $this->state($f)['explicitIntents']);
        $this->setIntents($f, [$saved, $b], 'p4-add-b');
        $this->assertSame([$couponA, $configuredB], $this->applied());

        // Remove B again: A must remain applied.
        $this->setIntents($f, [$saved], 'p4-remove-b');
        $this->assertSame([$couponA], $this->applied());
        $this->assertSame('2.00', $this->state($f)['totals']['discountTotal']);

        // Removing the last discount clears it and revokes id-only retention.
        $this->applyReview($f, $this->preview($f, ['action' => 'remove']), 'p4-remove-all');
        $this->assertSame([], $this->applied());
        $this->assertSame([], $this->state($f)['explicitIntents']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => [$saved]], $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_NOT_FOUND');

        // Dropping the coupon from a set (keeping only B) also revokes it.
        $this->setIntents($f, [['source' => 'code', 'code' => 'ABCD2'], $b], 'p4-readd');
        $this->setIntents($f, [$b], 'p4-drop-coupon');
        $this->assertSame([$configuredB], $this->applied());
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => [$saved, $b]], $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_NOT_FOUND');
    }

    public function test_coupon_ids_that_do_not_belong_to_the_order_fail_cleanly_without_database_errors(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $coupon = $this->coupon($f, 'FORE1');
        $configured = $this->manual($f);
        $this->setIntents($f, [['source' => 'code', 'code' => 'FORE1']], 'p4-own');

        $foreign = $this->fixture();
        $foreignCoupon = $this->coupon($foreign, 'FORE2');

        $cases = [
            'foreign tenant coupon id' => ['source' => 'code', 'discountId' => $foreignCoupon],
            'unknown id' => ['source' => 'code', 'discountId' => 987654321],
            'configured discount id as a coupon' => ['source' => 'code', 'discountId' => $configured],
            'non-numeric id' => ['source' => 'code', 'discountId' => 'abc'],
            'negative id' => ['source' => 'code', 'discountId' => -1],
        ];
        foreach ($cases as $label => $intent) {
            $response = $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => [$intent]], $f['headers']);
            $this->assertSame(422, $response->status(), $label);
            $body = strtolower($response->getContent());
            foreach (['sqlstate', 'select ', 'pdoexception', 'stack trace', 'illuminate\\'] as $leak) {
                $this->assertStringNotContainsString($leak, $body, $label);
            }
        }
        $this->assertSame([$coupon], $this->applied());
        $this->assertEquals(['source' => 'code', 'discountId' => $coupon], $this->state($f)['explicitIntents'][0]);
    }

    public function test_coupon_expiring_between_review_and_payment_never_settles(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $coupon = $this->coupon($f, 'EXPR3', ['value' => 10]);
        $configured = $this->manual($f, ['value' => 20]);
        $this->setIntents($f, [['source' => 'code', 'code' => 'EXPR3'], ['source' => 'configured_manual', 'discountId' => $configured]], 'p4-expiry');

        $quote = $this->quote($f, $f['cash']);
        $this->assertSame('14.40', $quote['totals']['total']);
        DB::table('discounts')->where('id', $coupon)->update(['ends_at' => now()->subMinute()]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote, 'p4-expired'), $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_EXPIRED');
        $this->assertDatabaseCount('payments', 0);
        $this->assertDatabaseCount('discount_usages', 0);

        // Once the coupon is valid again the original reviewed math settles exactly once.
        DB::table('discounts')->where('id', $coupon)->update(['ends_at' => null]);
        $fresh = $this->quote($f, $f['cash']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $fresh, 'p4-paid'), $f['headers'])->assertOk();
        $this->assertDatabaseCount('payments', 1);
        $this->assertSame(2, DB::table('discount_usages')->where('order_id', $f['order'])->count());
    }

    public function test_dormant_policy_values_survive_a_disable_and_re_enable_cycle_through_the_api(): void
    {
        $f = $this->fixture();
        $this->settings($f, ['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 3, 'stackingMode' => 'same_item_allowed', 'allowMultipleCoupons' => true, 'allowCouponWithConfigured' => true, 'allowOrderAfterItemDiscounts' => true, 'conflictResolution' => 'priority', 'maximumTotalDiscountPercent' => '40']);
        $before = app(DiscountSettingsService::class)->read($f['tenant']);

        // The Flutter screen sends the complete draft with only the master switch changed.
        $this->settings($f, ['allowMultipleDiscounts' => false]);
        $off = app(DiscountSettingsService::class)->read($f['tenant']);
        $this->assertFalse($off['allowMultipleDiscounts']);
        foreach (['maximumDiscountsPerOrder', 'stackingMode', 'allowMultipleCoupons', 'allowCouponWithConfigured', 'allowOrderAfterItemDiscounts', 'conflictResolution', 'maximumTotalDiscountPercent'] as $key) {
            $this->assertEquals($before[$key], $off[$key], $key);
        }
        $this->assertSame(1, $this->getJson('/api/v1/discount-capabilities', $f['headers'])->assertOk()->json('data.policy.effectiveMaximumDiscounts'));

        // An older client that sends only the legacy eight fields must not reset anything either.
        $legacy = array_intersect_key($off, array_flip(['automaticEnabled', 'selectionStrategy', 'combinationMode', 'orderDiscountBehavior', 'couponBehavior', 'manualBehavior', 'allowAutomaticSuppression', 'maximumTotalDiscountPercent']));
        $this->putJson('/api/v1/cafe-configuration/discount-settings', $legacy + ['expectedVersion' => $off['version']], $f['headers'])->assertOk();

        $this->settings($f, ['allowMultipleDiscounts' => true]);
        $on = app(DiscountSettingsService::class)->read($f['tenant']);
        $this->assertSame(3, $on['maximumDiscountsPerOrder']);
        $this->assertSame(3, $this->getJson('/api/v1/discount-capabilities', $f['headers'])->assertOk()->json('data.policy.effectiveMaximumDiscounts'));
        foreach (['stackingMode', 'allowMultipleCoupons', 'allowCouponWithConfigured', 'allowOrderAfterItemDiscounts', 'conflictResolution', 'maximumTotalDiscountPercent'] as $key) {
            $this->assertEquals($before[$key], $on[$key], $key);
        }
        $this->assertFalse($on['automaticEnabled']);
        $this->assertTrue($this->getJson('/api/v1/discount-capabilities', $f['headers'])->assertOk()->json('data.engineReady'));
    }
}
