<?php

namespace Tests\Feature\Customer;

use App\Models\Branch;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerOverviewApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_returns_authoritative_summary_and_five_most_recent_visible_orders(): void
    {
        [$tenant, $token, $customer, $branch] = $this->context();
        $visible = $this->order($tenant, $branch->id, $customer, 'ORD-NEW', 'paid', 'paid', '20.50', '2026-09-08 12:00:00');
        $refunded = $this->order($tenant, $branch->id, $customer, 'ORD-REFUND', 'paid', 'partially_refunded', '10.00', '2026-09-07 12:00:00');
        DB::table('payment_refunds')->insert(['tenant_id' => $tenant, 'branch_id' => $branch->id, 'order_id' => $refunded, 'refund_number' => 'R-'.uniqid(), 'type' => 'partial', 'amount' => '3.00', 'status' => 'completed', 'refunded_at' => '2026-09-08 13:00:00', 'created_at' => now(), 'updated_at' => now()]);
        $this->order($tenant, $branch->id, $customer, 'ORD-DRAFT', 'draft', 'unpaid', '99.00', '2026-09-06 12:00:00');
        foreach (range(1, 4) as $index) {
            $this->order($tenant, $branch->id, $customer, "ORD-OLD-$index", 'paid', 'paid', '1.00', "2026-09-0{$index} 12:00:00");
        }

        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/$customer/overview")
            ->assertOk()
            ->assertJsonPath('data.summary.totalOrders', 6)
            ->assertJsonPath('data.summary.totalSpending.amount', '31.50')
            ->assertJsonPath('data.summary.totalSpending.currency', 'SYP')
            ->assertJsonPath('data.summary.averageOrderValue.amount', '5.25')
            ->assertJsonPath('data.summary.lastOrderAt', '2026-09-08T12:00:00.000000Z')
            ->assertJsonPath('data.recentOrders.0.id', $visible)
            ->assertJsonCount(5, 'data.recentOrders');
    }

    public function test_it_keeps_overview_tenant_customer_and_branch_scoped(): void
    {
        [$tenant, $token, $customer, $branch] = $this->context(role: 'manager');
        $restricted = Branch::query()->create(['tenant_id' => $tenant, 'name' => 'Restricted', 'currency' => 'USD', 'is_active' => true]);
        $other = $this->customer($tenant, 'Other');
        $foreignTenant = $this->tenant('foreign');
        $foreign = $this->customer($foreignTenant, 'Foreign');
        $this->order($tenant, $restricted->id, $customer, 'ORD-HIDDEN', 'paid', 'paid', '50.00', '2026-09-08 12:00:00');
        $this->order($tenant, $branch->id, $other, 'ORD-OTHER', 'paid', 'paid', '50.00', '2026-09-08 12:00:00');

        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/$customer/overview")
            ->assertOk()
            ->assertJsonPath('data.summary.totalOrders', 0)
            ->assertJsonPath('data.summary.totalSpending', null)
            ->assertJsonCount(0, 'data.recentOrders');
        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/$foreign/overview")->assertNotFound();
    }

    private function context(string $role = 'owner'): array
    {
        $tenant = $this->tenant('overview');
        $branch = Branch::query()->create(['tenant_id' => $tenant, 'name' => 'Main', 'currency' => 'SYP', 'is_active' => true]);
        $user = User::query()->create(['tenant_id' => $tenant, 'name' => $role, 'email' => "$role-".uniqid().'@example.test', 'password' => 'password', 'role' => $role, 'is_active' => true, 'must_change_password' => false]);
        if ($role === 'manager') {
            DB::table('customer_role_permissions')->insert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => 'customer.manage', 'created_at' => now(), 'updated_at' => now()]);
            $user->branches()->attach($branch->id, ['tenant_id' => $tenant]);
        }
        return [$tenant, $this->authenticateTenantUser($tenant, $user), $this->customer($tenant, 'Customer'), $branch];
    }

    private function tenant(string $name): int { return (int) DB::table('tenants')->insertGetId(['name' => $name, 'slug' => $name.'-'.uniqid(), 'currency' => 'SYP', 'created_at' => now(), 'updated_at' => now()]); }
    private function customer(int $tenant, string $name): int { return (int) DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'normalized_name' => strtolower($name), 'customer_number' => 'C-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]); }
    private function order(int $tenant, int $branch, int $customer, string $number, string $status, string $paymentStatus, string $total, string $created): int { return (int) DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'customer_id' => $customer, 'order_number' => $number, 'status' => $status, 'payment_status' => $paymentStatus, 'total' => $total, 'created_at' => $created, 'updated_at' => $created]); }
}
