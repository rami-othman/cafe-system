<?php

namespace Tests\Feature;

use App\Services\DiscountEligibilityService;
use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

/**
 * Discount hardening Stage B: branch-local status, zero-value behavior (characterized,
 * not changed) and exact-decimal package arithmetic. The fixture branch is
 * Asia/Damascus (UTC+3, no DST); a second branch is Pacific/Pago_Pago (UTC-11).
 */
class DiscountStageBHardeningTest extends TestCase
{
    use DiscountEngineFixture;
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function at(string $utc): void
    {
        Carbon::setTestNow(Carbon::parse($utc, 'UTC'));
    }

    private function fixtureAt(string $utc): array
    {
        $this->at($utc);

        return $this->fixture();
    }

    private function pagoBranch(array $f): int
    {
        return (int) DB::table('branches')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Pago', 'is_active' => true, 'timezone' => 'Pacific/Pago_Pago']);
    }

    private function management(array $f, int $id): array
    {
        return $this->getJson("/api/v1/discounts/{$id}", $f['headers'])->assertOk()->json('data');
    }

    private function available(array $f): array
    {
        return collect($this->getJson("/api/v1/discounts/available?orderId={$f['order']}", $f['headers'])->assertOk()->json('data'))->keyBy('id')->all();
    }

    public function test_start_day_midnight_is_decided_by_the_branch_clock_in_status_and_pos(): void
    {
        $f = $this->fixtureAt('2026-10-20 12:00:00');
        $id = $this->policy($f, ['applicationMode' => 'manual', 'startDate' => '2026-10-21']);

        // 23:59:59 on the 20th in Damascus: not started anywhere.
        $this->at('2026-10-20 20:59:59');
        $this->assertSame('scheduled', $this->management($f, $id)['status']);
        $this->assertArrayNotHasKey($id, $this->available($f));

        // 00:00:00 on the 21st in Damascus (server/UTC is still the 20th): live and selectable.
        $this->at('2026-10-20 21:00:00');
        $this->assertSame('active', $this->management($f, $id)['status']);
        $this->assertTrue($this->available($f)[$id]['eligible']);
    }

    public function test_end_date_expires_at_the_branch_local_midnight_not_the_server_midnight(): void
    {
        $f = $this->fixtureAt('2026-10-20 12:00:00');
        $id = $this->policy($f, ['applicationMode' => 'manual', 'endDate' => '2026-10-20']);

        $this->at('2026-10-20 20:59:59');
        $this->assertSame('active', $this->management($f, $id)['status']);
        $this->assertArrayHasKey($id, $this->available($f));

        // The server clock still says the 20th; the branch has entered the 21st.
        $this->at('2026-10-20 21:00:00');
        $this->assertSame('expired', $this->management($f, $id)['status']);
        $this->assertArrayNotHasKey($id, $this->available($f));

        $this->at('2026-10-22 12:00:00');
        $this->assertSame('expired', $this->management($f, $id)['status']);
    }

    public function test_a_multi_branch_policy_reports_per_branch_status_and_is_not_reported_expired_while_live(): void
    {
        $f = $this->fixtureAt('2026-10-20 12:00:00');
        $pago = $this->pagoBranch($f);
        $id = $this->policy($f, ['applicationMode' => 'manual', 'endDate' => '2026-10-20']);
        $this->at('2026-10-20 21:00:00');

        $detail = $this->management($f, $id);
        $this->assertSame('active', $detail['status'], 'Still live in Pago Pago (10:00 on the 20th).');
        $this->assertSame([['branchId' => $f['branch'], 'status' => 'expired'], ['branchId' => $pago, 'status' => 'active']], $detail['branchStatuses']);
        $this->assertCount(1, $this->getJson('/api/v1/discounts?status=active', $f['headers'])->json('data'));
        $this->assertCount(0, $this->getJson('/api/v1/discounts?status=expired', $f['headers'])->json('data'));

        // A policy limited to the expired branch is expired, not "active somewhere".
        $local = $this->policy($f, ['applicationMode' => 'manual', 'endDate' => '2026-10-20', 'appliesToAllBranches' => false, 'branchIds' => [$f['branch']]]);
        $this->assertSame('expired', $this->management($f, $local)['status']);
        $this->assertSame([['branchId' => $f['branch'], 'status' => 'expired']], $this->management($f, $local)['branchStatuses']);
    }

    public function test_scheduled_in_one_branch_and_live_in_another_is_active_overall_and_inactive_beats_dates(): void
    {
        $f = $this->fixtureAt('2026-10-20 12:00:00');
        $pago = $this->pagoBranch($f);
        $id = $this->policy($f, ['applicationMode' => 'manual', 'startDate' => '2026-10-21']);
        $this->at('2026-10-20 21:00:00');

        $detail = $this->management($f, $id);
        $this->assertSame('active', $detail['status']);
        $this->assertSame([['branchId' => $f['branch'], 'status' => 'active'], ['branchId' => $pago, 'status' => 'scheduled']], $detail['branchStatuses']);

        $this->patchJson("/api/v1/discounts/{$id}/status", ['isActive' => false], $f['headers'])->assertOk();
        $this->assertSame('inactive', $this->management($f, $id)['status']);
        $this->assertArrayNotHasKey($id, $this->available($f));
    }

    public function test_overnight_schedule_crosses_local_midnight(): void
    {
        $f = $this->fixtureAt('2026-10-20 12:00:00');
        $id = $this->policy($f, ['applicationMode' => 'manual', 'startTime' => '22:00', 'endTime' => '02:00']);

        $this->at('2026-10-20 19:30:00'); // 22:30 local
        $this->assertTrue($this->available($f)[$id]['eligible']);
        $this->at('2026-10-20 22:30:00'); // 01:30 local on the next day
        $this->assertTrue($this->available($f)[$id]['eligible']);
        $this->at('2026-10-20 23:30:00'); // 02:30 local
        $this->assertFalse($this->available($f)[$id]['eligible']);
        $this->at('2026-10-20 12:00:00'); // 15:00 local
        $this->assertFalse($this->available($f)[$id]['eligible']);
    }

    public function test_the_engine_and_the_pos_list_agree_at_the_boundary(): void
    {
        $f = $this->fixtureAt('2026-10-20 12:00:00');
        $id = $this->policy($f, ['applicationMode' => 'manual', 'startDate' => '2026-10-21']);
        $intent = ['source' => 'configured_manual', 'discountId' => $id];

        $this->at('2026-10-20 20:59:59');
        $this->postJson("/api/v1/orders/{$f['order']}/discounts/preview", ['action' => 'apply', 'intent' => $intent], $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_NOT_STARTED');
        $this->at('2026-10-20 21:00:00');
        $this->assertTrue($this->available($f)[$id]['eligible']);
        $this->postJson("/api/v1/orders/{$f['order']}/discounts/preview", ['action' => 'apply', 'intent' => $intent], $f['headers'])->assertOk();
    }

    public function test_legacy_timestamp_windows_keep_instant_semantics(): void
    {
        $f = $this->fixtureAt('2026-10-20 12:00:00');
        $id = $this->policy($f, ['applicationMode' => 'manual']);
        DB::table('discounts')->where('id', $id)->update(['starts_at' => '2026-10-20 12:30:00', 'ends_at' => '2026-10-20 13:00:00']);

        $this->assertSame('scheduled', $this->management($f, $id)['status']);
        $this->at('2026-10-20 12:45:00');
        $this->assertSame('active', $this->management($f, $id)['status']);
        $this->at('2026-10-20 13:00:01');
        $this->assertSame('expired', $this->management($f, $id)['status']);
    }

    public function test_pos_list_reports_valid_until_as_a_calendar_day_or_a_utc_instant_with_its_zone(): void
    {
        $f = $this->fixtureAt('2026-10-20 12:00:00');
        $day = $this->policy($f, ['applicationMode' => 'manual', 'endDate' => '2026-10-25']);
        $legacy = $this->policy($f, ['applicationMode' => 'manual']);
        DB::table('discounts')->where('id', $legacy)->update(['ends_at' => '2026-10-25 22:30:00']);
        $open = $this->policy($f, ['applicationMode' => 'manual']);

        $rows = $this->available($f);

        $this->assertSame(['validUntil' => '2026-10-25', 'validUntilKind' => 'date', 'validUntilTimezone' => null], array_intersect_key($rows[$day], array_flip(['validUntil', 'validUntilKind', 'validUntilTimezone'])));
        $this->assertSame(['validUntil' => '2026-10-25T22:30:00Z', 'validUntilKind' => 'instant', 'validUntilTimezone' => 'Asia/Damascus'], array_intersect_key($rows[$legacy], array_flip(['validUntil', 'validUntilKind', 'validUntilTimezone'])));
        $this->assertNull($rows[$open]['validUntil']);
        $this->assertNull($rows[$open]['validUntilKind']);
        // An end date wins over a stale legacy instant on the same row.
        DB::table('discounts')->where('id', $day)->update(['ends_at' => '2026-01-01 00:00:00']);
        $this->assertSame('2026-10-25', $this->available($f)[$day]['validUntil']);
    }

    // --- zero-value behavior: characterized, deliberately unchanged -----------

    public function test_configured_zero_value_is_documented_legacy_behavior_with_automatic_off(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $zero = $this->policy($f, ['applicationMode' => 'manual', 'name' => 'Zero', 'value' => 0]);

        $result = $this->resolution($f, ['source' => 'configured_manual', 'discountId' => $zero]);
        // Documented (discount_settings_backend_contract.md): configured zero Manual/Code stays valid,
        // is snapshotted, and consumes usage once at settlement.
        $this->assertSame([[$zero, 'configured_manual', '0.00']], array_map(fn ($d) => [$d['discountId'], $d['source'], $d['amount']], $result['discounts']));
        $this->assertSame('20.00', $result['totals']['total']);
    }

    public function test_zero_value_automatic_promotions_never_apply_and_never_consume_usage(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $this->settings($f, ['automaticEnabled' => true]);
        $this->policy($f, ['applicationMode' => 'automatic', 'name' => 'Zero promo', 'value' => 0]);
        $real = $this->policy($f, ['applicationMode' => 'automatic', 'name' => 'Real promo', 'value' => 10]);

        $result = $this->resolution($f);
        $this->assertSame([$real], array_column($result['discounts'], 'discountId'));
        $quote = $this->quote($f, $f['cash']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote), $f['headers'])->assertOk();
        $this->assertSame([$real], DB::table('discount_usages')->where('order_id', $f['order'])->pluck('discount_id')->map(fn ($id) => (int) $id)->all());
    }

    public function test_an_explicit_zero_value_discount_is_excluded_by_the_v3_engine_when_automatic_is_on(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $this->settings($f, ['automaticEnabled' => true]);
        $zero = $this->policy($f, ['applicationMode' => 'manual', 'name' => 'Zero', 'value' => 0]);

        $result = $this->resolution($f, ['source' => 'configured_manual', 'discountId' => $zero]);
        $this->assertSame([], $result['discounts'], 'V3 resolveSet drops a discount that saves nothing.');
        $this->assertSame('20.00', $result['totals']['total']);
        $quote = $this->quote($f, $f['cash']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote), $f['headers'])->assertOk();
        $this->assertSame(0, DB::table('discount_usages')->where('order_id', $f['order'])->count());
    }

    // --- exact-decimal package arithmetic ------------------------------------

    /** @return array{0: array, 1: int} */
    private function packageOrder(string $quantity, string $unitPrice, string $lineTotal, int $percent = 100): array
    {
        $f = $this->fixture();
        DB::table('order_items')->where('id', $f['items'][0])->update(['quantity' => $quantity, 'unit_price' => $unitPrice, 'total' => $lineTotal]);
        DB::table('order_items')->where('id', $f['items'][1])->delete();
        DB::table('orders')->where('id', $f['order'])->update(['subtotal' => $lineTotal, 'total' => $lineTotal]);
        $bundle = $this->policy($f, ['applicationMode' => 'manual', 'scope' => 'bundle', 'value' => $percent, 'bundleRequirements' => [['productId' => $f['products'][0], 'quantity' => (float) $quantity]]]);

        return [$f, $bundle];
    }

    public function test_package_subtotal_is_exact_half_up_for_fractional_quantity_times_price(): void
    {
        foreach ([
            ['1.5', '0.15', '0.23', '0.23'],   // 0.225 -> 0.23
            ['2.5', '0.45', '1.13', '1.13'],   // 1.125 -> 1.13
            ['0.333', '1.15', '0.38', '0.38'], // 0.38295 -> 0.38
            ['3.5', '0.01', '0.04', '0.04'],   // 0.035 -> 0.04
            ['1.25', '0.82', '1.03', '1.03'],  // 1.025 -> 1.03
        ] as [$quantity, $price, $lineTotal, $expected]) {
            [$f, $bundle] = $this->packageOrder($quantity, $price, $lineTotal);
            $row = DB::table('discounts')->find($bundle);
            $result = app(DiscountEligibilityService::class)->assertApplicable($f['tenant'], $row, DB::table('orders')->find($f['order']));
            $this->assertSame($expected, $result['eligibleSubtotal'], "{$quantity} x {$price}");
            $this->assertSame(
                (string) BigDecimal::of($quantity)->multipliedBy($price)->toScale(2, RoundingMode::HALF_UP),
                $result['eligibleSubtotal'],
                'Matches an independent exact HALF_UP computation.'
            );
        }
    }

    public function test_package_savings_never_exceed_the_matched_amount_and_allocations_reconcile(): void
    {
        [$f, $bundle] = $this->packageOrder('1.5', '0.15', '0.23');

        $result = $this->resolution($f, ['source' => 'configured_manual', 'discountId' => $bundle]);
        $discount = $result['discounts'][0];
        $this->assertSame('0.23', $discount['amount']);
        $allocated = array_reduce($discount['allocations'], fn (BigDecimal $sum, array $a) => $sum->plus($a['amount']), BigDecimal::zero());
        $this->assertSame('0.23', (string) $allocated->toScale(2));
        $this->assertSame('0.00', $result['totals']['total']);
        $this->assertSame('0.23', $result['totals']['discountTotal']);
        $this->assertLessThanOrEqual(0.23, (float) $discount['amount']);
    }

    public function test_package_with_two_lines_sums_exact_cents_once(): void
    {
        $f = $this->fixture();
        // 0.1 + 0.2 style drift: 3 x 0.10 + 3 x 0.20 matched exactly = 0.90.
        DB::table('order_items')->where('id', $f['items'][0])->update(['quantity' => 3, 'unit_price' => '0.10', 'total' => '0.30']);
        DB::table('order_items')->where('id', $f['items'][1])->update(['quantity' => 3, 'unit_price' => '0.20', 'total' => '0.60']);
        DB::table('orders')->where('id', $f['order'])->update(['subtotal' => '0.90', 'total' => '0.90']);
        $bundle = $this->policy($f, ['applicationMode' => 'manual', 'scope' => 'bundle', 'value' => 50, 'bundleRequirements' => [
            ['productId' => $f['products'][0], 'quantity' => 3], ['productId' => $f['products'][1], 'quantity' => 3],
        ]]);

        $result = app(DiscountEligibilityService::class)->assertApplicable($f['tenant'], DB::table('discounts')->find($bundle), DB::table('orders')->find($f['order']));
        $this->assertSame('0.90', $result['eligibleSubtotal']);
        $this->assertSame('0.45', $result['amount']);
        $this->assertSame('0.45', $this->resolution($f, ['source' => 'configured_manual', 'discountId' => $bundle])['discounts'][0]['amount']);
    }

    public function test_a_package_that_is_not_fully_present_matches_nothing(): void
    {
        [$f, $bundle] = $this->packageOrder('1.5', '0.15', '0.23');
        DB::table('discount_bundle_requirements')->where('discount_id', $bundle)->update(['quantity' => '1.501']);

        $this->expectExceptionMessage('No order items are eligible for this discount.');
        app(DiscountEligibilityService::class)->assertApplicable($f['tenant'], DB::table('discounts')->find($bundle), DB::table('orders')->find($f['order']));
    }
}
