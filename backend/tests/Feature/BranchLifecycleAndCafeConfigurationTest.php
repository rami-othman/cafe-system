<?php

namespace Tests\Feature;

use App\Models\Branch;
use App\Models\Tenant;
use App\Models\User;
use App\Services\BranchAccessService;
use App\Services\UserBranchAssignmentService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class BranchLifecycleAndCafeConfigurationTest extends TestCase
{
    use RefreshDatabase;

    public function test_inactive_branches_stop_operational_access_without_removing_assignments_or_history(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('lifecycle', 'owner');
        $manager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'cashier');
        $assignments = app(UserBranchAssignmentService::class);
        $assignments->assign($manager, $branch);
        $assignments->assign($employee, $branch);
        $access = app(BranchAccessService::class);
        $foreignTenant = Tenant::query()->create([
            'name' => 'Foreign lifecycle tenant',
            'slug' => 'foreign-lifecycle-'.uniqid(),
            'status' => 'active',
        ]);
        $foreignBranch = Branch::query()->create([
            'tenant_id' => $foreignTenant->id,
            'name' => 'Foreign branch',
            'timezone' => 'UTC',
            'currency' => 'SYP',
            'is_active' => true,
        ]);
        $deletedBranch = Branch::query()->create([
            'tenant_id' => $tenant->id,
            'name' => 'Deleted branch',
            'timezone' => 'UTC',
            'currency' => 'SYP',
            'is_active' => true,
        ]);
        $deletedBranch->delete();
        $now = now();
        $orderId = DB::table('orders')->insertGetId([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'order_number' => 'HISTORICAL-'.uniqid(),
            'type' => 'takeaway',
            'status' => 'paid',
            'payment_status' => 'paid',
            'subtotal' => 10,
            'tax_total' => 0,
            'total' => 10,
            'opened_at' => $now,
            'closed_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $this->assertTrue($access->canAccessBranch($owner, $branch));
        $this->assertTrue($access->canAccessBranch($manager, $branch));
        $this->assertFalse($access->canAccessBranch($owner, $foreignBranch));
        $this->assertFalse($access->canAccessBranch($owner, $deletedBranch));
        $branch->update(['is_active' => false]);

        $this->assertDatabaseHas('user_branches', ['user_id' => $employee->id, 'branch_id' => $branch->id]);
        $this->assertDatabaseHas('orders', ['id' => $orderId, 'branch_id' => $branch->id]);
        $this->assertFalse($access->canAccessBranch($owner, $branch->fresh()));
        $this->assertFalse($access->canAccessBranch($manager, $branch->fresh()));
        $this->assertSame([], $access->accessibleBranchIds($employee));

        $ownerToken = $this->authenticateTenantUser($tenant->id, $owner);
        $employeeToken = $this->authenticateTenantUser($tenant->id, $employee);
        $this->withToken($ownerToken)->getJson('/api/v1/branches')->assertOk()->assertJsonCount(0, 'data');
        $this->withToken($employeeToken)->getJson('/api/v1/branches')->assertOk()->assertJsonCount(0, 'data');
        $this->withToken($ownerToken)->getJson("/api/v1/pos/state?branchId={$branch->id}")->assertNotFound();
        $this->withToken($ownerToken)->getJson("/api/v1/pos/state?branchId={$foreignBranch->id}")->assertUnprocessable();
        $this->withToken($ownerToken)->getJson("/api/v1/pos/state?branchId={$deletedBranch->id}")->assertUnprocessable();
        $this->withToken($employeeToken)->postJson('/api/v1/shifts/current', ['branchId' => $branch->id, 'openingCash' => 0])->assertNotFound();

        try {
            $assignments->assign($employee, $branch->fresh());
            $this->fail('Inactive branches must not be assignable.');
        } catch (DomainException) {
            // Expected: retained historical assignment cannot be replaced with an inactive one.
        }
    }

    public function test_inactive_branch_is_rejected_before_new_order_creation(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = User::query()->where('tenant_id', $tenantId)->where('role', 'owner')->firstOrFail();
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
        DB::table('branches')->where('id', $branchId)->update(['is_active' => false]);

        $this->withToken($this->authenticateTenantUser($tenantId, $owner))
            ->postJson('/api/v1/orders', ['branchId' => $branchId])
            ->assertNotFound();
    }

    public function test_owner_can_administrate_same_tenant_branches_and_sensitive_fields_are_rejected(): void
    {
        [$tenant, $active, $owner] = $this->tenantBranchUser('configuration', 'owner');
        $inactive = Branch::query()->create([
            'tenant_id' => $tenant->id,
            'name' => 'Inactive branch',
            'timezone' => 'Asia/Damascus',
            'currency' => 'SYP',
            'is_active' => false,
        ]);
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->getJson('/api/v1/cafe-configuration/branches')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment(['id' => $inactive->id, 'isActive' => false]);

        $created = $this->withToken($token)->postJson('/api/v1/cafe-configuration/branches', [
            'name' => '  New branch  ',
            'address' => 'Main Street',
            'phone' => '+963 11 123 4567',
            'timezone' => 'Asia/Damascus',
        ])->assertCreated()
            ->assertJsonPath('data.name', 'New branch')
            ->assertJsonPath('data.currency', 'SYP')
            ->assertJsonPath('data.isActive', true);
        $branchId = $created->json('data.id');
        $this->assertDatabaseHas('branches', ['id' => $branchId, 'tenant_id' => $tenant->id, 'currency' => 'SYP', 'is_active' => true]);

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchId}", [
            'name' => 'Renamed branch',
            'address' => null,
            'phone' => '123',
            'timezone' => 'UTC',
        ])->assertOk()->assertJsonPath('data.name', 'Renamed branch');

        $this->withToken($token)->postJson('/api/v1/cafe-configuration/branches', ['name' => 'Missing Zone'])
            ->assertUnprocessable()->assertJsonValidationErrors('timezone');
        $this->withToken($token)->postJson('/api/v1/cafe-configuration/branches', ['name' => 'Bad Zone', 'timezone' => 'Not/AZone'])
            ->assertUnprocessable()->assertJsonValidationErrors('timezone');
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchId}", ['currency' => 'USD'])
            ->assertUnprocessable()->assertJsonValidationErrors('currency');
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchId}", ['isActive' => false])
            ->assertUnprocessable()->assertJsonValidationErrors('isActive');
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchId}", ['tenant_id' => 999])
            ->assertUnprocessable()->assertJsonValidationErrors('tenant_id');
        $this->assertDatabaseHas('branches', ['id' => $branchId, 'tenant_id' => $tenant->id, 'currency' => 'SYP', 'is_active' => true]);
        $this->assertDatabaseHas('branches', ['id' => $active->id, 'tenant_id' => $tenant->id]);
    }

    public function test_configuration_is_owner_only_and_tenant_scoped(): void
    {
        [$tenantA, $branchA, $owner] = $this->tenantBranchUser('owner-a', 'owner');
        [$tenantB, $branchB] = $this->tenantBranchUser('owner-b', 'owner');
        $manager = $this->user($tenantA, 'manager');
        $employee = $this->user($tenantA, 'cashier');
        $ownerToken = $this->authenticateTenantUser($tenantA->id, $owner);

        $this->withToken($ownerToken)->getJson("/api/v1/cafe-configuration/branches/{$branchB->id}")->assertNotFound();
        $this->withToken($ownerToken)->putJson("/api/v1/cafe-configuration/branches/{$branchB->id}", ['name' => 'Nope'])->assertNotFound();
        $this->withToken($ownerToken)->getJson('/api/v1/cafe-configuration/branches')
            ->assertOk()->assertJsonMissing(['id' => $branchB->id]);
        $this->withToken($this->authenticateTenantUser($tenantA->id, $manager))
            ->getJson('/api/v1/cafe-configuration/branches')->assertForbidden();
        $this->withToken($this->authenticateTenantUser($tenantA->id, $employee))
            ->getJson('/api/v1/cafe-configuration/branches')->assertForbidden();
        $this->assertDatabaseHas('branches', ['id' => $branchA->id, 'tenant_id' => $tenantA->id]);
        $this->assertDatabaseHas('branches', ['id' => $branchB->id, 'tenant_id' => $tenantB->id, 'name' => $branchB->name]);
    }

    /** @return array{Tenant, Branch, User} */
    private function tenantBranchUser(string $name, string $role): array
    {
        $tenant = Tenant::query()->create(['name' => "Tenant {$name}", 'slug' => 'tenant-'.strtolower($name).'-'.uniqid(), 'status' => 'active']);
        $branch = Branch::query()->create(['tenant_id' => $tenant->id, 'name' => "Branch {$name}", 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);

        return [$tenant, $branch, $this->user($tenant, $role)];
    }

    private function user(Tenant $tenant, string $role): User
    {
        return User::query()->create([
            'tenant_id' => $tenant->id,
            'name' => ucfirst($role),
            'email' => uniqid($role, true).'@example.test',
            'username' => $role === 'cashier' ? 'cashier-'.uniqid() : null,
            'password' => Hash::make('password'),
            'role' => $role,
            'is_active' => true,
        ]);
    }
}
