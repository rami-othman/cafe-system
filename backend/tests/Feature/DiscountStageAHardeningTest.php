<?php

namespace Tests\Feature;

use App\Domain\Discount\DiscountAccess;
use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Services\OperationalAuditService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Discount hardening Stage A: Employee boundary, coupon secrecy, guessing protection and audit. */
class DiscountStageAHardeningTest extends TestCase
{
    use RefreshDatabase;

    private const CONTRACT = ['X-Discount-Contract' => '2'];

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
    }

    public function test_stale_employee_admin_grants_are_inert_while_pos_use_still_works(): void
    {
        $s = $this->scope();
        $employee = $this->headers($s['tenant'], $s['employee']);
        foreach (DiscountAccess::ADMINISTRATIVE as $permission) {
            DB::table('discount_role_permissions')->insert(['tenant_id' => $s['tenant'], 'role' => 'employee', 'permission' => $permission, 'created_at' => now(), 'updated_at' => now()]);
        }

        $this->getJson('/api/v1/discounts', $employee)->assertForbidden();
        $this->getJson("/api/v1/discounts/{$s['manual']}", $employee)->assertForbidden();
        $this->getJson('/api/v1/discounts/metrics', $employee)->assertForbidden();
        $this->postJson('/api/v1/discounts', $this->payload(), $employee)->assertForbidden();
        $this->putJson("/api/v1/discounts/{$s['manual']}", $this->payload(), $employee)->assertForbidden();
        $this->patchJson("/api/v1/discounts/{$s['manual']}/status", ['isActive' => false], $employee)->assertForbidden();
        $this->deleteJson("/api/v1/discounts/{$s['manual']}", [], $employee)->assertForbidden();
        $this->postJson('/api/v1/discounts/generate-code', [], $employee)->assertForbidden();
        $this->getJson('/api/v1/discounts/references/products', $employee)->assertForbidden();
        $this->getJson('/api/v1/discounts/role-permissions/employee', $employee)->assertForbidden();
        $this->putJson('/api/v1/discounts/role-permissions/employee', ['permissions' => [DiscountAccess::MANAGE]], $employee)->assertForbidden();
        $this->getJson('/api/v1/cafe-configuration/discount-settings', $employee)->assertForbidden();
        $this->putJson('/api/v1/cafe-configuration/discount-settings', [], $employee)->assertForbidden();

        $available = $this->getJson("/api/v1/discounts/available?orderId={$s['order']}", $employee)->assertOk();
        $this->assertSame([$s['manual']], collect($available->json('data'))->pluck('id')->all());
        $this->postJson("/api/v1/orders/{$s['order']}/discounts/preview", ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $s['manual']]], $employee + self::CONTRACT)->assertOk();
        $this->postJson("/api/v1/orders/{$s['order']}/discounts/preview", ['action' => 'apply', 'intent' => ['source' => 'code', 'code' => 'SECRT']], $employee + self::CONTRACT)->assertOk();
        $this->postJson("/api/v1/orders/{$s['order']}/discounts/apply", ['code' => 'secrt'], $employee)->assertOk();
    }

    public function test_employee_cannot_suppress_automatic_promotions(): void
    {
        $s = $this->scope();
        $this->assertFalse(app(DiscountAccess::class)->allows($this->requestFor($s['employee']), DiscountAccess::SUPPRESS_AUTOMATIC));
        $this->assertFalse(app(DiscountAccess::class)->allows($this->requestFor($s['employee']), DiscountAccess::SETTINGS_MANAGE));
    }

    public function test_compatibility_migration_removes_only_default_employee_admin_grants_and_is_idempotent(): void
    {
        $s = $this->scope();
        $other = $this->scope();
        foreach (DiscountAccess::ADMINISTRATIVE as $permission) {
            foreach ([$s['tenant'], $other['tenant']] as $tenant) {
                DB::table('discount_role_permissions')->insert(['tenant_id' => $tenant, 'role' => 'employee', 'permission' => $permission, 'created_at' => now(), 'updated_at' => now()]);
            }
        }
        $managerBefore = DB::table('discount_role_permissions')->where('role', 'manager')->orderBy('id')->pluck('permission', 'id')->all();
        $migration = require database_path('migrations/2026_10_15_000001_revoke_employee_discount_management_grants.php');

        $migration->up();
        $migration->up();

        $this->assertSame(0, DB::table('discount_role_permissions')->where('role', 'employee')->whereIn('permission', DiscountAccess::ADMINISTRATIVE)->count());
        $this->assertEqualsCanonicalizing(DiscountAccess::EMPLOYEE_ASSIGNABLE, DB::table('discount_role_permissions')->where('tenant_id', $s['tenant'])->where('role', 'employee')->pluck('permission')->all());
        $this->assertSame($managerBefore, DB::table('discount_role_permissions')->where('role', 'manager')->orderBy('id')->pluck('permission', 'id')->all());
    }

    public function test_provisioning_never_grants_new_employee_roles_administrative_access(): void
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Fresh', 'slug' => 'fresh-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        app(DefaultTenantRoleService::class)->ensureForTenant($tenant);

        $this->assertEqualsCanonicalizing(DiscountAccess::EMPLOYEE_ASSIGNABLE, DB::table('discount_role_permissions')->where('tenant_id', $tenant)->where('role', 'employee')->pluck('permission')->all());
    }

    public function test_owner_cannot_grant_employee_administrative_discount_permissions(): void
    {
        $s = $this->scope();
        $owner = $this->headers($s['tenant'], $s['owner']);
        foreach ([DiscountAccess::VIEW, DiscountAccess::MANAGE, DiscountAccess::SETTINGS_MANAGE] as $permission) {
            $this->putJson('/api/v1/discounts/role-permissions/employee', ['permissions' => [$permission]], $owner)->assertUnprocessable();
        }
        $this->putJson('/api/v1/discounts/role-permissions/manager', ['permissions' => [DiscountAccess::VIEW, DiscountAccess::MANAGE]], $owner)->assertOk();
    }

    public function test_coupon_codes_are_visible_only_to_actors_who_manage_policies(): void
    {
        $s = $this->scope();
        $manager = $this->manager($s['tenant'], [DiscountAccess::VIEW, DiscountAccess::MANAGE]);

        foreach ([$s['owner'], $manager] as $actor) {
            $h = $this->headers($s['tenant'], $actor);
            $this->assertSame('SECRT', collect($this->getJson('/api/v1/discounts', $h)->assertOk()->json('data'))->firstWhere('id', $s['coupon'])['code']);
            $this->getJson("/api/v1/discounts/{$s['coupon']}", $h)->assertOk()->assertJsonPath('data.code', 'SECRT');
        }
        $this->assertCount(1, $this->getJson('/api/v1/discounts?search=secrt', $this->headers($s['tenant'], $manager))->json('data'));
        // Same manager, MANAGE revoked by the Owner: still sees policies, no longer the secret.
        DB::table('discount_role_permissions')->where('tenant_id', $s['tenant'])->where('role', 'manager')->where('permission', DiscountAccess::MANAGE)->delete();
        $h = $this->headers($s['tenant'], $manager);
        $list = $this->getJson('/api/v1/discounts', $h)->assertOk();
        $row = collect($list->json('data'))->firstWhere('id', $s['coupon']);
        $this->assertNull($row['code']);
        $this->assertTrue($row['hasCode']);
        $this->assertStringNotContainsString('SECRT', $list->getContent());
        $this->assertStringNotContainsString('SECRT', $this->getJson("/api/v1/discounts/{$s['coupon']}", $h)->assertOk()->getContent());
        // A masked actor cannot probe codes through search.
        $this->assertSame([], $this->getJson('/api/v1/discounts?search=secrt', $h)->assertOk()->json('data'));
    }

    public function test_pos_responses_never_disclose_any_coupon_code(): void
    {
        $s = $this->scope();
        foreach ([$s['employee'], $s['owner']] as $actor) {
            $h = $this->headers($s['tenant'], $actor);
            $this->assertStringNotContainsString('SECRT', $this->getJson("/api/v1/discounts/available?orderId={$s['order']}", $h)->assertOk()->getContent());
            $preview = $this->postJson("/api/v1/orders/{$s['order']}/discounts/preview", ['action' => 'apply', 'intent' => ['source' => 'code', 'code' => 'secrt']], $h + self::CONTRACT)->assertOk();
            $this->assertStringNotContainsString('SECRT', strtoupper($preview->getContent()));
            $this->assertStringNotContainsString('SECRT', strtoupper($this->getJson("/api/v1/orders/{$s['order']}/discount-state", $h + self::CONTRACT)->getContent()));
        }
    }

    public function test_repeated_wrong_codes_are_throttled_per_user_without_blocking_others_or_configured_discounts(): void
    {
        $s = $this->scope();
        $other = $this->scope();
        $second = $this->cashier($s['tenant']);
        $limit = (int) config('discount_engine.coupon_attempts.per_user');
        $h = $this->headers($s['tenant'], $s['employee']) + self::CONTRACT;

        for ($i = 0; $i < $limit; $i++) {
            $this->preview($s['order'], 'WRNG'.$i, $h)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_NOT_FOUND');
        }
        $blocked = $this->preview($s['order'], 'WRNG9', $h)->assertStatus(429)->assertJsonPath('code', 'COUPON_ATTEMPTS_THROTTLED');
        $this->assertGreaterThan(0, (int) $blocked->headers->get('Retry-After'));
        $this->assertGreaterThan(0, $blocked->json('retryAfterSeconds'));
        // Even the correct code waits out the lockout: guessing cannot be confirmed while throttled.
        $this->preview($s['order'], 'SECRT', $h)->assertStatus(429);
        $this->postJson("/api/v1/orders/{$s['order']}/discounts/apply", ['code' => 'SECRT'], $this->headers($s['tenant'], $s['employee']))->assertStatus(429);

        // The same cashier keeps working with configured discounts and cart reads.
        $this->postJson("/api/v1/orders/{$s['order']}/discounts/preview", ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $s['manual']]], $h)->assertOk();
        $this->getJson("/api/v1/discounts/available?orderId={$s['order']}", $h)->assertOk();
        $this->getJson("/api/v1/orders/{$s['order']}/discount-state", $h)->assertOk();
        // Another cashier (different user, same tenant and IP) and another tenant are unaffected.
        $this->preview($s['order'], 'SECRT', $this->headers($s['tenant'], $second) + self::CONTRACT)->assertOk();
        $this->preview($other['order'], 'SECRT', $this->headers($other['tenant'], $other['employee']) + self::CONTRACT)->assertOk();
        // Attempts never consume usage.
        $this->assertSame(0, (int) DB::table('discounts')->where('id', $s['coupon'])->value('used_count'));
        $this->assertSame(0, DB::table('discount_usages')->where('tenant_id', $s['tenant'])->count());
    }

    public function test_many_users_behind_one_address_hit_the_tenant_ip_ceiling(): void
    {
        $s = $this->scope();
        config(['discount_engine.coupon_attempts.per_user' => 100, 'discount_engine.coupon_attempts.per_ip' => 6]);
        $users = [$this->cashier($s['tenant']), $this->cashier($s['tenant']), $this->cashier($s['tenant'])];
        for ($i = 0; $i < 6; $i++) {
            $this->preview($s['order'], 'BAD'.$i, $this->headers($s['tenant'], $users[$i % 3]) + self::CONTRACT)->assertUnprocessable();
        }

        $this->preview($s['order'], 'BAD7', $this->headers($s['tenant'], $users[0]) + self::CONTRACT)->assertStatus(429);
    }

    public function test_valid_redemption_and_successful_attempts_do_not_spend_the_budget(): void
    {
        $s = $this->scope();
        $h = $this->headers($s['tenant'], $s['employee']) + self::CONTRACT;
        for ($i = 0; $i < (int) config('discount_engine.coupon_attempts.per_user') + 5; $i++) {
            $this->preview($s['order'], 'SECRT', $h)->assertOk();
        }
        $this->preview($s['order'], 'WRONG', $h)->assertUnprocessable();
    }

    public function test_unknown_expired_inactive_and_out_of_branch_codes_are_indistinguishable(): void
    {
        $s = $this->scope();
        $h = $this->headers($s['tenant'], $s['employee']) + self::CONTRACT;
        $expired = $this->coupon($s['tenant'], 'EXPRD', ['end_date' => now()->subDay()->toDateString()]);
        $future = $this->coupon($s['tenant'], 'FUTUR', ['start_date' => now()->addDays(3)->toDateString()]);
        $inactive = $this->coupon($s['tenant'], 'INACT', ['is_active' => false]);
        $exhausted = $this->coupon($s['tenant'], 'EXHST', ['usage_limit' => 1]);
        DB::table('discount_usages')->insert(['tenant_id' => $s['tenant'], 'discount_id' => $exhausted, 'order_id' => $s['order'], 'business_date' => now()->toDateString(), 'created_at' => now(), 'updated_at' => now()]);
        $wrongBranch = $this->coupon($s['tenant'], 'OTHRB', []);
        DB::table('discount_targets')->insert(['tenant_id' => $s['tenant'], 'discount_id' => $wrongBranch, 'target_type' => 'branch', 'target_id' => $s['otherBranch'], 'created_at' => now(), 'updated_at' => now()]);

        $responses = [];
        foreach (['NOPE1', 'EXPRD', 'FUTUR', 'INACT', 'EXHST', 'OTHRB'] as $code) {
            $responses[$code] = $this->preview($s['order'], $code, $h)->assertUnprocessable()->json();
        }
        $this->assertCount(1, array_unique(array_map('json_encode', $responses)), 'Concealed availability must match an unknown code exactly.');
        $this->assertSame('DISCOUNT_NOT_FOUND', $responses['NOPE1']['code']);
        // The legacy endpoint answers all of them with the same 404.
        foreach (['NOPE1', 'EXPRD', 'INACT'] as $code) {
            $this->postJson("/api/v1/orders/{$s['order']}/discounts/apply", ['code' => $code], $this->headers($s['tenant'], $s['owner']))->assertNotFound()->assertJsonPath('message', 'Discount not found.');
        }
        unset($future, $expired, $inactive);
    }

    public function test_discount_crud_and_permission_changes_are_audited_without_coupon_secrets(): void
    {
        $s = $this->scope();
        $h = $this->headers($s['tenant'], $s['owner']);
        $branch = $s['branch'];

        $id = (int) $this->postJson('/api/v1/discounts', $this->payload(['name' => 'Audited', 'applicationMode' => 'code', 'code' => 'AUDT1', 'value' => 15]), $h)->assertCreated()->json('data.id');
        $this->patchJson("/api/v1/discounts/{$id}", $this->payload(['name' => 'Audited', 'applicationMode' => 'code', 'code' => 'AUDT2', 'value' => 20, 'appliesToAllBranches' => false, 'branchIds' => [$branch]]), $h)->assertOk();
        $this->patchJson("/api/v1/discounts/{$id}/status", ['isActive' => false], $h)->assertOk();
        $this->patchJson("/api/v1/discounts/{$id}/status", ['isActive' => false], $h)->assertOk();
        $this->patchJson("/api/v1/discounts/{$id}/status", ['isActive' => true], $h)->assertOk();
        $this->deleteJson("/api/v1/discounts/{$id}", [], $h)->assertNoContent();
        $this->putJson('/api/v1/discounts/role-permissions/manager', ['permissions' => [DiscountAccess::VIEW]], $h)->assertOk();

        $log = fn (string $action) => DB::table('activity_logs')->where('tenant_id', $s['tenant'])->where('action', $action)->orderBy('id')->get();
        $this->assertCount(1, $log('discount.created'));
        $this->assertCount(1, $log('discount.updated'));
        $this->assertCount(1, $log('discount.deactivated'), 'A no-op status write is not a change.');
        $this->assertCount(1, $log('discount.activated'));
        $this->assertCount(1, $log('discount.archived'));
        $this->assertCount(1, $log('discount.role_permissions.replaced'));

        $updated = $log('discount.updated')->first();
        $this->assertSame($s['owner']->id, (int) $updated->user_id);
        $this->assertSame($s['tenant'], (int) $updated->tenant_id);
        $this->assertSame($id, (int) $updated->entity_id);
        $before = json_decode($updated->before_state, true);
        $after = json_decode($updated->after_state, true);
        $this->assertEquals(15, $before['value']);
        $this->assertEquals(20, $after['value']);
        $this->assertTrue($after['codeChanged']);
        $this->assertContains('value', $after['changedFields']);
        $this->assertContains('branchIds', $after['changedFields']);
        $this->assertSame([$branch], $after['branchIds']);
        $this->assertNotNull($updated->created_at);

        $role = json_decode($log('discount.role_permissions.replaced')->first()->after_state, true);
        $this->assertSame(['discounts.view'], $role['permissions']);
        $this->assertContains('discounts.manage', $role['removed']);

        $dump = DB::table('activity_logs')->where('tenant_id', $s['tenant'])->get()->map(fn ($r) => $r->before_state.$r->after_state)->implode('');
        foreach (['AUDT1', 'AUDT2'] as $secret) {
            $this->assertStringNotContainsStringIgnoringCase($secret, $dump);
        }
    }

    public function test_legacy_pos_apply_and_remove_are_audited_without_the_typed_code(): void
    {
        $s = $this->scope();
        $h = $this->headers($s['tenant'], $s['employee']);
        $this->postJson("/api/v1/orders/{$s['order']}/discounts/apply", ['code' => 'secrt'], $h)->assertOk();
        $this->deleteJson("/api/v1/orders/{$s['order']}/discounts", [], $h)->assertOk();
        $this->postJson("/api/v1/orders/{$s['order']}/discounts/apply", ['discountId' => $s['manual']], $h)->assertOk();
        $this->deleteJson("/api/v1/orders/{$s['order']}/discount", [], $h)->assertOk();

        $rows = DB::table('activity_logs')->where('tenant_id', $s['tenant'])->where('action', 'like', 'discount.legacy.%')->orderBy('id')->get();
        $this->assertSame(['discount.legacy.applied', 'discount.legacy.removed', 'discount.legacy.applied', 'discount.legacy.removed'], $rows->pluck('action')->all());
        foreach ($rows as $row) {
            $this->assertSame($s['employee']->id, (int) $row->user_id);
            $this->assertSame($s['branch'], (int) $row->branch_id);
            $this->assertSame($s['order'], (int) $row->entity_id);
            $this->assertStringNotContainsStringIgnoringCase('SECRT', $row->before_state.$row->after_state);
        }
        $this->assertSame($s['coupon'], json_decode($rows[0]->after_state, true)['discountId']);
    }

    public function test_audit_service_redacts_secrets_at_any_depth_and_coupons_only_on_discount_entities(): void
    {
        $s = $this->scope();
        $audit = app(OperationalAuditService::class);
        $request = Request::create('/');
        $audit->record($request, $s['tenant'], 'discount.engine.apply', 'order', 1, [], ['intent' => ['source' => 'code', 'code' => 'RAWCD'], 'intents' => [['code' => 'RAWC2']], 'coupon' => 'RAWC3', 'password' => 'hunter2', 'nested' => ['access_token' => 'tok-abc', 'ok' => 'visible']]);
        $audit->record($request, $s['tenant'], 'sales.invoice.created', 'sales_invoice', 2, [], ['code' => 'INV-KEEP', 'token' => 'tok-def']);

        $discount = DB::table('activity_logs')->where('action', 'discount.engine.apply')->first()->after_state;
        foreach (['RAWCD', 'RAWC2', 'RAWC3', 'hunter2', 'tok-abc'] as $secret) {
            $this->assertStringNotContainsString($secret, $discount);
        }
        $this->assertStringContainsString('visible', $discount);
        $other = DB::table('activity_logs')->where('action', 'sales.invoice.created')->first()->after_state;
        $this->assertStringContainsString('INV-KEEP', $other, 'Non-discount `code` fields stay auditable.');
        $this->assertStringNotContainsString('tok-def', $other);
    }

    public function test_existing_settings_and_suppression_audit_events_are_not_duplicated(): void
    {
        $s = $this->scope();
        $this->putJson('/api/v1/discounts/role-permissions/manager', ['permissions' => DiscountAccess::ALL_PERMISSIONS], $this->headers($s['tenant'], $s['owner']))->assertOk();
        $this->assertSame(0, DB::table('activity_logs')->where('tenant_id', $s['tenant'])->where('action', 'discount.settings.updated')->count());
        $this->assertSame(1, DB::table('activity_logs')->where('tenant_id', $s['tenant'])->where('action', 'discount.role_permissions.replaced')->count());
    }

    // --- helpers -----------------------------------------------------------

    private function preview(int $order, string $code, array $headers)
    {
        return $this->postJson("/api/v1/orders/{$order}/discounts/preview", ['action' => 'apply', 'intent' => ['source' => 'code', 'code' => $code]], $headers);
    }

    private function requestFor(User $user): Request
    {
        $request = Request::create('/');
        $request->attributes->set('auth_user', $user);
        $request->attributes->set('tenant_id', $user->tenant_id);

        return $request;
    }

    private function scope(): array
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Stage A', 'slug' => 'stage-a-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'A', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $otherBranch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'B', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
        $owner = User::query()->create(['tenant_id' => $tenant, 'tenant_role_id' => $roles['owner']->id, 'name' => 'Owner', 'email' => 'o-'.uniqid().'@example.test', 'password' => 'test-password', 'role' => 'owner', 'is_active' => true]);
        $employee = $this->cashier($tenant, $branch);
        $category = (int) DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Cat', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $product = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'P', 'price' => 100, 'cost_price' => 1, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $order = (int) DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'order_number' => 'SA-'.uniqid(), 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 100, 'total' => 100, 'tax_rate' => 0, 'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('order_items')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'product_name' => 'P', 'quantity' => 1, 'unit_price' => 100, 'total' => 100, 'created_at' => $now, 'updated_at' => $now]);
        $manual = $this->policy($tenant, 'Configured', 'manual', null, []);
        $coupon = $this->coupon($tenant, 'SECRT', []);

        return compact('tenant', 'branch', 'otherBranch', 'owner', 'employee', 'order', 'manual', 'coupon');
    }

    private function cashier(int $tenant, ?int $branch = null): User
    {
        $role = DB::table('tenant_roles')->where('tenant_id', $tenant)->where('code', 'employee')->value('id');
        $user = User::query()->create(['tenant_id' => $tenant, 'tenant_role_id' => $role, 'name' => 'Cashier', 'email' => 'c-'.uniqid().'@example.test', 'password' => 'test-password', 'role' => 'cashier', 'is_active' => true]);
        $branch ??= (int) DB::table('branches')->where('tenant_id', $tenant)->orderBy('id')->value('id');
        DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $user->id, 'branch_id' => $branch, 'created_at' => now(), 'updated_at' => now()]);

        return $user;
    }

    private function manager(int $tenant, array $permissions): User
    {
        $role = DB::table('tenant_roles')->where('tenant_id', $tenant)->where('code', 'manager')->value('id');
        DB::table('discount_role_permissions')->where('tenant_id', $tenant)->where('role', 'manager')->delete();
        foreach ($permissions as $permission) {
            DB::table('discount_role_permissions')->insert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => $permission, 'created_at' => now(), 'updated_at' => now()]);
        }

        return User::query()->create(['tenant_id' => $tenant, 'tenant_role_id' => $role, 'name' => 'Manager', 'email' => 'm-'.uniqid().'@example.test', 'password' => 'test-password', 'role' => 'manager', 'is_active' => true]);
    }

    private function policy(int $tenant, string $name, string $mode, ?string $code, array $extra): int
    {
        return (int) DB::table('discounts')->insertGetId($extra + ['tenant_id' => $tenant, 'name' => $name, 'code' => $code, 'application_mode' => $mode, 'type' => 'percentage', 'scope' => 'order', 'value' => 10, 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function coupon(int $tenant, string $code, array $extra): int
    {
        return $this->policy($tenant, 'Coupon policy', 'code', $code, $extra);
    }

    private function payload(array $overrides = []): array
    {
        return $overrides + ['name' => 'Policy', 'applicationMode' => 'manual', 'type' => 'percentage', 'scope' => 'order', 'value' => 10, 'isActive' => true, 'appliesToAllBranches' => true];
    }

    private function headers(int $tenant, User $user): array
    {
        return ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $user)];
    }
}
