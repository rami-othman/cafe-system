<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class OrderListApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_order_list_returns_a_bounded_authoritative_summary(): void
    {
        [$tenant, $branch] = $this->context();
        $order = $this->order($tenant, $branch, 'SUMMARY-1', 'draft', 'dine_in', 10);
        $customer = (int) DB::table('customers')->insertGetId([
            'tenant_id' => $tenant,
            'customer_number' => 'CUST-SUMMARY-1',
            'name' => 'Summary Customer',
            'normalized_name' => 'summary customer',
            'phone' => '+963 900 000 001',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $table = (int) DB::table('cafe_tables')->insertGetId([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'name' => 'Table 7',
            'code' => 'T7',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('orders')->where('id', $order)->update([
            'customer_id' => $customer,
            'table_id' => $table,
        ]);

        $this->item($tenant, $order, 'First', '1.500', 1);
        $this->item($tenant, $order, 'Second', '2.000', 2);
        $deleted = $this->item($tenant, $order, 'Deleted', '9.000', 3);
        DB::table('order_items')->where('id', $deleted)->update(['deleted_at' => now()]);
        $this->item($tenant, $order, 'Third', '4.000', 4);
        $this->item($tenant, $order, 'Fourth', '5.000', 5);

        $this->getJson('/api/v1/orders?branchId='.$branch.'&perPage=25&page=1', $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.0.id', $order)
            ->assertJsonPath('data.0.orderNumber', 'SUMMARY-1')
            ->assertJsonPath('data.0.branchId', $branch)
            ->assertJsonPath('data.0.orderType', 'dine_in')
            ->assertJsonPath('data.0.status', 'draft')
            ->assertJsonPath('data.0.paymentStatus', 'unpaid')
            ->assertJsonPath('data.0.customer.id', $customer)
            ->assertJsonPath('data.0.customer.name', 'Summary Customer')
            ->assertJsonPath('data.0.table.id', $table)
            ->assertJsonPath('data.0.table.name', 'Table 7')
            ->assertJsonPath('data.0.itemCount', 12.5)
            ->assertJsonPath('data.0.itemPreview.0.name', 'First')
            ->assertJsonPath('data.0.itemPreview.1.name', 'Second')
            ->assertJsonPath('data.0.itemPreview.2.name', 'Third')
            ->assertJsonCount(3, 'data.0.itemPreview')
            ->assertJsonPath('data.0.totals.total', 10)
            ->assertJsonMissingPath('data.0.items')
            ->assertJsonMissingPath('data.0.payments')
            ->assertJsonMissingPath('data.0.refunds')
            ->assertJsonMissingPath('data.0.refundableAmount')
            ->assertJsonPath('meta.currentPage', 1)
            ->assertJsonPath('meta.lastPage', 1)
            ->assertJsonPath('meta.perPage', 25)
            ->assertJsonPath('meta.total', 1);
    }

    public function test_active_filter_is_applied_before_pagination_and_page_two_reaches_old_records(): void
    {
        [$tenant, $branch] = $this->context();
        $this->order($tenant, $branch, 'ACTIVE-OLD', 'draft', 'takeaway', 1, now()->subDays(2));
        for ($index = 1; $index <= 100; $index++) {
            $this->order($tenant, $branch, 'PAID-'.$index, 'paid', 'takeaway', 1, now()->subMinutes(100 - $index));
        }
        foreach (['held', 'completed', 'refunded', 'cancelled'] as $status) {
            $this->order($tenant, $branch, 'NOT-ACTIVE-'.$status, $status, 'takeaway', 1, now()->addMinutes(200));
        }

        $this->getJson('/api/v1/orders?branchId='.$branch.'&status=active&perPage=100&page=1', $this->headers($tenant))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.orderNumber', 'ACTIVE-OLD')
            ->assertJsonPath('meta.total', 1);

        for ($index = 1; $index <= 101; $index++) {
            $this->order($tenant, $branch, 'DRAFT-'.$index, 'draft', 'takeaway', 1, now()->addMinutes($index));
        }

        $this->getJson('/api/v1/orders?branchId='.$branch.'&status=draft&perPage=100&page=2', $this->headers($tenant))
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.currentPage', 2)
            ->assertJsonPath('meta.lastPage', 2)
            ->assertJsonPath('meta.total', 102);
    }

    public function test_held_dine_in_and_takeaway_filters_are_server_side(): void
    {
        [$tenant, $branch] = $this->context();
        $this->order($tenant, $branch, 'HELD', 'held', 'takeaway', 1);
        $this->order($tenant, $branch, 'DINE', 'draft', 'dine_in', 1);
        $this->order($tenant, $branch, 'TAKE', 'draft', 'takeaway', 1);

        $this->getJson('/api/v1/orders?branchId='.$branch.'&status=held', $this->headers($tenant))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.orderNumber', 'HELD');

        $this->getJson('/api/v1/orders?branchId='.$branch.'&orderType=dine_in', $this->headers($tenant))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.orderNumber', 'DINE');

        $this->getJson('/api/v1/orders?branchId='.$branch.'&orderType=takeaway', $this->headers($tenant))
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment(['orderNumber' => 'HELD'])
            ->assertJsonFragment(['orderNumber' => 'TAKE']);
    }

    public function test_order_list_keeps_tenant_and_branch_isolation(): void
    {
        [$tenant, $branch] = $this->context();
        $visible = $this->order($tenant, $branch, 'VISIBLE', 'draft', 'takeaway', 1);
        $restrictedBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $tenant,
            'name' => 'Restricted Orders Branch',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->order($tenant, $restrictedBranch, 'RESTRICTED', 'draft', 'takeaway', 1);
        $foreignTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Foreign Orders Tenant',
            'slug' => 'foreign-orders-tenant',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $foreignBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $foreignTenant,
            'name' => 'Foreign Orders Branch',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->order($foreignTenant, $foreignBranch, 'FOREIGN', 'draft', 'takeaway', 1);

        $this->getJson('/api/v1/orders?branchId='.$branch, $this->headers($tenant))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $visible);

        $this->getJson('/api/v1/orders?branchId='.$foreignBranch, $this->headers($tenant))
            ->assertUnprocessable();

        $user = User::query()->create([
            'tenant_id' => $tenant,
            'name' => 'Restricted Orders User',
            'email' => 'restricted-orders-'.uniqid().'@example.test',
            'password' => 'testing-password',
            'role' => 'cashier',
            'is_active' => true,
            'must_change_password' => false,
        ]);
        $user->branches()->attach($branch, ['tenant_id' => $tenant]);
        $restrictedHeaders = [
            'Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $user),
            'X-Tenant-Id' => (string) $tenant,
        ];

        $this->getJson('/api/v1/orders?branchId='.$restrictedBranch, $restrictedHeaders)
            ->assertForbidden();
    }

    public function test_order_list_query_count_does_not_grow_with_page_size(): void
    {
        [$tenant, $branch] = $this->context();
        for ($index = 1; $index <= 30; $index++) {
            $this->order($tenant, $branch, 'BOUND-'.$index, 'draft', 'takeaway', $index, now()->addMinutes($index));
        }

        $smallPageQueries = $this->listQueryCount($tenant, $branch, 5);
        $largePageQueries = $this->listQueryCount($tenant, $branch, 30);

        $this->assertLessThanOrEqual($smallPageQueries + 1, $largePageQueries);
    }

    public function test_order_detail_retains_refund_safety_fields(): void
    {
        [$tenant, $branch] = $this->context();
        $order = $this->order($tenant, $branch, 'DETAIL-REFUND', 'paid', 'takeaway', 20);
        DB::table('payments')->insert([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_id' => $order,
            'method' => 'cash',
            'amount' => 20,
            'currency' => 'SYP',
            'status' => 'completed',
            'paid_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->getJson('/api/v1/orders/'.$order, $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.refundedAmount', 0)
            ->assertJsonPath('data.refundableAmount', 20)
            ->assertJsonPath('data.refunds', []);
    }

    public function test_order_list_rejects_a_page_size_above_the_safe_maximum(): void
    {
        [$tenant, $branch] = $this->context();

        $this->getJson('/api/v1/orders?branchId='.$branch.'&perPage=101', $this->headers($tenant))
            ->assertUnprocessable();
    }

    private function context(): array
    {
        $tenant = (int) DB::table('tenants')->orderBy('id')->value('id');
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('is_active', true)->orderBy('id')->value('id');

        return [$tenant, $branch];
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }

    private function order(
        int $tenant,
        int $branch,
        string $number,
        string $status,
        string $type,
        float $total,
        mixed $createdAt = null,
    ): int {
        $createdAt ??= now();

        return (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_number' => $number,
            'type' => $type,
            'status' => $status,
            'payment_status' => $status === 'paid' ? 'paid' : 'unpaid',
            'total' => $total,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ]);
    }

    private function item(int $tenant, int $order, string $name, string $quantity, int $idOrder): int
    {
        return (int) DB::table('order_items')->insertGetId([
            'tenant_id' => $tenant,
            'order_id' => $order,
            'product_name' => $name,
            'quantity' => $quantity,
            'unit_price' => 1,
            'total' => $quantity,
            'status' => 'pending',
            'created_at' => now()->addSeconds($idOrder),
            'updated_at' => now()->addSeconds($idOrder),
        ]);
    }

    private function listQueryCount(int $tenant, int $branch, int $perPage): int
    {
        DB::flushQueryLog();
        DB::enableQueryLog();
        $this->getJson('/api/v1/orders?branchId='.$branch.'&perPage='.$perPage, $this->headers($tenant))->assertOk();
        $count = count(DB::getQueryLog());
        DB::disableQueryLog();

        return $count;
    }
}
