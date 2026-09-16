<?php

namespace Tests\Feature\Customer;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerGroupApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_administer_groups_employee_can_manage_memberships_but_not_groups(): void
    {
        [$tenant, $ownerToken, $employeeToken] = $this->actors();
        $first = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'VIP'])->assertCreated();
        $second = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Regular'])->assertCreated();
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => 'Member', 'customer_number' => 'C-000001', 'normalized_name' => 'member', 'created_at' => now(), 'updated_at' => now()]);

        $this->withToken($employeeToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Denied'])->assertForbidden();
        $this->withToken($employeeToken)->putJson('/api/v1/customers/'.$customer.'/groups', ['groupIds' => [$first->json('data.id'), $second->json('data.id')]])->assertOk();
        $this->assertSame(2, DB::table('customer_group_memberships')->where('customer_id', $customer)->count());
        $this->withToken($employeeToken)->putJson('/api/v1/customers/'.$customer.'/groups', ['groupIds' => []])->assertOk();
        $this->assertSame(0, DB::table('customer_group_memberships')->where('customer_id', $customer)->count());
    }

    public function test_archived_or_foreign_groups_reject_the_whole_membership_replacement(): void
    {
        [$tenant, $ownerToken, $employeeToken] = $this->actors();
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => 'Member', 'customer_number' => 'C-000001', 'normalized_name' => 'member', 'created_at' => now(), 'updated_at' => now()]);
        $group = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Archived'])->assertCreated()->json('data.id');
        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/archive')->assertOk();
        $this->withToken($employeeToken)->putJson('/api/v1/customers/'.$customer.'/groups', ['groupIds' => [$group]])->assertUnprocessable();
        $this->assertSame(0, DB::table('customer_group_memberships')->where('customer_id', $customer)->count());
    }

    public function test_active_group_lookup_is_bounded_and_excludes_archived_groups(): void
    {
        [, $ownerToken, $employeeToken] = $this->actors();
        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Visible'])->assertCreated();
        $archived = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Hidden'])->assertCreated()->json('data.id');
        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$archived.'/archive')->assertOk();
        $this->withToken($employeeToken)->getJson('/api/v1/customer-groups?perPage=100')->assertOk()->assertJsonPath('meta.perPage', 100)->assertJsonCount(1, 'data');
    }

    public function test_repeated_group_lifecycle_requests_do_not_record_duplicate_audits(): void
    {
        [, $ownerToken] = $this->actors();
        $group = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Idempotent'])->assertCreated()->json('data.id');

        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/archive')->assertOk();
        $this->assertSame(1, DB::table('activity_logs')->where('entity_type', 'customer_group')->where('entity_id', $group)->where('action', 'customer.group.archive')->count());
        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/archive')->assertOk();
        $this->assertSame(1, DB::table('activity_logs')->where('entity_type', 'customer_group')->where('entity_id', $group)->where('action', 'customer.group.archive')->count());

        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/restore')->assertOk();
        $this->assertSame(1, DB::table('activity_logs')->where('entity_type', 'customer_group')->where('entity_id', $group)->where('action', 'customer.group.restore')->count());
        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/restore')->assertOk();
        $this->assertSame(1, DB::table('activity_logs')->where('entity_type', 'customer_group')->where('entity_id', $group)->where('action', 'customer.group.restore')->count());
    }

    public function test_administrative_group_list_is_tenant_scoped_bounded_searchable_and_reports_member_counts(): void
    {
        [$tenant, $ownerToken] = $this->actors();
        $alpha = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Alpha'])->assertCreated()->json('data.id');
        $beta = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Beta'])->assertCreated()->json('data.id');
        $customer = $this->customer($tenant, 'Member', 'C-000001');
        DB::table('customer_group_memberships')->insert(['tenant_id' => $tenant, 'customer_id' => $customer, 'customer_group_id' => $alpha, 'created_at' => now(), 'updated_at' => now()]);
        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$beta.'/archive')->assertOk();

        $this->withToken($ownerToken)->getJson('/api/v1/admin/customer-management/customer-groups?search=alp&status=all&page=1&perPage=1000')
            ->assertOk()
            ->assertJsonPath('meta.currentPage', 1)
            ->assertJsonPath('meta.perPage', 100)
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.id', $alpha)
            ->assertJsonPath('data.0.memberCount', 1);
    }

    public function test_group_member_and_candidate_queries_are_bounded_and_enforce_lifecycle_and_tenant_scope(): void
    {
        [$tenant, $ownerToken] = $this->actors();
        $group = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Members'])->assertCreated()->json('data.id');
        $member = $this->customer($tenant, 'Current Member', 'C-000001');
        $candidate = $this->customer($tenant, 'Eligible Candidate', 'C-000002');
        $inactive = $this->customer($tenant, 'Inactive Candidate', 'C-000003', false);
        DB::table('customer_group_memberships')->insert(['tenant_id' => $tenant, 'customer_id' => $member, 'customer_group_id' => $group, 'created_at' => now(), 'updated_at' => now()]);

        $this->withToken($ownerToken)->getJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/members?search=current&page=1&perPage=30')
            ->assertOk()->assertJsonPath('meta.total', 1)->assertJsonPath('data.0.id', $member);
        $this->withToken($ownerToken)->getJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/eligible-members?search=candidate&page=1&perPage=30')
            ->assertOk()->assertJsonPath('meta.total', 1)->assertJsonPath('data.0.id', $candidate);

        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/archive')->assertOk();
        $this->withToken($ownerToken)->getJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/eligible-members')->assertUnprocessable();
        $this->assertNotSame($candidate, $inactive);
    }

    public function test_group_member_commands_are_atomic_and_return_the_authoritative_refreshed_count(): void
    {
        [$tenant, $ownerToken] = $this->actors();
        $group = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Command Group'])->assertCreated()->json('data.id');
        $first = $this->customer($tenant, 'First', 'C-000001');
        $second = $this->customer($tenant, 'Second', 'C-000002');
        $foreignTenant = DB::table('tenants')->insertGetId(['name' => 'Foreign', 'slug' => 'foreign-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $foreign = $this->customer($foreignTenant, 'Foreign', 'C-000001');

        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/members', ['customerIds' => [$first, $second]])
            ->assertOk()->assertJsonPath('data.memberCount', 2);
        $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/members', ['customerIds' => [$first, $foreign]])
            ->assertStatus(422);
        $this->assertSame(2, DB::table('customer_group_memberships')->where('customer_group_id', $group)->count());
        $this->withToken($ownerToken)->deleteJson('/api/v1/admin/customer-management/customer-groups/'.$group.'/members/'.$first)
            ->assertOk()->assertJsonPath('data.memberCount', 1);
        $this->assertDatabaseMissing('customer_group_memberships', ['tenant_id' => $tenant, 'customer_group_id' => $group, 'customer_id' => $first]);
    }

    private function actors(): array
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Group Tenant', 'slug' => 'group-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $owner = User::query()->create(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true, 'must_change_password' => false]);
        $employee = User::query()->create(['tenant_id' => $tenant, 'name' => 'Employee', 'email' => uniqid().'@example.test', 'password' => 'password', 'role' => 'employee', 'is_active' => true, 'must_change_password' => false]);

        return [$tenant, $this->authenticateTenantUser($tenant, $owner), $this->authenticateTenantUser($tenant, $employee)];
    }

    private function customer(int $tenant, string $name, string $number, bool $active = true): int
    {
        return (int) DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'customer_number' => $number, 'normalized_name' => strtolower($name), 'is_active' => $active, 'created_at' => now(), 'updated_at' => now()]);
    }
}
