<?php

namespace Tests\Feature\Customer;

use App\Domain\Customer\CustomerAccess;
use App\Domain\Customer\CustomerDomainException;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerAuthorizationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_domain_errors_expose_stable_codes_and_statuses(): void
    {
        foreach ([
            [CustomerDomainException::permissionDenied(), 'CUSTOMER_PERMISSION_DENIED', 403],
            [CustomerDomainException::notOperationallyEligible(), 'CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE', 422],
            [CustomerDomainException::invalidTransition(), 'CUSTOMER_INVALID_TRANSITION', 422],
            [CustomerDomainException::numberConflict(), 'CUSTOMER_NUMBER_CONFLICT', 409],
            [CustomerDomainException::writeConflict(), 'CUSTOMER_WRITE_CONFLICT', 409],
        ] as [$exception, $code, $status]) {
            $this->assertSame($code, $exception->domainCode);
            $this->assertSame($status, $exception->status);
        }
    }

    public function test_owner_and_permitted_manager_can_administer_but_employee_cannot(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Access Tenant', 'slug' => 'access-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $owner = $this->user($tenant, 'owner');
        $manager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'employee');
        $access = app(CustomerAccess::class);

        $this->assertTrue($access->allows($this->request($tenant, $owner), 'customer.manage'));
        $this->assertFalse($access->allows($this->request($tenant, $manager), 'customer.manage'));
        $this->assertTrue($access->allows($this->request($tenant, $employee), 'customer.lookup'));
        $this->assertTrue($access->allows($this->request($tenant, $employee), 'customer.quick_create'));

        DB::table('customer_role_permissions')->insert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => 'customer.manage', 'created_at' => now(), 'updated_at' => now()]);
        $this->assertTrue($access->allows($this->request($tenant, $manager), 'customer.manage'));
    }

    public function test_owner_only_manager_permission_endpoint_is_idempotent_and_tenant_scoped(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Permission Tenant', 'slug' => 'permission-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $otherTenant = DB::table('tenants')->insertGetId(['name' => 'Other Permission Tenant', 'slug' => 'permission-other-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $owner = $this->user($tenant, 'owner');
        $manager = $this->user($tenant, 'manager');
        $ownerToken = $this->authenticateTenantUser($tenant, $owner);
        $managerToken = $this->authenticateTenantUser($tenant, $manager);

        $this->withToken($ownerToken)->getJson('/api/v1/admin/customer-management/role-permissions/manager')->assertOk()->assertJsonPath('data.enabled', false);
        $this->withToken($ownerToken)->putJson('/api/v1/admin/customer-management/role-permissions/manager', ['enabled' => true])->assertOk()->assertJsonPath('data.enabled', true);
        $this->withToken($ownerToken)->putJson('/api/v1/admin/customer-management/role-permissions/manager', ['enabled' => true])->assertOk()->assertJsonPath('data.enabled', true);
        $this->withToken($managerToken)->getJson('/api/v1/admin/customer-management/role-permissions/manager')->assertForbidden();
        $this->assertDatabaseHas('customer_role_permissions', ['tenant_id' => $tenant, 'role' => 'manager', 'permission' => 'customer.manage']);
        $this->assertDatabaseMissing('customer_role_permissions', ['tenant_id' => $otherTenant, 'role' => 'manager', 'permission' => 'customer.manage']);
    }

    public function test_authenticated_self_capability_exposes_only_current_tenant_customer_management_access(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Capability Tenant', 'slug' => 'capability-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $owner = $this->user($tenant, 'owner');
        $grantedManager = $this->user($tenant, 'manager');
        $ungrantedManager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'employee');
        DB::table('customer_role_permissions')->insert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => 'customer.manage', 'created_at' => now(), 'updated_at' => now()]);

        $this->withToken($this->authenticateTenantUser($tenant, $owner))
            ->getJson('/api/v1/customer-management/capabilities')
            ->assertOk()->assertJsonPath('data.customer.manage', true);
        $this->withToken($this->authenticateTenantUser($tenant, $grantedManager))
            ->getJson('/api/v1/customer-management/capabilities')
            ->assertOk()->assertJsonPath('data.customer.manage', true);

        DB::table('customer_role_permissions')->where('tenant_id', $tenant)->delete();
        $this->withToken($this->authenticateTenantUser($tenant, $ungrantedManager))
            ->getJson('/api/v1/customer-management/capabilities')
            ->assertOk()->assertJsonPath('data.customer.manage', false);
        $this->withToken($this->authenticateTenantUser($tenant, $employee))
            ->getJson('/api/v1/customer-management/capabilities')
            ->assertOk()->assertJsonPath('data.customer.manage', false);
    }

    public function test_customer_audit_state_never_copies_profile_or_phone_pii(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Audit Tenant', 'slug' => 'audit-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $owner = $this->user($tenant, 'owner');
        $token = $this->authenticateTenantUser($tenant, $owner);
        $created = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'PII Customer', 'email' => 'private@example.test', 'birthDate' => '1990-01-01', 'notes' => 'private note', 'phones' => [['rawNumber' => '+963 991234567', 'isPrimary' => true]]])->assertCreated();
        $id = $created->json('data.id');
        $this->withToken($token)->putJson('/api/v1/admin/customer-management/customers/'.$id, ['notes' => 'updated private note'])->assertOk();
        $this->withToken($token)->postJson('/api/v1/customers/quick-create', ['name' => 'Quick PII', 'phone' => '091234568'])->assertCreated();
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers/'.$id.'/archive')->assertOk();
        foreach (DB::table('activity_logs')->where('tenant_id', $tenant)->get(['before_state', 'after_state']) as $row) {
            $state = (string) $row->before_state.' '.(string) $row->after_state;
            foreach (['private@example.test', '1990-01-01', 'private note', 'updated private note', '991234567', '091234568'] as $pii) {
                $this->assertStringNotContainsString($pii, $state);
            }
        }
    }

    private function request(int $tenant, User $user): Request
    {
        $request = Request::create('/api/v1/admin/customer-management/customers', 'GET');
        $request->attributes->set('tenant_id', $tenant);
        $request->attributes->set('auth_user', $user);

        return $request;
    }

    private function user(int $tenant, string $role): User
    {
        return User::query()->create(['tenant_id' => $tenant, 'name' => $role, 'email' => $role.'-'.uniqid().'@example.test', 'password' => 'password', 'role' => $role, 'is_active' => true, 'must_change_password' => false]);
    }
}
