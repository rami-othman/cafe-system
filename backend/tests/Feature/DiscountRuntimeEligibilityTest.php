<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DiscountRuntimeEligibilityTest extends TestCase
{
    use RefreshDatabase;

    public function test_date_day_time_branch_and_minimum_rules_are_enforced_from_the_order_branch(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-09-04 23:00:00', 'America/New_York'));
        $scope = $this->scope('America/New_York'); // Friday, inside an overnight window.
        $discount = $this->discount($scope, [
            'starts_at' => CarbonImmutable::now('UTC')->subMinute(),
            'ends_at' => CarbonImmutable::now('UTC')->addMinute(),
            'active_days' => json_encode(['Fri']), 'start_time' => '22:00:00', 'end_time' => '02:00:00',
            'minimum_order_amount' => 20,
        ]);
        $this->target($scope, $discount, 'branch', $scope['branch']);

        $this->apply($scope, $discount)->assertOk()->assertJsonPath('data.discount.amount', 10);

        DB::table('discounts')->where('id', $discount)->update(['active_days' => json_encode(['Thu'])]);
        $this->apply($scope, $discount)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_DAY_NOT_ALLOWED');
        DB::table('discounts')->where('id', $discount)->update(['active_days' => json_encode(['Fri']), 'start_time' => '00:00:00', 'end_time' => '01:00:00']);
        $this->apply($scope, $discount)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_TIME_NOT_ALLOWED');
        DB::table('discounts')->where('id', $discount)->update(['start_time' => null, 'end_time' => null, 'starts_at' => CarbonImmutable::now('UTC')->addSecond()]);
        $this->apply($scope, $discount)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_NOT_STARTED');
        DB::table('discounts')->where('id', $discount)->update(['starts_at' => CarbonImmutable::now('UTC'), 'ends_at' => CarbonImmutable::now('UTC')]);
        $this->apply($scope, $discount)->assertOk(); // Date boundaries are inclusive.
    }

    public function test_targeted_calculation_uses_the_immutable_versioned_category_not_live_catalog(): void
    {
        $scope = $this->scope();
        $otherCategory = DB::table('categories')->insertGetId(['tenant_id' => $scope['tenant'], 'name' => 'Changed live category', 'created_at' => now(), 'updated_at' => now()]);
        $version = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $scope['tenant'], 'menu_publication_id' => $scope['publication'], 'branch_id' => $scope['branch'],
            'channel' => 'pos', 'version_number' => 1, 'payload_json' => json_encode(['context' => ['schemaVersion' => 3], 'menus' => []]),
            'checksum' => str_repeat('a', 64), 'status' => 'current', 'published_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('orders')->where('id', $scope['order'])->update(['published_menu_version_id' => $version]);
        DB::table('products')->where('id', $scope['product'])->update(['category_id' => $otherCategory]);
        $discount = $this->discount($scope, ['scope' => 'category', 'value' => 25]);
        $this->target($scope, $discount, 'category', $scope['category']);

        $this->apply($scope, $discount)->assertOk()->assertJsonPath('data.discount.amount', 25);
    }

    public function test_customer_payment_and_usage_limits_are_revalidated_when_paid_without_double_consumption(): void
    {
        $scope = $this->scope();
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $scope['tenant'], 'name' => 'VIP', 'total_spent' => 1000, 'visits_count' => 3, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('orders')->where('id', $scope['order'])->update(['customer_id' => $customer]);
        $discount = $this->discount($scope, [
            'customer_eligibility' => 'VIP', 'payment_method' => 'card', 'usage_limit' => 1, 'usage_limit_per_customer' => 1,
        ]);
        $this->apply($scope, $discount)->assertOk(); // Tender is intentionally unknown at Apply.
        $this->postJson("/api/v1/orders/{$scope['order']}/pay", ['method' => 'cash', 'amount' => 100, 'idempotencyKey' => 'wrong-tender'], $this->headers($scope))
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_PAYMENT_METHOD_NOT_ALLOWED');
        $paid = $this->postJson("/api/v1/orders/{$scope['order']}/pay", ['method' => 'card', 'amount' => 100, 'idempotencyKey' => 'paid-once'], $this->headers($scope))
            ->assertOk();
        $this->postJson("/api/v1/orders/{$scope['order']}/pay", ['method' => 'card', 'amount' => 100, 'idempotencyKey' => 'paid-once'], $this->headers($scope))
            ->assertOk()->assertJsonPath('data.payment.id', $paid->json('data.payment.id'));
        $this->assertSame(1, DB::table('discount_usages')->where('discount_id', $discount)->count());
        $this->assertSame(1, (int) DB::table('discounts')->where('id', $discount)->value('used_count'));
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    private function scope(string $timezone = 'Asia/Damascus'): array
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Discount runtime', 'slug' => 'discount-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch', 'timezone' => $timezone, 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Published category', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Product', 'price' => 100, 'cost_price' => 1, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $publication = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $this->authenticateTenantUser($tenant);
        $actorId = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->orderBy('id')->value('id');
        $shift = DB::table('shifts')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $actorId, 'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $order = DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'shift_id' => $shift, 'order_number' => 'D-1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 100, 'tax_rate' => 0, 'total' => 100, 'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('order_items')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'category_id' => $category, 'product_name' => 'Published Product', 'quantity' => 1, 'unit_price' => 100, 'total' => 100, 'created_at' => $now, 'updated_at' => $now]);

        return compact('tenant', 'branch', 'category', 'product', 'publication', 'order');
    }

    private function discount(array $scope, array $overrides = []): int
    {
        return DB::table('discounts')->insertGetId($overrides + [
            'tenant_id' => $scope['tenant'], 'name' => 'Runtime policy '.uniqid(), 'application_mode' => 'auto', 'type' => 'percentage', 'value' => 10,
            'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
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
}
