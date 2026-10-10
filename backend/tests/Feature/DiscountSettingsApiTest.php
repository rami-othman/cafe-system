<?php

namespace Tests\Feature;

use App\Domain\Discount\DiscountAccess;
use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Services\DiscountSettingsService;
use App\Services\OperationalAuditService;
use Database\Seeders\SuperAdminSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class DiscountSettingsApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/cafe-configuration/discount-settings';

    private function scope(string $role = 'owner'): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Settings', 'slug' => uniqid('settings-')]);
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
        $user = User::query()->create(['tenant_id' => $tenant, 'tenant_role_id' => $roles[$role]->id, 'role' => $role === 'employee' ? 'cashier' : $role, 'name' => 'Actor', 'email' => uniqid().'@example.test', 'password' => 'testing-password', 'is_active' => true, 'must_change_password' => false]);

        return [$tenant, ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $user)], $user];
    }

    private function payload(int $version = 0, array $changes = []): array
    {
        return array_replace(DiscountSettingsService::DEFAULTS, ['expectedVersion' => $version], $changes);
    }

    public function test_defaults_are_read_only_and_round_trip_with_atomic_version_and_audit(): void
    {
        [$tenant, $headers, $actor] = $this->scope();
        $initial = DiscountSettingsService::DEFAULTS + ['version' => 0, 'engineReady' => true];
        $this->getJson(self::URL, $headers)->assertOk()->assertExactJson(['data' => $initial]);
        $this->assertDatabaseCount('tenant_discount_settings', 0);
        $this->assertSame(0, DB::table('activity_logs')->where('action', 'discount.settings.updated')->count());
        $payload = $this->payload(changes: ['selectionStrategy' => 'priority', 'combinationMode' => 'disjoint_items', 'orderDiscountBehavior' => 'after_items', 'couponBehavior' => 'follow_combination_rules', 'manualBehavior' => 'follow_combination_rules', 'maximumTotalDiscountPercent' => 12.3456, 'allowAutomaticSuppression' => false]);
        $saved = $this->putJson(self::URL, $payload, $headers)->assertOk()->assertJsonPath('data.version', 1)->assertJsonPath('data.engineReady', true)->json('data');
        $this->getJson(self::URL, $headers)->assertExactJson(['data' => $saved]);
        $this->assertDatabaseHas('tenant_discount_settings', ['tenant_id' => $tenant, 'version' => 1, 'updated_by' => $actor->id]);
        $audit = DB::table('activity_logs')->where('action', 'discount.settings.updated')->first();
        $this->assertSame($initial, json_decode($audit->before_state, true));
        $this->assertSame($saved, json_decode($audit->after_state, true));
        $this->assertSame($actor->id, (int) $audit->user_id);
        $this->putJson(self::URL, $this->payload(1), $headers)->assertOk()->assertJsonPath('data.version', 2);
        $this->assertSame(2, DB::table('activity_logs')->where('action', 'discount.settings.updated')->count());
    }

    public function test_manager_grant_revocation_and_unrelated_configuration_remain_owner_only(): void
    {
        [$tenant, $headers] = $this->scope('manager');
        $this->getJson(self::URL, $headers)->assertOk();
        $this->putJson(self::URL, $this->payload(), $headers)->assertOk();
        foreach (['profile', 'tax'] as $page) {
            $this->getJson('/api/v1/cafe-configuration/'.$page, $headers)->assertForbidden();
            $this->putJson('/api/v1/cafe-configuration/'.$page, [], $headers)->assertForbidden();
        }
        $this->putJson('/api/v1/discounts/role-permissions/manager', ['permissions' => DiscountAccess::CATALOG], $headers)->assertForbidden();
        $owner = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $this->putJson('/api/v1/discounts/role-permissions/manager', ['permissions' => DiscountAccess::CATALOG], $owner)->assertOk();
        app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
        $this->getJson(self::URL, $headers)->assertForbidden()->assertJsonPath('code', 'DISCOUNT_SETTINGS_FORBIDDEN');
        $this->putJson(self::URL, $this->payload(1), $headers)->assertForbidden();
        $this->putJson('/api/v1/discounts/role-permissions/employee', ['permissions' => [DiscountAccess::SETTINGS_MANAGE]], $owner)->assertUnprocessable();
        $this->putJson('/api/v1/discounts/role-permissions/manager', ['permissions' => DiscountAccess::ALL_PERMISSIONS], $owner)->assertOk();
        $this->getJson(self::URL, $headers)->assertOk();
    }

    public function test_employee_factory_and_foreign_tenant_cannot_access_another_tenants_settings(): void
    {
        [$tenant, $owner, $actor] = $this->scope();
        $this->putJson(self::URL, $this->payload(changes: ['selectionStrategy' => 'priority']), $owner)->assertOk();
        foreach (['employee', 'factory_manager'] as $role) {
            [, $headers] = $this->scope($role);
            $this->getJson(self::URL, $headers)->assertForbidden();
            $this->putJson(self::URL, $this->payload(), $headers)->assertForbidden();
        }
        [$other, $headers] = $this->scope();
        $headers['X-Tenant-Id'] = $tenant;
        $this->getJson(self::URL, $headers)->assertOk()->assertJsonPath('data.version', 0)->assertJsonPath('data.selectionStrategy', 'highest_saving');
        $this->putJson(self::URL, $this->payload(), $headers)->assertOk();
        $this->assertDatabaseHas('tenant_discount_settings', ['tenant_id' => $tenant, 'selection_strategy' => 'priority']);
        $this->assertDatabaseHas('tenant_discount_settings', ['tenant_id' => $other, 'selection_strategy' => 'highest_saving']);
        // A malformed cross-tenant role reference must not supply Owner or
        // Manager authority even with an otherwise valid own-tenant token.
        $foreignRole = DB::table('tenant_roles')->where('tenant_id', $other)->where('code', 'owner')->value('id');
        DB::table('users')->where('id', $actor->id)->update(['tenant_role_id' => $foreignRole]);
        $this->getJson(self::URL, $owner)->assertForbidden()->assertJsonPath('code', 'DISCOUNT_SETTINGS_FORBIDDEN');
        $this->putJson(self::URL, $this->payload(1), $owner)->assertForbidden();
        // Malformed foreign-tenant token identity is rejected at authentication.
        DB::table('api_tokens')->where('token_hash', hash('sha256', substr($headers['Authorization'], 7)))->update(['tenant_id' => $tenant]);
        $this->getJson(self::URL, $headers)->assertUnauthorized()->assertJsonPath('code', 'AUTH_SESSION_INVALID');
    }

    public function test_platform_and_unauthenticated_tokens_do_not_establish_tenant_settings_authority(): void
    {
        $this->seed(SuperAdminSeeder::class);
        $this->postJson('/api/super-admin/v1/auth/login', ['email' => 'admin@cafe618.local', 'password' => 'change-me-local-only'])->assertOk();
        // Real authenticated platform session cookies cannot authenticate the
        // tenant bearer route, including when supplied alongside a fake bearer.
        $this->getJson(self::URL, ['Authorization' => 'Bearer platform-only-token'])->assertUnauthorized();
        $this->putJson(self::URL, $this->payload(), ['Authorization' => ''])->assertUnauthorized()->assertJsonPath('code', 'AUTH_REQUIRED');
    }

    public function test_invalid_fields_and_combinations_have_no_side_effects(): void
    {
        [, $headers] = $this->scope();
        foreach ([['selectionStrategy' => 'random'], ['combinationMode' => 'stack'], ['orderDiscountBehavior' => 'after_items'], ['couponBehavior' => 'stack'], ['manualBehavior' => 'stack'], ['maximumTotalDiscountPercent' => 0], ['maximumTotalDiscountPercent' => 101], ['maximumTotalDiscountPercent' => 0.00001], ['automaticEnabled' => 0], ['allowAutomaticSuppression' => 'true'], ['expectedVersion' => '0'], ['expectedVersion' => -1], ['engineReady' => true], ['version' => 10], ['tenantId' => 999]] as $changes) {
            $this->putJson(self::URL, $this->payload(changes: $changes), $headers)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_SETTINGS_VALIDATION_FAILED');
        }
        $missing = $this->payload();
        unset($missing['expectedVersion']);
        $this->putJson(self::URL, $missing, $headers)->assertUnprocessable();
        // automaticEnabled=true is a valid opt-in since the Automatic rollout
        // (DiscountAutomaticPromotionsTest); only malformed values are rejected.
        $this->assertDatabaseCount('tenant_discount_settings', 0);
        $this->assertSame(0, DB::table('activity_logs')->where('action', 'discount.settings.updated')->count());
    }

    public function test_stale_save_preserves_settings_and_audit(): void
    {
        [, $headers] = $this->scope();
        $this->putJson(self::URL, $this->payload(1), $headers)->assertConflict();
        $this->assertDatabaseCount('tenant_discount_settings', 0);
        $saved = $this->putJson(self::URL, $this->payload(), $headers)->assertOk()->json('data');
        $this->putJson(self::URL, $this->payload(changes: ['selectionStrategy' => 'priority']), $headers)->assertConflict()->assertJsonPath('code', 'DISCOUNT_SETTINGS_VERSION_CONFLICT');
        $this->getJson(self::URL, $headers)->assertExactJson(['data' => $saved]);
        $this->assertSame(1, DB::table('activity_logs')->where('action', 'discount.settings.updated')->count());
    }

    public function test_audit_failure_rolls_back_first_insert_and_existing_update(): void
    {
        [, $headers] = $this->scope();
        $saved = $this->putJson(self::URL, $this->payload(), $headers)->assertOk()->json('data');
        [$newTenant, $newHeaders] = $this->scope();
        $audit = $this->mock(OperationalAuditService::class);
        $audit->shouldReceive('record')->twice()->andThrow(new \RuntimeException('Simulated audit failure'));
        // The route has cached its first controller instance; reset it to
        // resolve the injected failing audit service for both requests.
        foreach (Route::getRoutes() as $route) {
            $route->flushController();
        }
        $this->putJson(self::URL, $this->payload(), $newHeaders)->assertStatus(500);
        $this->assertDatabaseMissing('tenant_discount_settings', ['tenant_id' => $newTenant]);
        $this->putJson(self::URL, $this->payload(1, ['selectionStrategy' => 'priority']), $headers)->assertStatus(500);
        $this->getJson(self::URL, $headers)->assertExactJson(['data' => $saved]);
        $this->assertSame(1, DB::table('activity_logs')->where('action', 'discount.settings.updated')->count());
    }
}
