<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Services\DiscountSettingsService;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Discount System V3 Phase 1: Cafe Discount Policy contract on the settings API. */
class DiscountV3PolicySettingsTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/cafe-configuration/discount-settings';

    private const V3_DEFAULTS = [
        'allowMultipleDiscounts' => false,
        'stackingMode' => 'different_items_only',
        'allowMultipleCoupons' => false,
        'allowCouponWithConfigured' => false,
        'allowOrderAfterItemDiscounts' => false,
        'maximumDiscountsPerOrder' => 1,
        'conflictResolution' => 'best_saving',
    ];

    private function scope(string $role = 'owner'): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Policy', 'slug' => uniqid('policy-')]);
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
        $user = User::query()->create(['tenant_id' => $tenant, 'tenant_role_id' => $roles[$role]->id, 'role' => $role === 'employee' ? 'cashier' : $role, 'name' => 'Actor', 'email' => uniqid().'@example.test', 'password' => 'testing-password', 'is_active' => true, 'must_change_password' => false]);

        return [$tenant, ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $user)]];
    }

    /** The exact request an existing (pre-V3) client sends: legacy fields only. */
    private function legacyPayload(int $version = 0, array $changes = []): array
    {
        return array_replace(DiscountSettingsService::LEGACY_DEFAULTS, ['expectedVersion' => $version], $changes);
    }

    private function fullPayload(int $version = 0, array $changes = []): array
    {
        return array_replace(DiscountSettingsService::DEFAULTS, ['expectedVersion' => $version], $changes);
    }

    public function test_defaults_preserve_the_current_single_discount_behavior(): void
    {
        [, $headers] = $this->scope();
        $data = $this->getJson(self::URL, $headers)->assertOk()->json('data');
        foreach (self::V3_DEFAULTS as $field => $value) {
            $this->assertSame($value, $data[$field], $field);
        }
        // Legacy fields stay alongside the V3 fields for the current client.
        $this->assertSame('single', $data['combinationMode']);
        $this->assertFalse($data['automaticEnabled']);
        $this->assertNull($data['maximumTotalDiscountPercent']);
        $this->assertFalse($data['engineReady']);
        $this->assertDatabaseCount('tenant_discount_settings', 0);
    }

    public function test_owner_and_manager_round_trip_all_policy_fields_and_the_shared_total_limit(): void
    {
        foreach (['owner', 'manager'] as $role) {
            [$tenant, $headers] = $this->scope($role);
            $changes = ['allowMultipleDiscounts' => true, 'stackingMode' => 'same_item_allowed', 'allowMultipleCoupons' => true, 'allowCouponWithConfigured' => true, 'allowOrderAfterItemDiscounts' => true, 'maximumDiscountsPerOrder' => 4, 'conflictResolution' => 'priority', 'maximumTotalDiscountPercent' => 35.5];
            $saved = $this->putJson(self::URL, $this->fullPayload(0, $changes), $headers)->assertOk()->assertJsonPath('data.version', 1)->json('data');
            foreach ($changes as $field => $value) {
                $this->assertSame($value, $saved[$field], "$role $field");
            }
            $this->getJson(self::URL, $headers)->assertOk()->assertExactJson(['data' => $saved]);
            $this->assertDatabaseHas('tenant_discount_settings', ['tenant_id' => $tenant, 'allow_multiple_discounts' => true, 'stacking_mode' => 'same_item_allowed', 'maximum_discounts_per_order' => 4, 'conflict_resolution' => 'priority', 'maximum_total_discount_percent' => '35.5000']);
            $audit = DB::table('activity_logs')->where('action', 'discount.settings.updated')->where('tenant_id', $tenant)->first();
            $this->assertSame(self::V3_DEFAULTS['stackingMode'], json_decode($audit->before_state, true)['stackingMode']);
            $this->assertSame('same_item_allowed', json_decode($audit->after_state, true)['stackingMode']);
        }
    }

    public function test_employee_cannot_read_or_write_the_policy(): void
    {
        [, $headers] = $this->scope('employee');
        $this->getJson(self::URL, $headers)->assertForbidden()->assertJsonPath('code', 'DISCOUNT_SETTINGS_FORBIDDEN');
        $this->putJson(self::URL, $this->fullPayload(0, ['allowMultipleDiscounts' => true]), $headers)->assertForbidden();
        $this->assertDatabaseCount('tenant_discount_settings', 0);
    }

    public function test_invalid_policy_values_are_rejected_without_side_effects(): void
    {
        [, $headers] = $this->scope();
        $invalid = [
            ['stackingMode' => 'overlap'], ['stackingMode' => ''], ['stackingMode' => null],
            ['conflictResolution' => 'lowest_saving'], ['conflictResolution' => 'random'], ['conflictResolution' => null],
            ['maximumDiscountsPerOrder' => 0], ['maximumDiscountsPerOrder' => -1], ['maximumDiscountsPerOrder' => 11], ['maximumDiscountsPerOrder' => '3'], ['maximumDiscountsPerOrder' => 2.5], ['maximumDiscountsPerOrder' => null],
            ['allowMultipleDiscounts' => 1], ['allowMultipleCoupons' => 'true'], ['allowCouponWithConfigured' => null], ['allowOrderAfterItemDiscounts' => 'yes'],
            ['maximumTotalDiscountPercent' => 0], ['maximumTotalDiscountPercent' => 100.5],
        ];
        foreach ($invalid as $changes) {
            $this->putJson(self::URL, $this->fullPayload(0, $changes), $headers)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_SETTINGS_VALIDATION_FAILED');
        }
        $this->assertDatabaseCount('tenant_discount_settings', 0);
        // The documented boundaries are valid.
        foreach ([1, 10] as $count) {
            $this->putJson(self::URL, $this->fullPayload($count === 1 ? 0 : 1, ['maximumDiscountsPerOrder' => $count]), $headers)->assertOk()->assertJsonPath('data.maximumDiscountsPerOrder', $count);
        }
    }

    public function test_legacy_client_payload_still_saves_and_never_resets_saved_policy_or_total_limit(): void
    {
        [, $headers] = $this->scope();
        $this->putJson(self::URL, $this->legacyPayload(0), $headers)->assertOk()->assertJsonPath('data.version', 1);
        $this->getJson(self::URL, $headers)->assertOk()->assertJsonPath('data.stackingMode', 'different_items_only')->assertJsonPath('data.maximumDiscountsPerOrder', 1);
        $this->putJson(self::URL, $this->fullPayload(1, ['allowMultipleDiscounts' => true, 'stackingMode' => 'same_item_allowed', 'maximumDiscountsPerOrder' => 3, 'conflictResolution' => 'priority', 'maximumTotalDiscountPercent' => 40]), $headers)->assertOk();
        // An older client re-saving only legacy fields must keep every V3 value.
        $kept = $this->putJson(self::URL, $this->legacyPayload(2, ['maximumTotalDiscountPercent' => 25, 'selectionStrategy' => 'priority']), $headers)->assertOk()->json('data');
        $this->assertTrue($kept['allowMultipleDiscounts']);
        $this->assertSame('same_item_allowed', $kept['stackingMode']);
        $this->assertSame(3, $kept['maximumDiscountsPerOrder']);
        $this->assertSame('priority', $kept['conflictResolution']);
        $this->assertEquals(25, $kept['maximumTotalDiscountPercent']);
        $this->assertSame('priority', $kept['selectionStrategy']);
    }

    public function test_existing_tenant_row_created_before_v3_reads_safe_defaults_and_keeps_its_total_limit(): void
    {
        [$tenant, $headers] = $this->scope();
        // A row exactly as the pre-V3 schema stored it: V3 columns take defaults.
        DB::table('tenant_discount_settings')->insert(['tenant_id' => $tenant, 'automatic_enabled' => false, 'selection_strategy' => 'priority', 'combination_mode' => 'single', 'order_discount_behavior' => 'exclusive', 'coupon_behavior' => 'exclusive', 'manual_behavior' => 'exclusive', 'maximum_total_discount_percent' => '12.5000', 'allow_automatic_suppression' => true, 'version' => 7, 'updated_by' => DB::table('users')->where('tenant_id', $tenant)->value('id')]);
        $data = $this->getJson(self::URL, $headers)->assertOk()->json('data');
        $this->assertSame(7, $data['version']);
        $this->assertEquals(12.5, $data['maximumTotalDiscountPercent']);
        $this->assertSame('priority', $data['selectionStrategy']);
        foreach (self::V3_DEFAULTS as $field => $value) {
            $this->assertSame($value, $data[$field], $field);
        }
    }

    public function test_stale_version_conflict_and_foreign_tenant_isolation_still_apply_to_the_policy(): void
    {
        [$tenant, $headers] = $this->scope();
        [$other, $otherHeaders] = $this->scope();
        $this->putJson(self::URL, $this->fullPayload(0, ['allowMultipleDiscounts' => true]), $headers)->assertOk();
        $this->putJson(self::URL, $this->fullPayload(0, ['allowMultipleDiscounts' => false]), $headers)->assertStatus(409)->assertJsonPath('code', 'DISCOUNT_SETTINGS_VERSION_CONFLICT');
        $this->assertTrue((bool) DB::table('tenant_discount_settings')->where('tenant_id', $tenant)->value('allow_multiple_discounts'));
        $this->getJson(self::URL, $otherHeaders)->assertOk()->assertJsonPath('data.allowMultipleDiscounts', false)->assertJsonPath('data.version', 0);
        $this->assertDatabaseMissing('tenant_discount_settings', ['tenant_id' => $other]);
    }

    public function test_database_rejects_invalid_policy_values(): void
    {
        [$tenant] = $this->scope();
        $actor = DB::table('users')->where('tenant_id', $tenant)->value('id');
        $row = ['tenant_id' => $tenant, 'automatic_enabled' => false, 'selection_strategy' => 'highest_saving', 'combination_mode' => 'single', 'order_discount_behavior' => 'exclusive', 'coupon_behavior' => 'exclusive', 'manual_behavior' => 'exclusive', 'allow_automatic_suppression' => true, 'version' => 1, 'updated_by' => $actor];
        foreach ([['stacking_mode' => 'bad'], ['conflict_resolution' => 'lowest_saving'], ['maximum_discounts_per_order' => 0], ['maximum_discounts_per_order' => 11]] as $bad) {
            try {
                DB::transaction(fn () => DB::table('tenant_discount_settings')->insert($row + $bad));
                $this->fail('The database must reject '.json_encode($bad));
            } catch (QueryException $exception) {
                $this->assertSame('23514', $exception->errorInfo[0]);
            }
        }
    }
}
