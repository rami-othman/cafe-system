<?php

namespace Tests\Feature;

use App\Exceptions\OrderLifecycleException;
use App\Services\DiscountResolutionService;
use App\Services\DiscountSettingsService;
use App\Services\PosPricingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

/**
 * Discount System V3 Phase 2: multi-discount resolution against the Cafe
 * Discount Policy. The fixture order is two 10.00 lines (products A and B).
 */
class DiscountV3MultiDiscountEngineTest extends TestCase
{
    use DiscountEngineFixture;
    use RefreshDatabase;

    /** Enable multiple discounts; every other policy flag keeps its restrictive default unless given. */
    private function multi(array $f, array $changes = []): void
    {
        $this->settings($f, array_replace(['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 5], $changes));
    }

    private function manual(array $f, array $changes = []): int
    {
        return $this->policy($f, array_replace(['applicationMode' => 'manual'], $changes));
    }

    private function coupon(array $f, string $code, array $changes = []): int
    {
        return $this->policy($f, array_replace(['applicationMode' => 'code', 'code' => $code], $changes));
    }

    private function m(int $id): array
    {
        return ['source' => 'configured_manual', 'discountId' => $id];
    }

    private function c(int $id): array
    {
        return ['source' => 'code', 'discountId' => $id];
    }

    private function line(array $f, int $index, string $total, string $quantity = '1'): void
    {
        DB::table('order_items')->where('id', $f['items'][$index])->update(['quantity' => $quantity, 'unit_price' => bcdiv($total, $quantity, 4), 'total' => $total]);
    }

    private function ids(array $result): array
    {
        return array_column($result['discounts'], 'discountId');
    }

    private function amounts(array $result): array
    {
        return array_column($result['discounts'], 'amount');
    }

    private function excludedCodes(array $result): array
    {
        return array_column($result['excluded'], 'code', 'discountId');
    }

    public function test_default_policy_keeps_one_discount_and_dormant_maximum_is_not_mutated(): void
    {
        $f = $this->fixture();
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $result = $this->resolution($f, [$this->m($a), $this->m($b)]);
        $this->assertSame([$b], $this->ids($result));
        $this->assertSame([$a => 'MULTIPLE_DISCOUNTS_DISABLED'], $this->excludedCodes($result));
        $this->assertSame([$b], $result['excluded'][0]['conflictsWith']);
        $this->assertSame(1, $result['policy']['effectiveMaximumDiscounts']);

        $this->settings($f, ['maximumDiscountsPerOrder' => 6]);
        $result = $this->resolution($f, [$this->m($a), $this->m($b)]);
        $this->assertSame(1, $result['policy']['effectiveMaximumDiscounts']);
        $this->assertSame(6, app(DiscountSettingsService::class)->read($f['tenant'])['maximumDiscountsPerOrder']);
        $this->assertCount(1, $result['discounts']);
    }

    public function test_two_and_three_discounts_apply_sequentially_in_the_reviewed_order(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'maximumDiscountsPerOrder' => 3]);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $c = $this->manual($f, ['type' => 'fixed', 'value' => 1]);

        $two = $this->resolution($f, [$this->m($a), $this->m($b)]);
        $this->assertSame([$a, $b], $this->ids($two));
        $this->assertSame(['2.00', '3.60'], $this->amounts($two));
        $this->assertSame('5.60', $two['totals']['discountTotal']);

        $three = $this->resolution($f, [$this->m($a), $this->m($b), $this->m($c)]);
        $this->assertSame([$a, $b, $c], $this->ids($three));
        $this->assertSame(['2.00', '3.60', '1.00'], $this->amounts($three));
        $this->assertSame([1, 2, 3], array_column($three['discounts'], 'sequence'));
        $this->assertSame(['subtotal' => '20.00', 'discountTotal' => '6.60', 'taxTotal' => '0.00', 'total' => '13.40'], $three['totals']);

        // Sequential stacking is order dependent, so the reviewed order is authoritative.
        $reversed = $this->resolution($f, [$this->m($b), $this->m($a)]);
        $this->assertSame([$b, $a], $this->ids($reversed));
        $this->assertSame(['4.00', '1.60'], $this->amounts($reversed));
        $this->assertSame($three['fingerprint'], $this->resolution($f, [$this->m($a), $this->m($b), $this->m($c)])['fingerprint']);
        $this->assertNotSame($two['fingerprint'], $reversed['fingerprint']);
        $this->assertSame([1, 2, 3], array_column($three['requested'], 'position'));
    }

    public function test_duplicate_intents_are_rejected_before_any_money_is_resolved(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $a = $this->manual($f);
        $code = $this->coupon($f, 'DUPE1');
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => [['source' => 'configured_manual', 'discountId' => $a], ['source' => 'configured_manual', 'discountId' => $a]]], $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_DUPLICATE_INTENT');
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => [['source' => 'code', 'code' => 'dupe1'], ['source' => 'code', 'code' => 'DUPE1']]], $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_DUPLICATE_INTENT');
        $this->assertNotNull($code);
        $this->assertDatabaseCount('discount_reviews', 0);
        $this->assertDatabaseCount('order_discounts', 0);
    }

    public function test_client_cannot_submit_money_or_unknown_intent_fields(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $a = $this->manual($f);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => [['source' => 'configured_manual', 'discountId' => $a, 'amount' => '19.00']]], $f['headers'])->assertUnprocessable();
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => [['source' => 'ad_hoc', 'discountId' => $a]]], $f['headers'])->assertUnprocessable();
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => []], $f['headers'])->assertUnprocessable();
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'set', 'intents' => array_fill(0, 11, ['source' => 'configured_manual', 'discountId' => $a])], $f['headers'])->assertUnprocessable();
    }

    public function test_individual_exclusivity_never_widens_the_cafe_policy(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $exclusiveSmall = $this->manual($f, ['value' => 10, 'combinationBehavior' => 'exclusive']);
        $normal = $this->manual($f, ['value' => 50]);
        $result = $this->resolution($f, [$this->m($exclusiveSmall), $this->m($normal)]);
        $this->assertSame([$normal], $this->ids($result));
        $this->assertSame([$exclusiveSmall => 'EXCLUSIVE_DISCOUNT_CONFLICT'], $this->excludedCodes($result));

        $exclusiveBig = $this->manual($f, ['value' => 90, 'combinationBehavior' => 'exclusive']);
        $result = $this->resolution($f, [$this->m($normal), $this->m($exclusiveBig)]);
        $this->assertSame([$exclusiveBig], $this->ids($result));
        $this->assertSame([$normal => 'EXCLUSIVE_DISCOUNT_CONFLICT'], $this->excludedCodes($result));

        // Exclusive + exclusive: one survives.
        $result = $this->resolution($f, [$this->m($exclusiveSmall), $this->m($exclusiveBig)]);
        $this->assertSame([$exclusiveBig], $this->ids($result));
        $this->assertSame([$exclusiveSmall => 'EXCLUSIVE_DISCOUNT_CONFLICT'], $this->excludedCodes($result));

        // follow_cafe_policy + follow_cafe_policy coexist when the cafe allows it.
        $other = $this->manual($f, ['value' => 10]);
        $this->assertSame([$normal, $other], $this->ids($this->resolution($f, [$this->m($normal), $this->m($other)])));
    }

    public function test_maximum_discount_count_applies_to_the_final_set(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'maximumDiscountsPerOrder' => 2]);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $c = $this->manual($f, ['value' => 30]);
        $result = $this->resolution($f, [$this->m($a), $this->m($b), $this->m($c)]);
        $this->assertSame([$b, $c], $this->ids($result));
        $this->assertSame(['4.00', '4.80'], $this->amounts($result));
        $this->assertSame([$a => 'MAXIMUM_DISCOUNT_COUNT_EXCEEDED'], $this->excludedCodes($result));
        $this->assertCount(2, $result['discounts']);
    }

    public function test_multiple_coupons_and_coupon_with_configured_switches(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $one = $this->coupon($f, 'CPN1A', ['value' => 10]);
        $two = $this->coupon($f, 'CPN2B', ['value' => 20]);
        $configured = $this->manual($f, ['value' => 5]);

        $result = $this->resolution($f, [$this->c($one), $this->c($two)]);
        $this->assertSame([$two], $this->ids($result));
        $this->assertSame([$one => 'MULTIPLE_COUPONS_DISABLED'], $this->excludedCodes($result));
        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'allowMultipleCoupons' => true]);
        $this->assertSame([$one, $two], $this->ids($this->resolution($f, [$this->c($one), $this->c($two)])));

        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'allowMultipleCoupons' => true, 'allowCouponWithConfigured' => false]);
        $result = $this->resolution($f, [$this->c($two), $this->m($configured)]);
        $this->assertSame([$two], $this->ids($result));
        $this->assertSame([$configured => 'COUPON_COMBINATION_NOT_ALLOWED'], $this->excludedCodes($result));
        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'allowCouponWithConfigured' => true]);
        $this->assertSame([$two, $configured], $this->ids($this->resolution($f, [$this->c($two), $this->m($configured)])));

        // Two configured discounts need neither coupon switch.
        $second = $this->manual($f, ['value' => 7]);
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $this->assertCount(2, $this->resolution($f, [$this->m($configured), $this->m($second)])['discounts']);
    }

    public function test_exclusive_coupon_stays_exclusive_even_when_coupons_may_combine(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'allowMultipleCoupons' => true, 'allowCouponWithConfigured' => true]);
        $coupon = $this->coupon($f, 'EXCL1', ['value' => 10, 'combinationBehavior' => 'exclusive']);
        $configured = $this->manual($f, ['value' => 50]);
        $result = $this->resolution($f, [$this->c($coupon), $this->m($configured)]);
        $this->assertSame([$configured], $this->ids($result));
        $this->assertSame([$coupon => 'EXCLUSIVE_DISCOUNT_CONFLICT'], $this->excludedCodes($result));
    }

    public function test_item_and_order_level_combination_uses_residual_after_items(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $item = $this->manual($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]]]);
        $order = $this->manual($f, ['value' => 10]);
        $result = $this->resolution($f, [$this->m($order), $this->m($item)]);
        $this->assertSame([$item], $this->ids($result), 'Best saving keeps the larger single discount when item+order is off.');
        $this->assertSame([$order => 'ORDER_ITEM_COMBINATION_NOT_ALLOWED'], $this->excludedCodes($result));

        $this->multi($f, ['allowOrderAfterItemDiscounts' => true]);
        $result = $this->resolution($f, [$this->m($order), $this->m($item)]);
        // Item-level is always applied first, whatever the reviewed order: 5.00, then 10% of the 15.00 left.
        $this->assertSame([$item, $order], $this->ids($result));
        $this->assertSame(['5.00', '1.50'], $this->amounts($result));
        $this->assertSame('6.50', $result['totals']['discountTotal']);
        $this->assertSame('items', $result['discounts'][0]['stage']);
        $this->assertSame('order', $result['discounts'][1]['stage']);
        $this->assertSame([], $result['excluded']);
    }

    public function test_different_items_only_uses_actual_allocation_overlap(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $latte = $this->manual($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]]]);
        $cookie = $this->manual($f, ['scope' => 'product', 'value' => 20, 'targetProductIds' => [$f['products'][1]]]);
        $both = $this->manual($f, ['scope' => 'product', 'value' => 10, 'targetProductIds' => $f['products']]);
        $sameLatte = $this->manual($f, ['scope' => 'product', 'value' => 30, 'targetProductIds' => [$f['products'][0]]]);

        $result = $this->resolution($f, [$this->m($latte), $this->m($cookie)]);
        $this->assertSame([$latte, $cookie], $this->ids($result));
        $this->assertSame(['5.00', '2.00'], $this->amounts($result));

        // A broad discount is not rejected: it is calculated on the disjoint remainder (the cookie only).
        $result = $this->resolution($f, [$this->m($latte), $this->m($both)]);
        $this->assertSame([$latte, $both], $this->ids($result));
        $this->assertSame(['5.00', '1.00'], $this->amounts($result));
        $this->assertSame([$f['items'][1]], array_column($result['discounts'][1]['allocations'], 'orderItemId'));

        // Nothing left for a second discount on the same item.
        $result = $this->resolution($f, [$this->m($latte), $this->m($sameLatte)]);
        $this->assertSame([$latte], $this->ids($result));
        $this->assertSame([$sameLatte => 'SAME_ITEM_STACKING_DISABLED'], $this->excludedCodes($result));

        // Two order-level discounts touch the same money.
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 15]);
        $result = $this->resolution($f, [$this->m($a), $this->m($b)]);
        $this->assertSame([$b], $this->ids($result));
        $this->assertSame([$a => 'SAME_ITEM_STACKING_DISABLED'], $this->excludedCodes($result));
    }

    public function test_same_item_stacking_is_sequential_not_additive(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $this->line($f, 0, '100.00');
        $a = $this->manual($f, ['scope' => 'product', 'value' => 10, 'targetProductIds' => [$f['products'][0]]]);
        $b = $this->manual($f, ['scope' => 'product', 'value' => 20, 'targetProductIds' => [$f['products'][0]]]);
        $result = $this->resolution($f, [$this->m($a), $this->m($b)]);
        $this->assertSame(['10.00', '18.00'], $this->amounts($result));
        $this->assertSame('28.00', $result['totals']['discountTotal']);
        $this->assertSame([['orderItemId' => $f['items'][0], 'amount' => '10.00']], $result['discounts'][0]['allocations']);
        $this->assertSame([['orderItemId' => $f['items'][0], 'amount' => '18.00']], $result['discounts'][1]['allocations']);
    }

    public function test_fixed_and_percentage_order_matters_and_never_goes_negative(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $this->line($f, 0, '100.00');
        $target = [$f['products'][0]];
        $fixed = $this->manual($f, ['scope' => 'product', 'type' => 'fixed', 'value' => 5, 'targetProductIds' => $target]);
        $percent = $this->manual($f, ['scope' => 'product', 'value' => 10, 'targetProductIds' => $target]);
        $fixedFirst = $this->resolution($f, [$this->m($fixed), $this->m($percent)]);
        $this->assertSame(['5.00', '9.50'], $this->amounts($fixedFirst));
        $percentFirst = $this->resolution($f, [$this->m($percent), $this->m($fixed)]);
        $this->assertSame(['10.00', '5.00'], $this->amounts($percentFirst));

        $all = $this->manual($f, ['scope' => 'product', 'value' => 100, 'targetProductIds' => $target]);
        $extra = $this->manual($f, ['scope' => 'product', 'type' => 'fixed', 'value' => 50, 'targetProductIds' => $target]);
        $result = $this->resolution($f, [$this->m($all), $this->m($extra)]);
        $this->assertSame([$all], $this->ids($result));
        $this->assertSame([$extra => 'DISCOUNT_ITEMS_NOT_ELIGIBLE'], $this->excludedCodes($result));
        $this->assertSame('100.00', $result['totals']['discountTotal']);
        $this->assertSame('10.00', $result['totals']['total']);
    }

    public function test_exact_decimal_rounding_is_half_up_per_discount_on_the_residual(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $this->line($f, 0, '19.99');
        $target = [$f['products'][0]];
        $a = $this->manual($f, ['scope' => 'product', 'value' => 15, 'targetProductIds' => $target]);
        $b = $this->manual($f, ['scope' => 'product', 'value' => 15, 'targetProductIds' => $target]);
        $result = $this->resolution($f, [$this->m($a), $this->m($b)]);
        $this->assertSame(['3.00', '2.55'], $this->amounts($result));
        $this->assertSame('5.55', $result['totals']['discountTotal']);
        $this->assertSame('24.44', $result['totals']['total']);
    }

    public function test_maximum_total_percent_is_the_single_aggregate_cap(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'maximumTotalDiscountPercent' => 25]);
        $a = $this->manual($f, ['value' => 20]);
        $b = $this->manual($f, ['value' => 20]);
        $result = $this->resolution($f, [$this->m($a), $this->m($b)]);
        $this->assertSame(['4.00', '1.00'], $this->amounts($result));
        $this->assertSame([false, true], array_column($result['discounts'], 'capped'));
        $this->assertSame('5.00', $result['totals']['discountTotal']);

        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'maximumTotalDiscountPercent' => 20]);
        $result = $this->resolution($f, [$this->m($a), $this->m($b)]);
        $this->assertSame([$a], $this->ids($result));
        $this->assertSame([$b => 'MAXIMUM_TOTAL_DISCOUNT_EXCEEDED'], $this->excludedCodes($result));
        $this->assertSame('4.00', $result['totals']['discountTotal']);
        $this->assertSame(20.0, $result['policy']['maximumTotalDiscountPercent']);
    }

    public function test_conflict_resolution_best_saving_priority_and_deterministic_ties(): void
    {
        $f = $this->fixture();
        // Multiple discounts disabled: exactly one of the requested discounts can win.
        $important = $this->manual($f, ['value' => 10, 'priority' => 10]);
        $rich = $this->manual($f, ['value' => 50, 'priority' => 1]);
        $this->assertSame([$rich], $this->ids($this->resolution($f, [$this->m($important), $this->m($rich)])));
        $this->settings($f, ['conflictResolution' => 'priority']);
        $result = $this->resolution($f, [$this->m($important), $this->m($rich)]);
        $this->assertSame([$important], $this->ids($result));
        $this->assertSame([$rich => 'MULTIPLE_DISCOUNTS_DISABLED'], $this->excludedCodes($result));

        // Higher number is the stronger priority; equal priorities fall back to the lower id.
        $x = $this->manual($f, ['value' => 20, 'priority' => 5]);
        $y = $this->manual($f, ['value' => 20, 'priority' => 5]);
        $this->assertSame([$x], $this->ids($this->resolution($f, [$this->m($y), $this->m($x)])));
        $this->settings($f, ['conflictResolution' => 'best_saving']);
        $this->assertSame([$x], $this->ids($this->resolution($f, [$this->m($y), $this->m($x)])));
        $this->assertSame([$x], $this->ids($this->resolution($f, [$this->m($x), $this->m($y)])));
    }

    public function test_priority_resolution_keeps_compatible_discounts_by_priority(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['conflictResolution' => 'priority', 'stackingMode' => 'same_item_allowed', 'maximumDiscountsPerOrder' => 2]);
        $low = $this->manual($f, ['value' => 50, 'priority' => 1]);
        $mid = $this->manual($f, ['value' => 10, 'priority' => 5]);
        $high = $this->manual($f, ['value' => 5, 'priority' => 9]);
        $result = $this->resolution($f, [$this->m($low), $this->m($mid), $this->m($high)]);
        // Priority picks high + mid even though low would save more. Reviewed order still sequences them.
        $this->assertSame([$mid, $high], $this->ids($result));
        $this->assertSame([$low => 'MAXIMUM_DISCOUNT_COUNT_EXCEEDED'], $this->excludedCodes($result));
    }

    public function test_product_category_and_variant_targets_participate(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Drinks', 'is_active' => true]);
        DB::table('products')->where('id', $f['products'][1])->update(['category_id' => $category]);
        $large = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => 'Large', 'is_active' => true]);
        $regular = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => 'Regular', 'is_active' => true]);
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $regular]);
        $variant = $this->manual($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]], 'productVariantSelections' => [['productId' => $f['products'][0], 'variantMode' => 'selected', 'variantIds' => [$large]]]]);
        $byCategory = $this->manual($f, ['scope' => 'category', 'value' => 20, 'targetCategoryIds' => [$category]]);

        try {
            $this->resolution($f, [$this->m($variant), $this->m($byCategory)]);
            $this->fail('A Regular line must not satisfy a Large-only discount.');
        } catch (OrderLifecycleException $exception) {
            $this->assertSame('DISCOUNT_ITEMS_NOT_ELIGIBLE', $exception->domainCode);
        }
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $large]);
        $result = $this->resolution($f, [$this->m($variant), $this->m($byCategory)]);
        $this->assertSame([$variant, $byCategory], $this->ids($result));
        $this->assertSame(['5.00', '2.00'], $this->amounts($result));
    }

    public function test_package_selected_variants_work_in_a_multi_discount_set(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed', 'allowOrderAfterItemDiscounts' => true]);
        $large = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => 'Large', 'is_active' => true]);
        $regular = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => 'Regular', 'is_active' => true]);
        $requirements = [['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$large]], ['productId' => $f['products'][1], 'quantity' => 1]];
        $package = $this->manual($f, ['scope' => 'bundle', 'value' => 50, 'bundleRequirements' => $requirements]);
        $product = $this->manual($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]]]);
        $order = $this->manual($f, ['value' => 10]);

        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $regular]);
        try {
            $this->resolution($f, [$this->m($package), $this->m($order)]);
            $this->fail('Regular must not satisfy the Large requirement.');
        } catch (OrderLifecycleException $exception) {
            $this->assertSame('DISCOUNT_ITEMS_NOT_ELIGIBLE', $exception->domainCode);
        }

        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $large]);
        $withOrder = $this->resolution($f, [$this->m($package), $this->m($order)]);
        $this->assertSame([$package, $order], $this->ids($withOrder));
        // The package is item-level: 50% of 20.00, then 10% of the 10.00 that remains.
        $this->assertSame(['10.00', '1.00'], $this->amounts($withOrder));

        // After another item discount the package is priced on what its lines still hold.
        $stacked = $this->resolution($f, [$this->m($product), $this->m($package)]);
        $this->assertSame([$product, $package], $this->ids($stacked));
        $this->assertSame(['5.00', '7.50'], $this->amounts($stacked));
    }

    public function test_ineligible_discount_throws_when_strict_and_is_excluded_when_not(): void
    {
        $f = $this->fixture();
        $this->multi($f);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        DB::table('discounts')->where('id', $b)->update(['is_active' => false]);
        try {
            $this->resolution($f, [$this->m($a), $this->m($b)]);
            $this->fail('An inactive requested discount must be rejected.');
        } catch (OrderLifecycleException $exception) {
            $this->assertSame('DISCOUNT_INACTIVE', $exception->domainCode);
        }
        $result = app(DiscountResolutionService::class)->resolve($f['tenant'], DB::table('orders')->find($f['order']), [$this->m($a), $this->m($b)], null, false);
        $this->assertSame([$a], $this->ids($result));
        $this->assertSame([$b => 'DISCOUNT_INACTIVE'], $this->excludedCodes($result));
    }

    public function test_set_apply_persists_sequence_allocations_and_replays_idempotently(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $review = $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]);
        $this->assertSame([1, 2], array_column($review['requested'], 'position'));
        $this->assertSame([$a, $b], $this->ids($review));
        $this->assertSame([], $review['excluded']);
        $this->assertTrue($review['policy']['allowMultipleDiscounts']);
        $this->assertSame('5.60', $review['after']['discountTotal']);

        $applied = $this->applyReview($f, $review, 'set-1');
        $this->assertSame($applied, $this->applyReview($f, $review, 'set-1'));
        $rows = DB::table('order_discounts')->where('order_id', $f['order'])->orderBy('application_sequence')->get();
        $this->assertSame([1, 2], $rows->pluck('application_sequence')->map(fn ($v) => (int) $v)->all());
        $this->assertSame([$a, $b], $rows->pluck('discount_id')->map(fn ($v) => (int) $v)->all());
        $this->assertSame(app(DiscountSettingsService::class)->read($f['tenant'])['version'], (int) $rows[0]->settings_version);
        $this->assertDatabaseCount('order_discount_allocations', 4);
        $this->assertSame('5.60', DB::table('orders')->find($f['order'])->discount_total);
        $this->assertSame('14.40', DB::table('orders')->find($f['order'])->total);
        $stored = json_decode(DB::table('order_discount_intents')->where('order_id', $f['order'])->value('intent'), true);
        $this->assertSame([[$a, 'configured_manual'], [$b, 'configured_manual']], array_map(fn ($i) => [$i['discountId'], $i['source']], $stored));
        $metadata = json_decode($rows[1]->calculation_metadata, true);
        $this->assertSame(2, $metadata['sequence']);
        $this->assertSame('sequential', $metadata['stacking']);
        $this->assertSame('same_item_allowed', $metadata['policy']['stackingMode']);

        $state = $this->getJson('/api/v1/orders/'.$f['order'].'/discount-state', $f['headers'])->assertOk()->json('data');
        $this->assertSame([1, 2], array_column($state['discounts'], 'sequence'));
        $this->assertCount(2, $state['explicitIntents']);
        $this->assertSame($a, $state['explicitIntent']['discountId']);
        $this->assertTrue($state['requiresDiscountBreakdown']);
        $this->assertSame(1, DB::table('activity_logs')->where('action', 'discount.engine.set')->count());
    }

    public function test_legacy_single_intent_apply_replaces_the_whole_set_and_remove_clears_it(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $this->applyReview($f, $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]), 'set');
        $this->assertDatabaseCount('order_discounts', 2);

        $replaced = $this->applyReview($f, $this->preview($f, ['action' => 'apply', 'intent' => $this->m($a)]), 'legacy');
        $this->assertSame([$a], array_column($replaced['discounts'], 'discountId'));
        $this->assertDatabaseCount('order_discounts', 1);
        $this->assertSame('2.00', DB::table('orders')->find($f['order'])->discount_total);

        $this->applyReview($f, $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]), 'again');
        $removed = $this->applyReview($f, $this->preview($f, ['action' => 'remove']), 'clear');
        $this->assertSame([], $removed['discounts']);
        $this->assertDatabaseCount('order_discounts', 0);
        $this->assertSame([], $removed['explicitIntents']);
    }

    public function test_set_preview_excludes_by_policy_and_apply_saves_only_the_reviewed_result(): void
    {
        $f = $this->fixture();
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $review = $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]);
        $this->assertSame([$b], $this->ids($review));
        $this->assertSame('MULTIPLE_DISCOUNTS_DISABLED', $review['excluded'][0]['code']);
        $this->assertSame(1, $review['excluded'][0]['position']);
        $this->applyReview($f, $review, 'only-b');
        $this->assertSame([$b], DB::table('order_discounts')->pluck('discount_id')->map(fn ($v) => (int) $v)->all());
        $this->assertCount(1, $this->getJson('/api/v1/orders/'.$f['order'].'/discount-state', $f['headers'])->json('data.explicitIntents'));
    }

    public function test_stale_set_review_is_rejected_after_a_policy_change(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $review = $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]);
        $this->settings($f, ['allowMultipleDiscounts' => false]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/operations', ['reviewId' => $review['reviewId'], 'operationId' => 'stale-policy'], $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_REVIEW_STALE');
        $this->assertDatabaseCount('order_discounts', 0);
    }

    public function test_cart_recalculation_keeps_requested_set_but_follows_current_policy(): void
    {
        $f = $this->fixture();
        $this->multi($f, ['stackingMode' => 'same_item_allowed']);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $this->applyReview($f, $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]), 'held');
        DB::table('orders')->where('id', $f['order'])->update(['status' => 'held']);

        // Saved rows are pinned until the cart changes: a policy edit alone never rewrites them.
        $this->settings($f, ['allowMultipleDiscounts' => false]);
        $this->assertDatabaseCount('order_discounts', 2);
        $this->assertSame('5.60', DB::table('orders')->find($f['order'])->discount_total);

        DB::table('order_items')->where('id', $f['items'][0])->update(['quantity' => 2, 'total' => '20.00']);
        DB::transaction(fn () => app(PosPricingService::class)->recalculateOrder($f['tenant'], $f['order']));
        $this->assertSame([$b], DB::table('order_discounts')->pluck('discount_id')->map(fn ($v) => (int) $v)->all());
        $this->assertCount(2, json_decode(DB::table('order_discount_intents')->where('order_id', $f['order'])->value('intent'), true), 'The reviewed intent set is not rewritten by a cart edit.');
    }
}
