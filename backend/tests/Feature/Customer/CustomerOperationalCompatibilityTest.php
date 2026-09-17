<?php

namespace Tests\Feature\Customer;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerOperationalCompatibilityTest extends TestCase
{
    use RefreshDatabase;

    public function test_operational_lookup_preserves_envelope_fields_and_excludes_inactive_or_archived_customers(): void
    {
        $tenant = $this->tenant('operational');
        $owner = $this->user($tenant, 'owner');
        $token = $this->authenticateTenantUser($tenant, $owner);
        $this->customer($tenant, 'Active Customer', 'C-000001', true, null, '091234567');
        $this->customer($tenant, 'Inactive Customer', 'C-000002', false, null, '091234568');
        $this->customer($tenant, 'Archived Customer', 'C-000003', false, now(), '091234569');

        $response = $this->withToken($token)->getJson('/api/v1/customers?search=Active')->assertOk();
        $response->assertJsonStructure(['data' => [['id', 'name', 'phone', 'email', 'totalSpent', 'visitsCount', 'loyaltyPoints', 'tier']]]);
        $this->assertSame(['Active Customer'], collect($response->json('data'))->pluck('name')->all());
    }

    public function test_employee_quick_create_requires_exactly_one_phone_and_records_active_primary_customer(): void
    {
        $tenant = $this->tenant('quick');
        $employee = $this->user($tenant, 'employee');
        $token = $this->authenticateTenantUser($tenant, $employee);

        $created = $this->withToken($token)->postJson('/api/v1/customers/quick-create', ['name' => 'Quick Customer', 'phone' => '+963 991234567'])->assertCreated();
        $id = $created->json('data.id');
        $created->assertJsonPath('data.status', 'active')->assertJsonPath('data.customerNumber', 'C-000001');
        $this->assertDatabaseHas('customer_phones', ['customer_id' => $id, 'is_primary' => true, 'raw_number' => '+963 991234567', 'validation_status' => 'valid']);
        $this->assertDatabaseHas('customers', ['id' => $id, 'phone' => '+963 991234567']);
        $this->assertSame(0, DB::table('customer_group_memberships')->where('customer_id', $id)->count());

        $emptyGroups = $this->withToken($token)->postJson('/api/v1/customers/quick-create', [
            'name' => 'Empty Groups Customer',
            'phone' => '+963 991234568',
            'groupIds' => [],
        ])->assertCreated();
        $this->assertSame(0, DB::table('customer_group_memberships')->where('customer_id', $emptyGroups->json('data.id'))->count());

        $this->withToken($token)->postJson('/api/v1/customers/quick-create', ['name' => 'Invalid', 'phone' => '091234567', 'phones' => [['rawNumber' => '091234568']]])->assertUnprocessable();
        $this->assertSame(2, DB::table('customers')->where('tenant_id', $tenant)->count());
    }

    public function test_quick_create_persists_notes_and_multiple_active_same_tenant_groups_atomically(): void
    {
        $tenant = $this->tenant('quick-groups');
        $owner = $this->user($tenant, 'owner');
        $employee = $this->user($tenant, 'employee');
        $ownerToken = $this->authenticateTenantUser($tenant, $owner);
        $employeeToken = $this->authenticateTenantUser($tenant, $employee);
        $firstGroup = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'VIP'])->assertCreated()->json('data.id');
        $secondGroup = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Regular'])->assertCreated()->json('data.id');

        $created = $this->withToken($employeeToken)->postJson('/api/v1/customers/quick-create', [
            'name' => 'Grouped Customer',
            'phone' => '0912 345-67',
            'notes' => 'Operational note',
            'groupIds' => [$secondGroup, $firstGroup],
        ])->assertCreated();

        $id = $created->json('data.id');
        $created->assertJsonPath('data.notes', 'Operational note');
        $this->assertSame(
            [$firstGroup, $secondGroup],
            DB::table('customer_group_memberships')->where('customer_id', $id)->orderBy('customer_group_id')->pluck('customer_group_id')->all(),
        );
        $this->assertDatabaseHas('customer_phones', [
            'customer_id' => $id,
            'normalized_number' => '091234567',
            'is_primary' => true,
        ]);
    }

    public function test_quick_create_rejects_duplicate_unknown_and_invalid_groups_without_partial_state(): void
    {
        $tenant = $this->tenant('quick-invalid');
        $owner = $this->user($tenant, 'owner');
        $employee = $this->user($tenant, 'employee');
        $ownerToken = $this->authenticateTenantUser($tenant, $owner);
        $employeeToken = $this->authenticateTenantUser($tenant, $employee);
        $group = $this->withToken($ownerToken)->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'VIP'])->assertCreated()->json('data.id');
        $foreignTenant = $this->tenant('quick-foreign');
        $foreignOwner = $this->user($foreignTenant, 'owner');
        $foreignGroup = $this->withToken($this->authenticateTenantUser($foreignTenant, $foreignOwner))->postJson('/api/v1/admin/customer-management/customer-groups', ['name' => 'Foreign'])->assertCreated()->json('data.id');

        foreach ([
            ['groupIds' => [$group, $group]],
            ['groupIds' => [$foreignGroup]],
            ['groupIds' => [999999999]],
            ['groupIds' => ['invalid']],
            ['unknown' => true],
        ] as $payload) {
            $this->withToken($employeeToken)->postJson('/api/v1/customers/quick-create', array_merge([
                'name' => 'Rejected Customer',
                'phone' => '091234567',
            ], $payload))->assertUnprocessable();
        }

        $this->assertSame(0, DB::table('customers')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('customer_phones')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('customer_group_memberships')->where('tenant_id', $tenant)->count());
    }

    private function tenant(string $name): int
    {
        return (int) DB::table('tenants')->insertGetId(['name' => $name, 'slug' => $name.'-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
    }

    private function user(int $tenant, string $role): User
    {
        return User::query()->create(['tenant_id' => $tenant, 'name' => $role, 'email' => $role.'-'.uniqid().'@example.test', 'password' => 'password', 'role' => $role, 'is_active' => true, 'must_change_password' => false]);
    }

    private function customer(int $tenant, string $name, string $number, bool $active, $deletedAt, string $phone): int
    {
        return (int) DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'customer_number' => $number, 'normalized_name' => mb_strtolower($name), 'phone' => $phone, 'is_active' => $active, 'deleted_at' => $deletedAt, 'created_at' => now(), 'updated_at' => now()]);
    }
}
