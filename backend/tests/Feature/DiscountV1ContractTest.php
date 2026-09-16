<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DiscountV1ContractTest extends TestCase
{
    use RefreshDatabase;

    public function test_create_detail_and_full_policy_update_are_lossless_for_v1_targets(): void
    {
        $this->seed();
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        $branchIds = DB::table('branches')->where('tenant_id', $tenant)->orderBy('id')->limit(2)->pluck('id')->map(fn ($id) => (int) $id)->all();
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branchIds[0], $owner);
        $method = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('is_active', true)->value('id');
        $category = (int) DB::table('categories')->where('tenant_id', $tenant)->value('id');
        DB::table('categories')->where('id', $category)->update(['is_active' => true]);
        $group = (int) DB::table('customer_groups')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'Contract members', 'normalized_name' => 'contract members', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $payload = $this->payload($category, $group, $branchIds, $method);
        $headers = $this->headers($tenant, $owner);
        $created = $this->postJson('/api/v1/discounts', $payload, $headers)->assertCreated();
        $id = (int) $created->json('data.id');
        $created->assertJsonPath('data.customerEligibilityMode', 'selected_groups')
            ->assertJsonPath('data.customerGroupIds.0', $group)
            ->assertJsonPath('data.paymentMethodIds.0', $method)
            ->assertJsonPath('data.targetCategoryIds.0', $category)
            ->assertJsonPath('data.branchIds.1', $branchIds[1])
            ->assertJsonPath('data.startDate', '2026-09-01')
            ->assertJsonPath('data.endTime', '02:00:00');

        $this->getJson("/api/v1/discounts/{$id}", $headers)->assertOk()
            ->assertJsonPath('data.customerGroups.0.id', $group)
            ->assertJsonPath('data.paymentMethods.0.id', $method)
            ->assertJsonPath('data.categoryTargets.0.id', $category)
            ->assertJsonPath('data.branches.0.id', $branchIds[0]);

        $payload['name'] = 'Only the name changed';
        $this->putJson("/api/v1/discounts/{$id}", $payload, $headers)->assertOk()
            ->assertJsonPath('data.name', 'Only the name changed')
            ->assertJsonPath('data.customerGroupIds.0', $group)
            ->assertJsonPath('data.paymentMethodIds.0', $method)
            ->assertJsonPath('data.targetCategoryIds.0', $category)
            ->assertJsonPath('data.usageLimitPerCustomer', 3);
    }

    public function test_v1_rejects_inactive_and_cross_tenant_group_payment_and_catalog_targets(): void
    {
        $this->seed();
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $category = (int) DB::table('categories')->where('tenant_id', $tenant)->value('id');
        DB::table('categories')->where('id', $category)->update(['is_active' => true]);
        $inactiveGroup = (int) DB::table('customer_groups')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'Archived', 'normalized_name' => 'archived', 'is_active' => false,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $payload = $this->payload($category, $inactiveGroup, [$branch], null);
        $this->postJson('/api/v1/discounts', $payload, $this->headers($tenant, $owner))
            ->assertUnprocessable()->assertJsonValidationErrors('customerGroupIds');

        $foreignTenant = (int) DB::table('tenants')->insertGetId(['name' => 'Foreign', 'slug' => 'foreign-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $foreignGroup = (int) DB::table('customer_groups')->insertGetId([
            'tenant_id' => $foreignTenant, 'name' => 'Foreign group', 'normalized_name' => 'foreign group', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $payload['customerGroupIds'] = [$foreignGroup];
        $this->postJson('/api/v1/discounts', $payload, $this->headers($tenant, $owner))
            ->assertUnprocessable()->assertJsonValidationErrors('customerGroupIds');

        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner);
        $inactiveMethod = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('is_active', true)->value('id');
        DB::table('payment_methods')->where('id', $inactiveMethod)->update(['is_active' => false]);
        $payload['customerGroupIds'] = [];
        $payload['customerEligibilityMode'] = 'all';
        $payload['paymentMethodIds'] = [$inactiveMethod];
        $this->postJson('/api/v1/discounts', $payload, $this->headers($tenant, $owner))
            ->assertUnprocessable()->assertJsonValidationErrors('paymentMethodIds');
    }

    private function payload(int $category, int $group, array $branchIds, ?int $paymentMethodId): array
    {
        return [
            'name' => 'Lossless policy', 'code' => 'LOSSLESS20', 'description' => 'Complete V1 configuration',
            'applicationMode' => 'code', 'type' => 'percentage', 'scope' => 'category', 'value' => 20,
            'targetProductIds' => [], 'targetCategoryIds' => [$category],
            'customerEligibilityMode' => 'selected_groups', 'customerGroupIds' => [$group],
            'appliesToAllBranches' => false, 'branchIds' => $branchIds,
            'startDate' => '2026-09-01', 'endDate' => '2026-12-31', 'activeDays' => ['Mon', 'Fri'],
            'startTime' => '22:00', 'endTime' => '02:00', 'minimumOrderAmount' => 20,
            'maximumDiscountAmount' => 50, 'usageLimit' => 100, 'usageLimitPerCustomer' => 3,
            'paymentMethodIds' => $paymentMethodId ? [$paymentMethodId] : [], 'isActive' => true,
        ];
    }

    private function headers(int $tenant, int $user): array
    {
        $token = "discount-v1-{$tenant}-{$user}";
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'discount-v1-test'],
            ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
    }
}
