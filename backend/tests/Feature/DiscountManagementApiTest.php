<?php

namespace Tests\Feature;

use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DiscountManagementApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_tenant_can_manage_its_discounts_without_cross_tenant_access(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $productId = (int) DB::table('products')->where('tenant_id', $tenantId)->value('id');
        $headers = $this->headers($tenantId);

        $this->getJson('/api/v1/discounts', $headers)
            ->assertOk()->assertJsonCount(25, 'data')->assertJsonPath('data.0.status', 'active');

        $created = $this->postJson('/api/v1/discounts', $this->payload(['name' => 'Targeted Test', 'scope' => 'product', 'targetProductIds' => [$productId]]), $headers)
            ->assertCreated()->assertJsonPath('data.type', 'percentage')->assertJsonPath('data.targetProductIds.0', $productId);
        $discountId = $created->json('data.id');

        $this->patchJson("/api/v1/discounts/{$discountId}", $this->payload(['name' => 'Updated Fixed', 'type' => 'fixed', 'value' => 5]), $headers)
            ->assertOk()->assertJsonPath('data.name', 'Updated Fixed')->assertJsonPath('data.type', 'fixed');
        $this->patchJson("/api/v1/discounts/{$discountId}/status", ['isActive' => false], $headers)
            ->assertOk()->assertJsonPath('data.status', 'inactive');

        // A different tenant's token must not be able to see this discount.
        $otherTenant = (int) DB::table('tenants')->insertGetId(['name' => 'Other', 'slug' => 'other', 'created_at' => now(), 'updated_at' => now()]);
        $otherUser = (int) DB::table('users')->insertGetId(['tenant_id' => $otherTenant, 'name' => 'Other Owner', 'email' => 'other-owner@example.test', 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson("/api/v1/discounts/{$discountId}", $this->headers($otherTenant, $otherUser))->assertNotFound();

        $this->deleteJson("/api/v1/discounts/{$discountId}", [], $headers)->assertNoContent();
    }

    public function test_validation_rejects_duplicate_codes_and_invalid_dates(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $headers = $this->headers($tenantId);

        $this->postJson('/api/v1/discounts', $this->payload(['code' => 'MRNG15']), $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->postJson('/api/v1/discounts', $this->payload(['startsAt' => '2026-08-02T00:00:00Z', 'endsAt' => '2026-08-01T00:00:00Z']), $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('endsAt');
    }

    public function test_branch_targets_are_tenant_scoped_and_can_be_cleared_for_all_branches(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $headers = $this->headers($tenantId);
        $branchIds = DB::table('branches')->where('tenant_id', $tenantId)->orderBy('id')->pluck('id')->map(fn ($id) => (int) $id)->all();

        $this->postJson('/api/v1/discounts', $this->payload(['name' => 'All Branches', 'code' => 'ALL-BRANCHES', 'branchIds' => []]), $headers)
            ->assertCreated()->assertJsonPath('data.appliesToAllBranches', true)->assertJsonCount(0, 'data.branchIds');
        $created = $this->postJson('/api/v1/discounts', $this->payload(['name' => 'One Branch', 'code' => 'ONE-BRANCH', 'appliesToAllBranches' => false, 'branchIds' => [$branchIds[0]]]), $headers)
            ->assertCreated()->assertJsonPath('data.appliesToAllBranches', false)->assertJsonPath('data.branchIds.0', $branchIds[0]);
        $this->postJson('/api/v1/discounts', $this->payload(['name' => 'Many Branches', 'code' => 'MANY-BRANCHES', 'appliesToAllBranches' => false, 'branchIds' => array_slice($branchIds, 0, 2)]), $headers)
            ->assertCreated()->assertJsonCount(2, 'data.branchIds');
        $this->postJson('/api/v1/discounts', $this->payload(['name' => 'Invalid Branch', 'code' => 'INVALID-BRANCH', 'appliesToAllBranches' => false, 'branchIds' => [999999]]), $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('branchIds.0');

        $otherTenant = DB::table('tenants')->insertGetId(['name' => 'Other Branch Tenant', 'slug' => 'other-branch-tenant', 'created_at' => now(), 'updated_at' => now()]);
        $otherBranch = DB::table('branches')->insertGetId(['tenant_id' => $otherTenant, 'name' => 'Other Branch', 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson('/api/v1/discounts', $this->payload(['name' => 'Foreign Branch', 'code' => 'FOREIGN-BRANCH', 'appliesToAllBranches' => false, 'branchIds' => [$otherBranch]]), $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('branchIds.0');

        $discountId = $created->json('data.id');
        $this->patchJson("/api/v1/discounts/{$discountId}", $this->payload(['name' => 'Now All Branches', 'code' => 'ONE-BRANCH', 'branchIds' => []]), $headers)
            ->assertOk()->assertJsonPath('data.appliesToAllBranches', true)->assertJsonCount(0, 'data.branchIds');
    }

    public function test_tenant_and_branch_seed_data_is_idempotent(): void
    {
        $this->seed(TenantAccessSeeder::class);
        $this->seed(TenantAccessSeeder::class);

        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $this->assertSame(1, DB::table('tenants')->where('slug', 'cafe-618')->count());
        $this->assertSame(4, DB::table('branches')->where('tenant_id', $tenantId)->count());
    }

    public function test_discounts_require_authentication(): void
    {
        $this->call('GET', '/api/v1/discounts')->assertUnauthorized();
    }

    private function payload(array $overrides = []): array
    {
        return $overrides + [
            'name' => 'Management Test', 'code' => 'MANAGE10', 'applicationMode' => 'code', 'type' => 'percentage',
            'scope' => 'order', 'value' => 10, 'minimumOrderAmount' => 0, 'isActive' => true,
            'appliesToAllBranches' => true, 'branchIds' => [],
        ];
    }

    private function headers(int $tenantId, ?int $userId = null): array
    {
        $userId ??= (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = "discount-test-{$tenantId}-{$userId}";
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'discount-management-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
