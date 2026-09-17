<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Carbon\CarbonImmutable;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DiscountV2BackendTest extends TestCase
{
    use RefreshDatabase;

    public function test_management_v2_fields_round_trip_and_clear_losslessly(): void
    {
        $scope = $this->scope();
        $customer = $this->customer($scope, 'Round trip customer');
        $secondProduct = $this->product($scope, 'Cookie', 20);
        $headers = $this->headers($scope);
        $generated = $this->postJson('/api/v1/discounts/generate-code', [], $headers)->assertOk()->json('data.code');
        $this->assertMatchesRegularExpression('/^CPN-[A-Z2-9]{4}-[A-Z2-9]{4}$/', $generated);

        $payload = $this->managementPayload($scope, $customer, $secondProduct, $generated);
        $created = $this->postJson('/api/v1/discounts', $payload, $headers)->assertCreated();
        $id = (int) $created->json('data.id');
        $created->assertJsonPath('data.customerEligibilityMode', 'selected_customers')
            ->assertJsonPath('data.customerIds.0', $customer)
            ->assertJsonPath('data.channelKeys.0', 'delivery')
            ->assertJsonPath('data.perCustomerDailyUsageLimit', 1)
            ->assertJsonPath('data.bundleRequirements.0.productId', $scope['product']);

        $this->getJson("/api/v1/discounts/{$id}", $headers)->assertOk()
            ->assertJsonPath('data.bundleRequirements.1.productId', $secondProduct)
            ->assertJsonPath('data.customers.0.id', $customer);

        $payload['customerEligibilityMode'] = 'all';
        $payload['customerIds'] = [];
        $payload['channelKeys'] = [];
        $payload['perCustomerDailyUsageLimit'] = null;
        $this->putJson("/api/v1/discounts/{$id}", $payload, $headers)->assertOk()
            ->assertJsonPath('data.customerEligibilityMode', 'all')
            ->assertJsonCount(0, 'data.customerIds')
            ->assertJsonCount(0, 'data.channelKeys')
            ->assertJsonPath('data.perCustomerDailyUsageLimit', null);
    }

    public function test_generated_codes_require_management_auth_are_case_insensitively_unique_and_never_discovered(): void
    {
        $this->postJson('/api/v1/discounts/generate-code', [], ['Authorization' => 'Bearer invalid'])->assertUnauthorized();
        $scope = $this->scope();
        $code = $this->postJson('/api/v1/discounts/generate-code', [], $this->headers($scope))->assertOk()->json('data.code');
        DB::table('discounts')->insert([
            'tenant_id' => $scope['tenant'], 'name' => 'Secret code', 'code' => $code, 'application_mode' => 'code', 'type' => 'percentage', 'value' => 10,
            'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->getJson("/api/v1/discounts/available?orderId={$scope['order']}", $this->headers($scope))
            ->assertOk()->assertJsonCount(0, 'data')->assertJsonMissing(['code' => $code]);
        try {
            DB::transaction(function () use ($scope, $code): void {
                DB::table('discounts')->insert([
                    'tenant_id' => $scope['tenant'], 'name' => 'Duplicate code', 'code' => strtolower($code), 'application_mode' => 'code', 'type' => 'percentage', 'value' => 10,
                    'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now(),
                ]);
            });
            $this->fail('The database must reject a differently cased duplicate coupon code for one tenant.');
        } catch (QueryException) {
            // The expression index, rather than application validation, is the
            // concurrency-safe authority for tenant-local code uniqueness.
        }

        $otherTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Other coupon tenant', 'slug' => 'other-coupon-'.uniqid(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('discounts')->insert([
            'tenant_id' => $otherTenant, 'name' => 'Tenant-local code', 'code' => strtolower($code), 'application_mode' => 'code', 'type' => 'percentage', 'value' => 10,
            'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->assertSame(2, DB::table('discounts')->whereRaw('LOWER(code) = ?', [strtolower($code)])->count());
    }

    public function test_selected_customer_bundle_channel_and_payment_revalidation_use_authoritative_order_state(): void
    {
        $scope = $this->scope();
        $customer = $this->customer($scope, 'Selected customer');
        $cookie = $this->product($scope, 'Cookie', 20);
        DB::table('orders')->where('id', $scope['order'])->update(['customer_id' => $customer]);
        DB::table('order_items')->insert([
            'tenant_id' => $scope['tenant'], 'order_id' => $scope['order'], 'product_id' => $cookie, 'category_id' => $scope['category'],
            'product_name' => 'Cookie', 'quantity' => 3, 'unit_price' => 20, 'total' => 60, 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('orders')->where('id', $scope['order'])->update(['subtotal' => 160, 'total' => 160]);
        $discount = $this->discount($scope, ['scope' => 'bundle', 'value' => 20, 'customer_eligibility' => 'selected_customers']);
        $this->target($scope, $discount, 'customer', $customer);
        DB::table('discount_bundle_requirements')->insert([
            ['tenant_id' => $scope['tenant'], 'discount_id' => $discount, 'product_id' => $scope['product'], 'quantity' => 1, 'created_at' => now(), 'updated_at' => now()],
            ['tenant_id' => $scope['tenant'], 'discount_id' => $discount, 'product_id' => $cookie, 'quantity' => 1, 'created_at' => now(), 'updated_at' => now()],
        ]);
        DB::table('discount_channel_targets')->insert(['tenant_id' => $scope['tenant'], 'discount_id' => $discount, 'channel_key' => 'pos', 'created_at' => now(), 'updated_at' => now()]);

        $this->apply($scope, $discount)->assertOk()->assertJsonPath('data.discount.amount', 24); // 20% of 100 + 20, not all 3 cookies.
        DB::table('orders')->where('id', $scope['order'])->update(['sales_channel' => 'delivery']);
        $this->postJson("/api/v1/orders/{$scope['order']}/pay", ['method' => 'cash', 'paymentMethodId' => $scope['cashMethod'], 'amount' => 136, 'idempotencyKey' => 'v2-channel-change'], $this->headers($scope))
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CHANNEL_NOT_ELIGIBLE');
    }

    public function test_daily_limit_requires_customer_and_uses_branch_local_business_date(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-09-17 00:30:00', 'Asia/Damascus'));
        $scope = $this->scope('Asia/Damascus');
        $customer = $this->customer($scope, 'Daily customer');
        $discount = $this->discount($scope, ['usage_limit_per_customer_per_day' => 1]);
        $this->apply($scope, $discount)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CUSTOMER_REQUIRED');

        DB::table('orders')->where('id', $scope['order'])->update(['customer_id' => $customer]);
        DB::table('discount_usages')->insert([
            'tenant_id' => $scope['tenant'], 'discount_id' => $discount, 'order_id' => $scope['order'],
            'customer_id' => $customer, 'business_date' => '2026-09-17', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->apply($scope, $discount)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_DAILY_USAGE_LIMIT_REACHED');
        DB::table('discount_usages')->where('discount_id', $discount)->update(['business_date' => '2026-09-16']);
        $this->apply($scope, $discount)->assertOk();
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    private function scope(string $timezone = 'Asia/Damascus'): array
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Discount v2', 'slug' => 'discount-v2-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch', 'timezone' => $timezone, 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $category = (int) DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Category', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $product = $this->product(compact('tenant', 'category'), 'Coffee', 100);
        $this->authenticateTenantUser($tenant);
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $owner);
        $cashMethod = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('type', 'cash')->value('id');
        $shift = (int) DB::table('shifts')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $owner, 'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $order = (int) DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'sales_channel' => 'pos', 'shift_id' => $shift, 'order_number' => 'V2-1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 100, 'tax_rate' => 0, 'total' => 100, 'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('order_items')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'category_id' => $category, 'product_name' => 'Coffee', 'quantity' => 1, 'unit_price' => 100, 'total' => 100, 'created_at' => $now, 'updated_at' => $now]);

        return compact('tenant', 'branch', 'category', 'product', 'order', 'cashMethod', 'owner');
    }

    private function product(array $scope, string $name, int $price): int
    {
        return (int) DB::table('products')->insertGetId(['tenant_id' => $scope['tenant'], 'category_id' => $scope['category'], 'name' => $name, 'price' => $price, 'cost_price' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function customer(array $scope, string $name): int
    {
        return (int) DB::table('customers')->insertGetId(['tenant_id' => $scope['tenant'], 'name' => $name, 'customer_number' => 'C-'.uniqid(), 'normalized_name' => strtolower($name).'-'.uniqid(), 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function discount(array $scope, array $overrides = []): int
    {
        return (int) DB::table('discounts')->insertGetId($overrides + ['tenant_id' => $scope['tenant'], 'name' => 'V2 policy', 'application_mode' => 'manual', 'type' => 'percentage', 'value' => 10, 'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function target(array $scope, int $discount, string $type, int $target): void
    {
        DB::table('discount_targets')->insert(['tenant_id' => $scope['tenant'], 'discount_id' => $discount, 'target_type' => $type, 'target_id' => $target, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function apply(array $scope, int $discount)
    {
        return $this->postJson("/api/v1/orders/{$scope['order']}/discounts/apply", ['discountId' => $discount], $this->headers($scope));
    }

    private function headers(array $scope): array
    {
        return ['X-Tenant-Id' => (string) $scope['tenant']];
    }

    private function managementPayload(array $scope, int $customer, int $secondProduct, string $code): array
    {
        return ['name' => 'Bundle delivery', 'code' => $code, 'applicationMode' => 'code', 'type' => 'percentage', 'scope' => 'bundle', 'value' => 20,
            'targetProductIds' => [], 'targetCategoryIds' => [], 'bundleRequirements' => [['productId' => $scope['product'], 'quantity' => 1], ['productId' => $secondProduct, 'quantity' => 2]],
            'customerEligibilityMode' => 'selected_customers', 'customerIds' => [$customer], 'customerGroupIds' => [], 'channelKeys' => ['delivery'],
            'perCustomerDailyUsageLimit' => 1, 'appliesToAllBranches' => true, 'branchIds' => [], 'paymentMethodIds' => [], 'isActive' => true];
    }
}
