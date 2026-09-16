<?php

namespace Tests\Feature\Customer;

use App\Models\Branch;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerOrderHistoryApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_returns_only_the_requested_customer_orders_in_authorized_branches_with_filters_and_bounded_pagination(): void
    {
        [$tenant, $token, $customer, $firstBranch] = $this->customerContext();
        $secondBranch = Branch::query()->create(['tenant_id' => $tenant, 'name' => 'Airport', 'is_active' => true]);
        $otherCustomer = $this->customer($tenant, 'Other');
        $visible = $this->order($tenant, $firstBranch->id, $customer, 'ORD-002', 'paid', 'paid', '20.50', '2026-09-08 12:00:00');
        $this->order($tenant, $firstBranch->id, $customer, 'ORD-001', 'draft', 'unpaid', '15.00', '2026-09-07 12:00:00');
        $this->order($tenant, $firstBranch->id, $otherCustomer, 'ORD-OTHER', 'paid', 'paid', '99.00', '2026-09-09 12:00:00');
        $this->order($tenant, $secondBranch->id, $customer, 'ORD-BRANCH', 'paid', 'paid', '88.00', '2026-09-09 12:00:00');

        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$customer}/orders?status=paid&paymentStatus=paid&from=2026-09-08&to=2026-09-08&perPage=1&page=1")
            ->assertOk()
            ->assertJsonPath('data.0.id', $visible)
            ->assertJsonPath('data.0.orderNumber', 'ORD-002')
            ->assertJsonPath('data.0.branch.name', 'Main')
            ->assertJsonPath('data.0.total.amount', '20.50')
            ->assertJsonPath('data.0.total.currency', 'SYP')
            ->assertJsonPath('meta.currentPage', 1)
            ->assertJsonPath('meta.perPage', 1)
            ->assertJsonPath('meta.total', 1);
    }

    public function test_it_enforces_customer_tenant_ownership_branch_access_and_validates_query_input(): void
    {
        [$tenant, $token, $customer, $branch] = $this->customerContext(role: 'manager');
        $foreignTenant = $this->tenant('foreign');
        $foreignCustomer = $this->customer($foreignTenant, 'Foreign');
        $restrictedBranch = Branch::query()->create(['tenant_id' => $tenant, 'name' => 'Restricted', 'is_active' => true]);
        $this->order($tenant, $restrictedBranch->id, $customer, 'ORD-HIDDEN', 'paid', 'paid', '10.00', '2026-09-08 12:00:00');

        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$customer}/orders")->assertOk()->assertJsonCount(0, 'data');
        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$foreignCustomer}/orders")->assertNotFound();
        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$customer}/orders?branchId={$restrictedBranch->id}")->assertUnprocessable();
        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$customer}/orders?status=unknown")->assertUnprocessable();
        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$customer}/orders?paymentStatus=unknown")->assertUnprocessable();
        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$customer}/orders?from=2026-09-10&to=2026-09-01")->assertUnprocessable();
        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$customer}/orders?perPage=101")->assertUnprocessable();
    }

    public function test_same_order_number_in_different_permitted_branches_is_not_a_duplicate_query_row(): void
    {
        [$tenant, $token, $customer, $firstBranch] = $this->customerContext();
        $secondBranch = Branch::query()->create(['tenant_id' => $tenant, 'name' => 'Airport', 'is_active' => true]);
        $firstId = $this->order($tenant, $firstBranch->id, $customer, 'ORD-SHARED', 'paid', 'paid', '20.00', '2026-09-08 12:00:00');
        $secondId = $this->order($tenant, $secondBranch->id, $customer, 'ORD-SHARED', 'held', 'unpaid', '15.00', '2026-09-07 12:00:00');

        $response = $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$customer}/orders")->assertOk();

        $rows = collect($response->json('data'))->where('orderNumber', 'ORD-SHARED')->values();
        $this->assertCount(2, $rows);
        $this->assertSame([$firstId, $secondId], $rows->pluck('id')->sort()->values()->all());
        $this->assertSame([$firstBranch->id, $secondBranch->id], $rows->pluck('branch.id')->sort()->values()->all());
    }

    private function customerContext(string $role = 'owner'): array
    {
        $tenant = $this->tenant('orders');
        $branch = Branch::query()->create(['tenant_id' => $tenant, 'name' => 'Main', 'is_active' => true]);
        $user = $this->user($tenant, $role);
        if ($role === 'manager') DB::table('customer_role_permissions')->insert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => 'customer.manage', 'created_at' => now(), 'updated_at' => now()]);
        if ($role !== 'owner') $user->branches()->attach($branch->id, ['tenant_id' => $tenant]);
        return [$tenant, $this->authenticateTenantUser($tenant, $user), $this->customer($tenant, 'Customer'), $branch];
    }

    private function tenant(string $name): int { return (int) DB::table('tenants')->insertGetId(['name' => $name, 'slug' => $name.'-'.uniqid(), 'currency' => 'SYP', 'created_at' => now(), 'updated_at' => now()]); }
    private function user(int $tenant, string $role): User { return User::query()->create(['tenant_id' => $tenant, 'name' => $role, 'email' => $role.'-'.uniqid().'@example.test', 'password' => 'password', 'role' => $role, 'is_active' => true, 'must_change_password' => false]); }
    private function customer(int $tenant, string $name): int { return (int) DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'normalized_name' => strtolower($name), 'customer_number' => 'C-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]); }
    private function order(int $tenant, int $branch, int $customer, string $number, string $status, string $paymentStatus, string $total, string $created): int { return (int) DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'customer_id' => $customer, 'order_number' => $number, 'status' => $status, 'payment_status' => $paymentStatus, 'total' => $total, 'created_at' => $created, 'updated_at' => $created]); }
}
