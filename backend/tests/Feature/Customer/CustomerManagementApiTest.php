<?php

namespace Tests\Feature\Customer;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerManagementApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authorized_admin_can_create_name_only_customer_and_update_profile(): void
    {
        $tenant = $this->tenant('management');
        $owner = $this->user($tenant, 'owner');
        $token = $this->authenticateTenantUser($tenant, $owner);

        $created = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => '  Maria   Haddad  '])->assertCreated();
        $created->assertJsonPath('data.name', 'Maria Haddad')->assertJsonPath('data.customerNumber', 'C-000001')->assertJsonPath('data.status', 'active');
        $id = $created->json('data.id');
        $this->assertNotNull($created->json('data.createdAt'));
        $this->assertNotNull($created->json('data.updatedAt'));

        $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers/'.$id)->assertOk()->assertJsonPath('data.customerNumber', 'C-000001');
        $this->withToken($token)->putJson('/api/v1/admin/customer-management/customers/'.$id, ['name' => 'Maria Updated', 'email' => 'maria@example.test', 'birthDate' => '1990-01-02', 'notes' => 'Preferred customer'])->assertOk()->assertJsonPath('data.name', 'Maria Updated')->assertJsonPath('data.customerNumber', 'C-000001');
        $this->assertDatabaseHas('customers', ['id' => $id, 'tenant_id' => $tenant, 'customer_number' => 'C-000001', 'phone' => null]);
        $audit = DB::table('activity_logs')->where('tenant_id', $tenant)->where('entity_type', 'customer')->latest('id')->first();
        $this->assertNotNull($audit);
        $this->assertStringNotContainsString('maria@example.test', (string) $audit->after_state);
        $this->assertStringNotContainsString('Preferred customer', (string) $audit->after_state);
    }

    public function test_prohibited_identity_fields_and_invalid_profile_leave_no_partial_customer(): void
    {
        $tenant = $this->tenant('validation');
        $owner = $this->user($tenant, 'owner');
        $token = $this->authenticateTenantUser($tenant, $owner);

        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => '', 'customerNumber' => 'C-999999', 'tenantId' => $tenant])->assertUnprocessable();
        $this->assertSame(0, DB::table('customers')->where('tenant_id', $tenant)->count());
    }

    public function test_create_and_update_replace_supplied_active_group_memberships_atomically(): void
    {
        $tenant = $this->tenant('aggregate-memberships');
        $token = $this->authenticateTenantUser($tenant, $this->user($tenant, 'owner'));
        $firstGroup = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'First'])->assertCreated()->json('data.id');
        $secondGroup = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Second'])->assertCreated()->json('data.id');

        $customer = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'Grouped', 'groupIds' => [$firstGroup]])->assertCreated()->json('data.id');
        $this->assertDatabaseHas('customer_group_memberships', ['tenant_id' => $tenant, 'customer_id' => $customer, 'customer_group_id' => $firstGroup]);

        $this->withToken($token)->putJson('/api/v1/admin/customer-management/customers/'.$customer, ['groupIds' => [$secondGroup]])->assertOk();
        $this->assertDatabaseMissing('customer_group_memberships', ['tenant_id' => $tenant, 'customer_id' => $customer, 'customer_group_id' => $firstGroup]);
        $this->assertDatabaseHas('customer_group_memberships', ['tenant_id' => $tenant, 'customer_id' => $customer, 'customer_group_id' => $secondGroup]);
    }

    public function test_foreign_customer_is_not_disclosed_and_unpermitted_manager_is_denied(): void
    {
        $tenant = $this->tenant('one');
        $foreignTenant = $this->tenant('two');
        $owner = $this->user($foreignTenant, 'owner');
        $manager = $this->user($tenant, 'manager');
        $foreignToken = $this->authenticateTenantUser($foreignTenant, $owner);
        $managerToken = $this->authenticateTenantUser($tenant, $manager);
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $foreignTenant, 'name' => 'Foreign', 'customer_number' => 'C-000001', 'normalized_name' => 'foreign', 'created_at' => now(), 'updated_at' => now()]);

        $this->withToken($managerToken)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'Denied'])->assertForbidden();
        $this->withToken($foreignToken)->getJson('/api/v1/admin/customer-management/customers/'.$customer)->assertOk();
        $this->assertNotSame($tenant, (int) DB::table('customers')->where('id', $customer)->value('tenant_id'));
    }

    public function test_lifecycle_matrix_is_idempotent_and_preserves_related_history(): void
    {
        $tenant = $this->tenant('lifecycle');
        $owner = $this->user($tenant, 'owner');
        $token = $this->authenticateTenantUser($tenant, $owner);
        $created = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'Lifecycle', 'phones' => [['rawNumber' => '091234567', 'isPrimary' => true]]])->assertCreated();
        $id = $created->json('data.id');
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers/'.$id.'/deactivate')->assertOk()->assertJsonPath('data.status', 'inactive');
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers/'.$id.'/deactivate')->assertOk()->assertJsonPath('data.status', 'inactive');
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers/'.$id.'/activate')->assertOk()->assertJsonPath('data.status', 'active');
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers/'.$id.'/archive')->assertOk()->assertJsonPath('data.status', 'archived');
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers/'.$id.'/activate')->assertUnprocessable()->assertJsonPath('code', 'CUSTOMER_INVALID_TRANSITION');
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers/'.$id.'/restore')->assertOk()->assertJsonPath('data.status', 'inactive');
        $this->assertDatabaseHas('customer_phones', ['customer_id' => $id, 'raw_number' => '091234567']);
        $this->withToken($token)->getJson('/api/v1/customers')->assertOk()->assertJsonCount(0, 'data');
    }

    private function tenant(string $name): int
    {
        return (int) DB::table('tenants')->insertGetId(['name' => $name, 'slug' => $name.'-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
    }

    private function user(int $tenant, string $role): User
    {
        return User::query()->create(['tenant_id' => $tenant, 'name' => $role, 'email' => $role.'-'.uniqid().'@example.test', 'password' => 'password', 'role' => $role, 'is_active' => true, 'must_change_password' => false]);
    }
}
