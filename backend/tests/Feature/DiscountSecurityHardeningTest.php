<?php

namespace Tests\Feature;

use App\Domain\Discount\DiscountAccess;
use App\Models\User;
use App\Services\DefaultTenantRoleService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DiscountSecurityHardeningTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_manager_and_employee_receive_the_temporary_four_permission_defaults(): void
    {
        $scope = $this->scope();
        $manager = User::query()->create([
            'tenant_id' => $scope['tenant'],
            'tenant_role_id' => app(DefaultTenantRoleService::class)->ensureForTenant($scope['tenant'])['manager']->id,
            'name' => 'Manager', 'email' => 'manager-'.uniqid().'@example.test', 'password' => 'test-password',
            'role' => 'manager', 'is_active' => true,
        ]);
        $access = app(DiscountAccess::class);
        foreach ([$scope['owner'], $manager, $scope['employee']] as $actor) {
            $request = Request::create('/');
            $request->attributes->set('auth_user', $actor);
            foreach (DiscountAccess::CATALOG as $permission) {
                $this->assertTrue($access->allows($request, $permission));
            }
        }
        $this->assertSame(4, DB::table('discount_role_permissions')->where('tenant_id', $scope['tenant'])->where('role', 'manager')->count());
        $this->assertSame(4, DB::table('discount_role_permissions')->where('tenant_id', $scope['tenant'])->where('role', 'employee')->count());
    }

    public function test_employee_permissions_and_order_branch_access_are_enforced(): void
    {
        $scope = $this->scope();
        $employeeHeaders = $this->headers($scope['tenant'], $scope['employee']);

        $this->getJson('/api/v1/discounts', $employeeHeaders)->assertOk();
        $this->postJson('/api/v1/discounts', $this->managementPayload(), $employeeHeaders)->assertCreated();
        $this->putJson("/api/v1/orders/{$scope['orderA']}/discount", ['type' => 'percentage', 'value' => 10], $employeeHeaders)->assertOk();

        $this->putJson('/api/v1/discounts/role-permissions/employee', [
            'permissions' => [DiscountAccess::VIEW, DiscountAccess::APPLY_CONFIGURED],
        ], $this->headers($scope['tenant'], $scope['owner']))->assertOk();

        $this->getJson("/api/v1/discounts/available?orderId={$scope['orderA']}", $employeeHeaders)->assertOk();
        $this->postJson("/api/v1/orders/{$scope['orderA']}/discounts/apply", ['discountId' => $scope['manualDiscount']], $employeeHeaders)->assertOk();
        $this->getJson("/api/v1/discounts/available?orderId={$scope['orderB']}", $employeeHeaders)->assertForbidden();
        $this->postJson("/api/v1/orders/{$scope['orderB']}/discounts/apply", ['discountId' => $scope['manualDiscount']], $employeeHeaders)->assertForbidden();
        $this->deleteJson("/api/v1/orders/{$scope['orderB']}/discounts", [], $employeeHeaders)->assertForbidden();

        $ownerHeaders = $this->headers($scope['tenant'], $scope['owner']);
        $this->patchJson("/api/v1/discounts/{$scope['manualDiscount']}/status", ['isActive' => false], $ownerHeaders)->assertOk();
    }

    public function test_coupon_secrecy_bogo_lockout_single_discount_replacement_and_policy_invariants(): void
    {
        $scope = $this->scope();
        $headers = $this->headers($scope['tenant'], $scope['owner']);

        $available = $this->getJson("/api/v1/discounts/available?orderId={$scope['orderA']}", $headers)->assertOk();
        $available->assertJsonMissing(['id' => $scope['codeDiscount']])->assertJsonMissing(['id' => $scope['bogoDiscount']])->assertJsonMissing(['code' => 'SECRET10']);
        $this->postJson("/api/v1/orders/{$scope['orderA']}/discounts/apply", ['code' => 'wrong-code'], $headers)
            ->assertNotFound()->assertJsonMissing(['name' => 'Secret coupon']);

        $this->postJson("/api/v1/orders/{$scope['orderA']}/discounts/apply", ['discountId' => $scope['manualDiscount']], $headers)->assertOk();
        $this->assertManagedDiscount($scope, $scope['manualDiscount']);
        $this->postJson("/api/v1/orders/{$scope['orderA']}/discounts/apply", ['code' => 'sEcReT10'], $headers)
            ->assertOk()->assertJsonMissing(['code' => 'SECRET10']);
        $this->assertManagedDiscount($scope, $scope['codeDiscount']);
        $this->putJson("/api/v1/orders/{$scope['orderA']}/discount", ['type' => 'fixed', 'value' => 30], $headers)->assertOk();
        $this->assertSame(1, DB::table('order_discounts')->where('order_id', $scope['orderA'])->count());
        $this->assertNull(DB::table('order_discounts')->where('order_id', $scope['orderA'])->value('discount_id'));
        $this->postJson("/api/v1/orders/{$scope['orderA']}/discounts/apply", ['discountId' => $scope['manualDiscount']], $headers)->assertOk();
        $this->assertManagedDiscount($scope, $scope['manualDiscount']);

        $this->postJson("/api/v1/orders/{$scope['orderB']}/discounts/apply", ['discountId' => $scope['bogoDiscount']], $headers)
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_BOGO_UNSUPPORTED');
        $this->assertSame(0, DB::table('order_discounts')->where('order_id', $scope['orderB'])->count());

        $this->postJson('/api/v1/discounts', $this->managementPayload(['type' => 'bogo']), $headers)->assertUnprocessable()->assertJsonValidationErrors('type');
        $this->postJson('/api/v1/discounts', $this->managementPayload(['applicationMode' => 'automatic']), $headers)->assertUnprocessable()->assertJsonValidationErrors('applicationMode');
        $this->postJson('/api/v1/discounts', $this->managementPayload(['applicationMode' => 'code', 'code' => '']), $headers)->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->postJson('/api/v1/discounts', $this->managementPayload(['value' => -1]), $headers)->assertUnprocessable()->assertJsonValidationErrors('value');
        $this->postJson('/api/v1/discounts', $this->managementPayload(['value' => 101]), $headers)->assertUnprocessable()->assertJsonValidationErrors('value');
        $this->postJson('/api/v1/discounts', $this->managementPayload(['scope' => 'order', 'targetProductIds' => [$scope['product']]]), $headers)->assertUnprocessable()->assertJsonValidationErrors('targets');
    }

    private function scope(): array
    {
        $now = now();
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Discount hardening', 'slug' => 'discount-hardening-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $branchA = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'A', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $branchB = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'B', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
        $owner = User::query()->create(['tenant_id' => $tenant, 'tenant_role_id' => $roles['owner']->id, 'name' => 'Owner', 'email' => 'owner-'.uniqid().'@example.test', 'password' => 'test-password', 'role' => 'owner', 'is_active' => true]);
        $employee = User::query()->create(['tenant_id' => $tenant, 'tenant_role_id' => $roles['employee']->id, 'name' => 'Employee', 'email' => 'employee-'.uniqid().'@example.test', 'password' => 'test-password', 'role' => 'cashier', 'is_active' => true]);
        DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $employee->id, 'branch_id' => $branchA, 'created_at' => $now, 'updated_at' => $now]);
        $category = (int) DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Category', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $product = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Product', 'price' => 100, 'cost_price' => 1, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $orderA = $this->order($tenant, $branchA, $product);
        $orderB = $this->order($tenant, $branchB, $product);
        $manualDiscount = $this->discount($tenant, 'Configured', 'manual', 'percentage', null);
        $codeDiscount = $this->discount($tenant, 'Secret coupon', 'code', 'percentage', 'SECRET10');
        $bogoDiscount = $this->discount($tenant, 'Legacy BOGO', 'manual', 'bogo', null);

        return compact('tenant', 'owner', 'employee', 'product', 'orderA', 'orderB', 'manualDiscount', 'codeDiscount', 'bogoDiscount');
    }

    private function order(int $tenant, int $branch, int $product): int
    {
        $now = now();
        $order = (int) DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'order_number' => 'D-'.uniqid(), 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 100, 'total' => 100, 'tax_rate' => 0, 'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('order_items')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'product_name' => 'Product', 'quantity' => 1, 'unit_price' => 100, 'total' => 100, 'created_at' => $now, 'updated_at' => $now]);

        return $order;
    }

    private function discount(int $tenant, string $name, string $mode, string $type, ?string $code): int
    {
        return (int) DB::table('discounts')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'code' => $code, 'application_mode' => $mode, 'type' => $type, 'scope' => 'order', 'value' => 10, 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function assertManagedDiscount(array $scope, int $discount): void
    {
        $rows = DB::table('order_discounts')->where('order_id', $scope['orderA'])->get();
        $this->assertCount(1, $rows);
        $this->assertSame($discount, (int) $rows->first()->discount_id);
    }

    private function managementPayload(array $overrides = []): array
    {
        return $overrides + ['name' => 'Policy', 'applicationMode' => 'manual', 'type' => 'percentage', 'scope' => 'order', 'value' => 10, 'isActive' => true, 'appliesToAllBranches' => true];
    }

    private function headers(int $tenant, User $user): array
    {
        return ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $user)];
    }
}
