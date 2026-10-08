<?php

namespace Tests\Feature;

use App\Services\CouponCodeGenerator;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

/** Discount System V3 Phase 1: short generated coupon codes and per-discount combination behavior. */
class DiscountV3CouponsAndCombinationTest extends TestCase
{
    use DiscountEngineFixture;
    use RefreshDatabase;

    /** The fixture isolates Automatic; production runs the legacy single-discount path, so switch it off. */
    private function legacyRuntime(): array
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);

        return $f;
    }

    /** Legacy single-discount client: no X-Discount-Contract header. */
    private function legacyHeaders(array $f): array
    {
        return ['Authorization' => 'Bearer '.$f['token']];
    }

    private function codePolicy(array $f, string $code, array $changes = []): int
    {
        return (int) DB::table('discounts')->insertGetId($changes + ['tenant_id' => $f['tenant'], 'name' => 'Coupon '.$code, 'code' => $code, 'application_mode' => 'code', 'type' => 'percentage', 'value' => 10, 'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now()]);
    }

    /** A generator whose random source replays the given codes character by character. */
    private function replaying(array $codes, ?int &$calls = null): CouponCodeGenerator
    {
        $indexes = [];
        foreach ($codes as $code) {
            foreach (str_split($code) as $char) {
                $indexes[] = strpos(CouponCodeGenerator::ALPHABET, $char);
            }
        }
        $position = 0;

        return new CouponCodeGenerator(function (int $min, int $max) use ($indexes, &$position, &$calls): int {
            $calls++;

            return $indexes[$position++ % count($indexes)];
        });
    }

    public function test_generated_codes_are_five_unambiguous_uppercase_characters(): void
    {
        $f = $this->fixture();
        $this->assertSame(5, CouponCodeGenerator::LENGTH);
        $this->assertDoesNotMatchRegularExpression('/[O0I1]/', CouponCodeGenerator::ALPHABET);
        $generator = app(CouponCodeGenerator::class);
        $seen = [];
        for ($i = 0; $i < 300; $i++) {
            $code = $generator->generate($f['tenant']);
            $this->assertMatchesRegularExpression('/^[A-HJ-NP-Z2-9]{5}$/', $code);
            $seen[$code] = true;
        }
        $this->assertGreaterThan(250, count($seen), 'Codes must be unpredictable, not a fixed sequence.');
        $response = $this->postJson('/api/v1/discounts/generate-code', [], $this->legacyHeaders($f))->assertOk();
        $this->assertMatchesRegularExpression('/^[A-HJ-NP-Z2-9]{5}$/', $response->json('data.code'));
    }

    public function test_generated_code_is_saved_case_insensitively_and_unique_per_tenant(): void
    {
        $f = $this->fixture();
        $code = $this->postJson('/api/v1/discounts/generate-code', [], $this->legacyHeaders($f))->json('data.code');
        $payload = ['name' => 'Short', 'applicationMode' => 'code', 'code' => strtolower($code), 'type' => 'percentage', 'scope' => 'order', 'value' => 10, 'isActive' => true, 'appliesToAllBranches' => true];
        $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->assertJsonPath('data.code', $code);
        $this->postJson('/api/v1/discounts', ['name' => 'Again', 'code' => $code] + $payload, $f['headers'])->assertUnprocessable()->assertJsonValidationErrors('code');
        // The same code is free in another tenant.
        $other = DB::table('tenants')->insertGetId(['name' => 'Other', 'slug' => uniqid('other-')]);
        DB::table('discounts')->insert(['tenant_id' => $other, 'name' => 'Other', 'code' => $code, 'application_mode' => 'code', 'type' => 'percentage', 'value' => 5, 'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $this->assertSame(2, DB::table('discounts')->whereRaw('LOWER(code) = ?', [strtolower($code)])->count());
        // The database stays final authority, even for a race past validation.
        try {
            DB::transaction(fn () => DB::table('discounts')->insert(['tenant_id' => $f['tenant'], 'name' => 'Race', 'code' => strtolower($code), 'application_mode' => 'code', 'type' => 'percentage', 'value' => 5, 'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now()]));
            $this->fail('A case-insensitive duplicate in one tenant must be rejected by the database.');
        } catch (QueryException $exception) {
            $this->assertSame('23505', $exception->errorInfo[0]);
        }
    }

    public function test_collisions_are_retried_with_a_fresh_candidate(): void
    {
        $f = $this->fixture();
        $this->codePolicy($f, 'k7m4p'); // Stored differently cased: collision is case-insensitive.
        $this->codePolicy($f, 'A9X2D');
        $other = DB::table('tenants')->insertGetId(['name' => 'Other', 'slug' => uniqid('other-')]);
        $this->codePolicy($f, 'R6F8Q', ['deleted_at' => now()]);
        $calls = 0;
        $generator = $this->replaying(['K7M4P', 'A9X2D', 'R6F8Q'], $calls);
        // Two live collisions are skipped; the soft-deleted code is free again (index ignores it).
        $this->assertSame('R6F8Q', $generator->generate($f['tenant']));
        $this->assertSame(15, $calls);
        $this->assertSame('K7M4P', $this->replaying(['K7M4P'])->generate($other), 'Collisions are tenant scoped.');
    }

    public function test_retry_is_bounded_and_fails_cleanly(): void
    {
        $f = $this->fixture();
        $this->codePolicy($f, 'K7M4P');
        $calls = 0;
        try {
            $this->replaying(['K7M4P'], $calls)->generate($f['tenant']);
            $this->fail('Exhausting every attempt must fail.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('code', $exception->errors());
        }
        $this->assertSame(CouponCodeGenerator::MAX_ATTEMPTS * CouponCodeGenerator::LENGTH, $calls);
        $this->assertSame(1, DB::table('discounts')->where('tenant_id', $f['tenant'])->count());
    }

    public function test_existing_long_codes_keep_working_and_manual_codes_are_not_limited_to_five_characters(): void
    {
        $f = $this->legacyRuntime();
        $legacy = $this->codePolicy($f, 'CPN-AB2C-9XYZ', ['value' => 20]);
        $this->postJson("/api/v1/orders/{$f['order']}/discounts/apply", ['code' => 'cpn-ab2c-9xyz'], $this->legacyHeaders($f))->assertOk()->assertJsonPath('data.discount.id', $legacy)->assertJsonPath('data.discount.amount', 4);
        $this->assertDatabaseHas('discounts', ['id' => $legacy, 'code' => 'CPN-AB2C-9XYZ']);
        $manual = ['name' => 'Summer sale', 'applicationMode' => 'code', 'code' => 'summer-offer-2026', 'type' => 'percentage', 'scope' => 'order', 'value' => 5, 'isActive' => true, 'appliesToAllBranches' => true];
        $this->postJson('/api/v1/discounts', $manual, $f['headers'])->assertCreated()->assertJsonPath('data.code', 'SUMMER-OFFER-2026');
        // Editing an old long coupon keeps its code untouched.
        $payload = $this->getJson("/api/v1/discounts/$legacy", $f['headers'])->json('data');
        unset($payload['productVariantSelections']);
        $payload['name'] = 'Renamed';
        $this->putJson("/api/v1/discounts/$legacy", $payload, $f['headers'])->assertOk()->assertJsonPath('data.code', 'CPN-AB2C-9XYZ');
        // Generating new codes never rewrites existing ones.
        app(CouponCodeGenerator::class)->generate($f['tenant']);
        $this->assertSame(['CPN-AB2C-9XYZ', 'SUMMER-OFFER-2026'], DB::table('discounts')->where('tenant_id', $f['tenant'])->orderBy('id')->pluck('code')->all());
    }

    public function test_combination_behavior_defaults_validates_and_round_trips(): void
    {
        $f = $this->fixture();
        $payload = ['name' => 'Combo', 'applicationMode' => 'manual', 'type' => 'percentage', 'scope' => 'order', 'value' => 10, 'isActive' => true, 'appliesToAllBranches' => true];
        $implicit = $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->assertJsonPath('data.combinationBehavior', 'follow_cafe_policy')->json('data.id');
        $exclusive = $this->postJson('/api/v1/discounts', $payload + ['combinationBehavior' => 'exclusive'], $f['headers'])->assertCreated()->assertJsonPath('data.combinationBehavior', 'exclusive')->json('data.id');
        $this->postJson('/api/v1/discounts', $payload + ['combinationBehavior' => 'follow_cafe_policy'], $f['headers'])->assertCreated()->assertJsonPath('data.combinationBehavior', 'follow_cafe_policy');
        foreach (['stack', '', null, 1, 'Exclusive', 'always'] as $bad) {
            $this->postJson('/api/v1/discounts', $payload + ['combinationBehavior' => $bad], $f['headers'])->assertUnprocessable()->assertJsonValidationErrors('combinationBehavior');
        }
        $this->getJson("/api/v1/discounts/$exclusive", $f['headers'])->assertJsonPath('data.combinationBehavior', 'exclusive');
        // List, edit, and omission by an older client.
        $this->assertSame(['follow_cafe_policy', 'exclusive'], collect($this->getJson('/api/v1/discounts', $f['headers'])->json('data'))->whereIn('id', [$implicit, $exclusive])->pluck('combinationBehavior')->all());
        $detail = $this->getJson("/api/v1/discounts/$exclusive", $f['headers'])->json('data');
        unset($detail['productVariantSelections']);
        $older = $detail;
        unset($older['combinationBehavior']);
        $older['name'] = 'Edited by an older client';
        $this->putJson("/api/v1/discounts/$exclusive", $older, $f['headers'])->assertOk()->assertJsonPath('data.combinationBehavior', 'exclusive');
        $detail['combinationBehavior'] = 'follow_cafe_policy';
        $this->putJson("/api/v1/discounts/$exclusive", $detail, $f['headers'])->assertOk()->assertJsonPath('data.combinationBehavior', 'follow_cafe_policy');
        $detail['combinationBehavior'] = 'nonsense';
        $this->putJson("/api/v1/discounts/$exclusive", $detail, $f['headers'])->assertUnprocessable();
        $this->assertSame('follow_cafe_policy', DB::table('discounts')->where('id', $exclusive)->value('combination_behavior'));
    }

    public function test_legacy_discount_rows_load_safely_and_the_database_rejects_unknown_behavior(): void
    {
        $f = $this->fixture();
        // A row written without the column (as every pre-V3 row was) takes the safe default.
        $legacy = $this->codePolicy($f, 'OLD-CODE-1');
        $this->assertSame('follow_cafe_policy', DB::table('discounts')->where('id', $legacy)->value('combination_behavior'));
        $this->getJson("/api/v1/discounts/$legacy", $f['headers'])->assertOk()->assertJsonPath('data.combinationBehavior', 'follow_cafe_policy');
        $this->getJson('/api/v1/discounts/available?orderId='.$f['order'], $this->legacyHeaders($f))->assertOk();
        try {
            DB::transaction(fn () => DB::table('discounts')->where('id', $legacy)->update(['combination_behavior' => 'stack']));
            $this->fail('The database must reject an unknown combination behavior.');
        } catch (QueryException $exception) {
            $this->assertSame('23514', $exception->errorInfo[0]);
        }
    }

    public function test_phase_one_does_not_enable_multi_discount_runtime(): void
    {
        $f = $this->legacyRuntime();
        $first = $this->policy($f, ['applicationMode' => 'manual', 'value' => 10, 'combinationBehavior' => 'follow_cafe_policy']);
        $second = $this->policy($f, ['applicationMode' => 'manual', 'value' => 25, 'combinationBehavior' => 'follow_cafe_policy']);
        // Even a cafe policy that asks for stacking leaves today's runtime single-discount.
        $this->settings($f, ['allowMultipleDiscounts' => true, 'stackingMode' => 'same_item_allowed', 'allowMultipleCoupons' => true, 'allowCouponWithConfigured' => true, 'allowOrderAfterItemDiscounts' => true, 'maximumDiscountsPerOrder' => 5, 'conflictResolution' => 'priority']);
        $headers = $this->legacyHeaders($f);
        $this->postJson("/api/v1/orders/{$f['order']}/discounts/apply", ['discountId' => $first], $headers)->assertOk()->assertJsonPath('data.discount.amount', 2);
        $this->postJson("/api/v1/orders/{$f['order']}/discounts/apply", ['discountId' => $second], $headers)->assertOk()->assertJsonPath('data.discount.amount', 5);
        $this->assertSame([$second], DB::table('order_discounts')->where('order_id', $f['order'])->pluck('discount_id')->map(fn ($id) => (int) $id)->all());
        $this->assertSame('5.00', DB::table('orders')->where('id', $f['order'])->value('discount_total'));
        $this->assertFalse($this->getJson('/api/v1/cafe-configuration/discount-settings', $f['headers'])->json('data.automaticEnabled'));
    }
}
