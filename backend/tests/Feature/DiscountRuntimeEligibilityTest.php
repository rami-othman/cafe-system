<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
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
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $scope['tenant'], 'name' => 'VIP', 'customer_number' => 'C-000001', 'normalized_name' => 'vip', 'total_spent' => 1000, 'visits_count' => 3, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
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

    public function test_a_hundred_percent_discount_completes_without_a_payment_method(): void
    {
        $scope = $this->scope();
        $discount = $this->discount($scope, ['type' => 'percentage', 'value' => 100, 'usage_limit' => 1]);
        $this->apply($scope, $discount)->assertOk()->assertJsonPath('data.totals.total', 0);

        $this->getJson("/api/v1/orders/{$scope['order']}/payment-summary", $this->headers($scope))
            ->assertOk()->assertJsonPath('data.canPay', true)->assertJsonPath('data.totalDue', 0);
        $paid = $this->postJson("/api/v1/orders/{$scope['order']}/pay", [
            'amount' => 0, 'idempotencyKey' => 'zero-percent-once',
        ], $this->headers($scope))->assertOk()->assertJsonPath('data.payment.method', 'zero_balance');
        $this->postJson("/api/v1/orders/{$scope['order']}/pay", [
            'amount' => 0, 'idempotencyKey' => 'zero-percent-once',
        ], $this->headers($scope))->assertOk()->assertJsonPath('data.payment.id', $paid->json('data.payment.id'));

        $this->assertSame('paid', DB::table('orders')->where('id', $scope['order'])->value('payment_status'));
        $this->assertNull(DB::table('payments')->where('order_id', $scope['order'])->value('payment_method_id'));
        $this->assertSame(1, DB::table('discount_usages')->where('discount_id', $discount)->count());
        $this->assertSame(1, (int) DB::table('discounts')->where('id', $discount)->value('used_count'));
    }

    public function test_payment_method_id_is_authoritative_for_discount_eligibility_and_idempotent_retries(): void
    {
        $scope = $this->scope();
        $cashOnly = $this->discount($scope, ['payment_method' => 'cash']);
        $this->apply($scope, $cashOnly)->assertOk();
        $paid = $this->postJson("/api/v1/orders/{$scope['order']}/pay", [
            'method' => 'cash', 'paymentMethodId' => $scope['cashMethod'], 'amount' => 100, 'idempotencyKey' => 'matching-method-id',
        ], $this->headers($scope))->assertOk();
        $this->assertSame($scope['cashMethod'], (int) DB::table('payments')->where('id', $paid->json('data.payment.id'))->value('payment_method_id'));

        // A completed replay remains recoverable even if an administrator
        // deactivates the method after the original successful payment.
        DB::table('payment_methods')->where('id', $scope['cashMethod'])->update(['is_active' => false]);
        $this->postJson("/api/v1/orders/{$scope['order']}/pay", [
            'method' => 'cash', 'paymentMethodId' => $scope['cashMethod'], 'amount' => 100, 'idempotencyKey' => 'matching-method-id',
        ], $this->headers($scope))->assertOk()->assertJsonPath('data.payment.id', $paid->json('data.payment.id'));

        $mismatch = $this->scope();
        $this->apply($mismatch, $this->discount($mismatch, ['payment_method' => 'cash']))->assertOk();
        $this->postJson("/api/v1/orders/{$mismatch['order']}/pay", [
            'method' => 'cash', 'paymentMethodId' => $mismatch['cardMethod'], 'amount' => 100, 'idempotencyKey' => 'cash-card-mismatch',
        ], $this->headers($mismatch))->assertUnprocessable()->assertJsonValidationErrors('paymentMethodId');
        $this->assertSame(0, DB::table('payments')->where('order_id', $mismatch['order'])->count());

        $foreign = $this->scope();
        $this->postJson("/api/v1/orders/{$foreign['order']}/pay", [
            'method' => 'card', 'paymentMethodId' => $mismatch['cardMethod'], 'amount' => 100, 'idempotencyKey' => 'foreign-method',
        ], $this->headers($foreign))->assertUnprocessable()->assertJsonValidationErrors('paymentMethodId');

        DB::table('payment_methods')->where('id', $foreign['cardMethod'])->update(['is_active' => false]);
        $this->postJson("/api/v1/orders/{$foreign['order']}/pay", [
            'method' => 'card', 'paymentMethodId' => $foreign['cardMethod'], 'amount' => 100, 'idempotencyKey' => 'inactive-method',
        ], $this->headers($foreign))->assertUnprocessable()->assertJsonValidationErrors('paymentMethodId');
    }

    public function test_customer_group_membership_is_authoritative_at_apply_and_payment_time(): void
    {
        $scope = $this->scope();
        $member = (int) DB::table('customers')->insertGetId([
            'tenant_id' => $scope['tenant'], 'name' => 'Member', 'customer_number' => 'C-GROUP-1', 'normalized_name' => 'member',
            'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $nonMember = (int) DB::table('customers')->insertGetId([
            'tenant_id' => $scope['tenant'], 'name' => 'Anonymous identity', 'customer_number' => 'C-GROUP-2', 'normalized_name' => 'anonymous identity',
            'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $groupA = $this->group($scope, 'Group A');
        $groupB = $this->group($scope, 'Group B');
        foreach ([$groupA, $groupB] as $group) {
            DB::table('customer_group_memberships')->insert([
                'tenant_id' => $scope['tenant'], 'customer_id' => $member, 'customer_group_id' => $group,
                'created_at' => now(), 'updated_at' => now(),
            ]);
        }
        DB::table('orders')->where('id', $scope['order'])->update(['customer_id' => $member]);
        $discount = $this->discount($scope);
        $this->target($scope, $discount, 'customer_group', $groupB);
        $this->apply($scope, $discount)->assertOk(); // Matches one of multiple memberships.

        DB::table('customer_group_memberships')->where('tenant_id', $scope['tenant'])->where('customer_id', $member)->where('customer_group_id', $groupB)->delete();
        $this->postJson("/api/v1/orders/{$scope['order']}/pay", [
            'method' => 'cash', 'paymentMethodId' => $scope['cashMethod'], 'amount' => 100, 'idempotencyKey' => 'group-membership-removed',
        ], $this->headers($scope))->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CUSTOMER_NOT_ELIGIBLE');

        DB::table('orders')->where('id', $scope['order'])->update(['customer_id' => $nonMember]);
        $this->apply($scope, $discount)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CUSTOMER_NOT_ELIGIBLE');
        DB::table('customer_groups')->where('id', $groupB)->update(['is_active' => false]);
        DB::table('orders')->where('id', $scope['order'])->update(['customer_id' => $member]);
        DB::table('customer_group_memberships')->insert([
            'tenant_id' => $scope['tenant'], 'customer_id' => $member, 'customer_group_id' => $groupB,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->apply($scope, $discount)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CUSTOMER_NOT_ELIGIBLE');
    }

    public function test_paid_order_retains_its_discount_snapshot_after_the_policy_changes(): void
    {
        $scope = $this->scope();
        $discount = $this->discount($scope, ['name' => 'Original 10%', 'value' => 10]);
        $this->apply($scope, $discount)->assertOk()->assertJsonPath('data.discount.amount', 10);
        $this->postJson("/api/v1/orders/{$scope['order']}/pay", [
            'method' => 'cash', 'paymentMethodId' => $scope['cashMethod'], 'amount' => 90, 'idempotencyKey' => 'historical-discount-snapshot',
        ], $this->headers($scope))->assertOk();

        $snapshot = DB::table('order_discounts')->where('order_id', $scope['order'])->first();
        DB::table('discounts')->where('id', $discount)->update([
            'name' => 'Changed after payment', 'value' => 75, 'is_active' => false, 'updated_at' => now(),
        ]);
        DB::table('discount_targets')->insert([
            'tenant_id' => $scope['tenant'], 'discount_id' => $discount, 'target_type' => 'branch', 'target_id' => $scope['branch'],
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $paidOrder = DB::table('orders')->where('id', $scope['order'])->first();
        $retained = DB::table('order_discounts')->where('order_id', $scope['order'])->first();
        $this->assertSame('paid', $paidOrder->payment_status);
        $this->assertSame(90.0, (float) $paidOrder->total);
        $this->assertSame($snapshot->discount_name, $retained->discount_name);
        $this->assertSame((float) $snapshot->discount_value, (float) $retained->discount_value);
        $this->assertSame((float) $snapshot->discount_amount, (float) $retained->discount_amount);
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
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $actorId);
        $bankAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1030')->value('id');
        $cashMethod = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('type', 'cash')->value('id');
        $cardMethod = (int) DB::table('payment_methods')->insertGetId([
            'tenant_id' => $tenant, 'code' => 'CARD', 'name' => 'Card', 'type' => 'card',
            'financial_account_id' => $bankAccountId, 'is_active' => true, 'sort_order' => 2,
            'created_by' => $actorId, 'updated_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
        ]);
        $shift = DB::table('shifts')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $actorId, 'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $order = DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'shift_id' => $shift, 'order_number' => 'D-1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 100, 'tax_rate' => 0, 'total' => 100, 'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('order_items')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'category_id' => $category, 'product_name' => 'Published Product', 'quantity' => 1, 'unit_price' => 100, 'total' => 100, 'created_at' => $now, 'updated_at' => $now]);

        return compact('tenant', 'branch', 'category', 'product', 'publication', 'order', 'cashMethod', 'cardMethod');
    }

    private function discount(array $scope, array $overrides = []): int
    {
        return DB::table('discounts')->insertGetId($overrides + [
            'tenant_id' => $scope['tenant'], 'name' => 'Runtime policy '.uniqid(), 'application_mode' => 'manual', 'type' => 'percentage', 'value' => 10,
            'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function target(array $scope, int $discount, string $type, int $target): void
    {
        DB::table('discount_targets')->insert(['tenant_id' => $scope['tenant'], 'discount_id' => $discount, 'target_type' => $type, 'target_id' => $target, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function group(array $scope, string $name): int
    {
        return (int) DB::table('customer_groups')->insertGetId([
            'tenant_id' => $scope['tenant'], 'name' => $name, 'normalized_name' => strtolower($name).'-'.uniqid(), 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
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
