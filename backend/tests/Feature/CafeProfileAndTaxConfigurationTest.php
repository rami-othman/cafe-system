<?php

namespace Tests\Feature;

use App\Models\Branch;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class CafeProfileAndTaxConfigurationTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_read_and_update_only_its_cafe_profile_without_changing_login_identity_or_slug(): void
    {
        [$tenant, , $owner] = $this->tenantBranchUser('profile-a', 'owner', [
            'email' => 'contact@before.test',
            'phone' => '+963 11 100 0000',
            'timezone' => 'UTC',
        ]);
        [, , $otherOwner] = $this->tenantBranchUser('profile-b', 'owner', ['email' => 'other@before.test']);
        $token = $this->authenticateTenantUser($tenant->id, $owner);
        $originalSlug = $tenant->slug;
        $ownerEmail = $owner->email;

        $this->withToken($token)->getJson('/api/v1/cafe-configuration/profile')
            ->assertOk()
            ->assertJsonPath('data.name', $tenant->name)
            ->assertJsonPath('data.email', 'contact@before.test')
            ->assertJsonPath('data.currency', 'SYP')
            ->assertJsonPath('data.status', 'active')
            ->assertJsonMissingPath('data.slug')
            ->assertJsonMissingPath('data.plan');

        $this->withToken($token)->putJson('/api/v1/cafe-configuration/profile', [
            'name' => '  Renamed Cafe  ',
            'email' => '  contact@after.test  ',
            'phone' => '  +963 11 200 0000  ',
            'timezone' => 'Asia/Damascus',
        ])->assertOk()
            ->assertJsonPath('data.name', 'Renamed Cafe')
            ->assertJsonPath('data.email', 'contact@after.test')
            ->assertJsonPath('data.phone', '+963 11 200 0000')
            ->assertJsonPath('data.timezone', 'Asia/Damascus');

        $this->assertDatabaseHas('tenants', [
            'id' => $tenant->id,
            'name' => 'Renamed Cafe',
            'email' => 'contact@after.test',
            'slug' => $originalSlug,
        ]);
        $this->assertDatabaseHas('users', ['id' => $owner->id, 'email' => $ownerEmail]);
        $this->assertDatabaseHas('tenants', ['id' => $otherOwner->tenant_id, 'email' => 'other@before.test']);
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.tenant.name', 'Renamed Cafe')
            ->assertJsonPath('data.user.email', $ownerEmail);
    }

    public function test_profile_validates_allowed_fields_and_rejects_every_sensitive_tenant_field(): void
    {
        [$tenant, , $owner] = $this->tenantBranchUser('profile-security', 'owner', [
            'email' => 'contact@security.test',
            'phone' => '123',
            'timezone' => 'UTC',
            'plan' => 'starter',
            'tax_rate' => '0.080000',
            'logo_url' => 'https://example.test/logo.png',
        ]);
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->putJson('/api/v1/cafe-configuration/profile', [
            'email' => 'not-an-email',
            'phone' => 'x',
            'timezone' => 'Not/AZone',
        ])->assertUnprocessable()->assertJsonValidationErrors(['name', 'email', 'timezone']);

        $sensitive = [
            'tenantId' => 999,
            'tenant_id' => 999,
            'ownerId' => 999,
            'slug' => 'takeover',
            'status' => 'suspended',
            'plan' => 'enterprise',
            'currency' => 'USD',
            'taxRate' => 1,
            'tax_rate' => 1,
            'logoUrl' => 'https://example.test/new.png',
            'logo_url' => 'https://example.test/new.png',
            'deletedAt' => now()->toIso8601String(),
            'deleted_at' => now()->toIso8601String(),
        ];
        $this->withToken($token)->putJson('/api/v1/cafe-configuration/profile', [
            'name' => 'Safe name',
            'email' => 'safe@profile.test',
            'phone' => '321',
            'timezone' => 'UTC',
            ...$sensitive,
        ])->assertUnprocessable()->assertJsonValidationErrors(array_keys($sensitive));

        $this->assertDatabaseHas('tenants', [
            'id' => $tenant->id,
            'slug' => $tenant->slug,
            'status' => 'active',
            'plan' => 'starter',
            'currency' => 'SYP',
            'tax_rate' => '0.080000',
            'logo_url' => 'https://example.test/logo.png',
        ]);
    }

    public function test_every_profile_and_tax_endpoint_is_owner_only_and_keeps_password_change_boundary(): void
    {
        [$tenant, , $owner] = $this->tenantBranchUser('authorization', 'owner');
        $manager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'cashier');
        $requests = [
            ['getJson', '/api/v1/cafe-configuration/profile', []],
            ['putJson', '/api/v1/cafe-configuration/profile', ['name' => 'Cafe authorization', 'timezone' => 'UTC']],
            ['getJson', '/api/v1/cafe-configuration/tax', []],
            ['putJson', '/api/v1/cafe-configuration/tax', ['taxRate' => 0.08]],
        ];

        foreach ([$manager, $employee] as $actor) {
            $token = $this->authenticateTenantUser($tenant->id, $actor);
            foreach ($requests as [$method, $uri, $payload]) {
                $this->withToken($token)->{$method}($uri, $payload)->assertForbidden();
            }
        }

        $ownerToken = $this->authenticateTenantUser($tenant->id, $owner);
        foreach ($requests as [$method, $uri, $payload]) {
            $this->withToken($ownerToken)->{$method}($uri, $payload)->assertOk();
        }

        $mustChange = $this->user($tenant, 'owner', mustChangePassword: true);
        $this->withToken($this->authenticateTenantUser($tenant->id, $mustChange))
            ->getJson('/api/v1/cafe-configuration/profile')
            ->assertForbidden()
            ->assertJsonPath('code', 'PASSWORD_CHANGE_REQUIRED');
    }

    public function test_owner_can_read_and_update_only_its_fractional_tax_rate_with_validation_and_branch_compatibility(): void
    {
        [$tenantA, $branchA, $ownerA] = $this->tenantBranchUser('tax-a', 'owner', ['tax_rate' => '0.080000']);
        [$tenantB, , $ownerB] = $this->tenantBranchUser('tax-b', 'owner', ['tax_rate' => '0.150000']);
        $token = $this->authenticateTenantUser($tenantA->id, $ownerA);

        $this->withToken($token)->getJson('/api/v1/cafe-configuration/tax')
            ->assertOk()->assertJsonPath('data.taxRate', 0.08);

        foreach ([['taxRate' => -0.000001], ['taxRate' => 1.000001], ['taxRate' => 8], ['taxRate' => 'bad'], ['taxRate' => '0.1234567'], []] as $payload) {
            $this->withToken($token)->putJson('/api/v1/cafe-configuration/tax', $payload)
                ->assertUnprocessable()->assertJsonValidationErrors('taxRate');
        }

        $this->withToken($token)->putJson('/api/v1/cafe-configuration/tax', ['taxRate' => 0])
            ->assertOk()->assertJsonPath('data.taxRate', 0);
        $this->withToken($token)->putJson('/api/v1/cafe-configuration/tax', ['taxRate' => 1])
            ->assertOk()->assertJsonPath('data.taxRate', 1);
        $this->withToken($token)->putJson('/api/v1/cafe-configuration/tax', ['taxRate' => 0.1])
            ->assertOk()->assertJsonPath('data.taxRate', 0.1);

        $this->withToken($token)->getJson('/api/v1/branches')
            ->assertOk()
            ->assertJsonPath('data.0.id', $branchA->id)
            ->assertJsonPath('data.0.taxRate', 0.1);
        $this->assertDatabaseHas('tenants', ['id' => $tenantA->id, 'tax_rate' => '0.100000']);
        $this->assertDatabaseHas('tenants', ['id' => $tenantB->id, 'tax_rate' => '0.150000']);
        $this->withToken($this->authenticateTenantUser($tenantB->id, $ownerB))
            ->getJson('/api/v1/cafe-configuration/tax')->assertJsonPath('data.taxRate', 0.15);
    }

    public function test_tax_change_preserves_existing_order_snapshot_and_new_orders_use_the_new_rate(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('tax-history', 'owner', ['tax_rate' => '0.080000']);
        $productId = $this->product($tenant);
        $token = $this->authenticateTenantUser($tenant->id, $owner);
        $payload = [
            'branchId' => $branch->id,
            'orderType' => 'takeaway',
            'items' => [['productId' => $productId, 'quantity' => 1]],
        ];

        $existing = $this->withToken($token)->postJson('/api/v1/orders', $payload)
            ->assertCreated()
            ->assertJsonPath('data.totals.taxRate', 0.08)
            ->assertJsonPath('data.totals.taxTotal', 0.8)
            ->assertJsonPath('data.totals.total', 10.8);
        $existingId = $existing->json('data.id');

        $this->withToken($token)->putJson('/api/v1/cafe-configuration/tax', ['taxRate' => 0.1])
            ->assertOk()->assertJsonPath('data.taxRate', 0.1);

        $this->assertDatabaseHas('orders', [
            'id' => $existingId,
            'tax_rate' => '0.080000',
            'tax_total' => 0.8,
            'total' => 10.8,
        ]);
        $this->withToken($token)->getJson("/api/v1/orders/{$existingId}")
            ->assertOk()
            ->assertJsonPath('data.totals.taxRate', 0.08)
            ->assertJsonPath('data.totals.taxTotal', 0.8)
            ->assertJsonPath('data.totals.total', 10.8);

        $this->withToken($token)->postJson('/api/v1/orders', $payload)
            ->assertCreated()
            ->assertJsonPath('data.totals.taxRate', 0.1)
            ->assertJsonPath('data.totals.taxTotal', 1)
            ->assertJsonPath('data.totals.total', 11);
    }

    /** @return array{Tenant, Branch, User} */
    private function tenantBranchUser(string $name, string $role, array $attributes = []): array
    {
        $tenant = Tenant::query()->create([
            'name' => 'Tenant '.$name,
            'slug' => 'tenant-'.strtolower($name).'-'.uniqid(),
            'status' => 'active',
            'currency' => 'SYP',
            ...$attributes,
        ]);
        $branch = Branch::query()->create([
            'tenant_id' => $tenant->id,
            'name' => 'Branch '.$name,
            'timezone' => 'UTC',
            'currency' => 'SYP',
            'is_active' => true,
        ]);

        return [$tenant, $branch, $this->user($tenant, $role)];
    }

    private function user(Tenant $tenant, string $role, bool $mustChangePassword = false): User
    {
        return User::query()->create([
            'tenant_id' => $tenant->id,
            'name' => ucfirst($role),
            'email' => uniqid($role, true).'@example.test',
            'username' => $role === 'cashier' ? 'cashier-'.uniqid() : null,
            'password' => Hash::make('password'),
            'role' => $role,
            'is_active' => true,
            'must_change_password' => $mustChangePassword,
        ]);
    }

    private function product(Tenant $tenant): int
    {
        $categoryId = DB::table('categories')->insertGetId([
            'tenant_id' => $tenant->id,
            'name' => 'Coffee',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return DB::table('products')->insertGetId([
            'tenant_id' => $tenant->id,
            'category_id' => $categoryId,
            'name' => 'Latte',
            'price' => 10,
            'cost_price' => 1,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
