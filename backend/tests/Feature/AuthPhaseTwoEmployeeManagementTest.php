<?php

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\Branch;
use App\Models\Tenant;
use App\Models\TenantRole;
use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Services\UserBranchAssignmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthPhaseTwoEmployeeManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_manager_creates_manager_and_employee_with_temporary_credentials(): void
    {
        [$tenant, $branch, $manager] = $this->managerContext();
        $token = $this->loginEmail($manager, 'ManagerPassword');
        $roles = $this->withToken($token)->getJson('/api/v1/roles')->assertOk()->json('data');
        $managerRole = collect($roles)->firstWhere('code', 'manager');
        $employeeRole = collect($roles)->firstWhere('code', 'employee');

        $this->withToken($token)->postJson('/api/v1/employees', [
            'name' => 'New Manager', 'email' => 'new.manager@example.test', 'roleId' => $managerRole['id'],
            'branchIds' => [$branch->id], 'temporaryPassword' => 'ManagerTemp1', 'temporaryPassword_confirmation' => 'ManagerTemp1',
        ])->assertCreated()->assertJsonPath('data.role.code', 'manager')->assertJsonPath('data.mustChangePassword', true);
        $newManager = User::query()->where('email', 'new.manager@example.test')->firstOrFail();
        $this->assertTrue(Hash::check('ManagerTemp1', $newManager->password));
        $this->postJson('/api/v1/auth/login', ['email' => $newManager->email, 'password' => 'ManagerTemp1'])->assertOk();

        $this->withToken($token)->postJson('/api/v1/employees', [
            'name' => 'New Employee', 'email' => 'new.employee@example.test', 'username' => 'New.Employee', 'roleId' => $employeeRole['id'],
            'branchIds' => [$branch->id], 'temporaryPassword' => 'Employee1', 'temporaryPassword_confirmation' => 'Employee1',
        ])->assertCreated()->assertJsonPath('data.role.code', 'employee')->assertJsonPath('data.allBranches', false);
        $employee = User::query()->where('email', 'new.employee@example.test')->firstOrFail();
        $employeeToken = $this->postJson('/api/v1/auth/login', ['username' => 'new.employee', 'password' => 'Employee1'])->assertOk()->json('data.accessToken');
        $this->withToken($employeeToken)->getJson('/api/v1/employees')->assertForbidden()->assertJsonPath('code', 'PASSWORD_CHANGE_REQUIRED');
        $this->withToken($employeeToken)->postJson('/api/v1/auth/change-password', ['currentPassword' => 'Employee1', 'newPassword' => 'EmployeeChanged', 'newPassword_confirmation' => 'EmployeeChanged'])->assertOk();
        $this->withToken($employeeToken)->getJson('/api/v1/employees')->assertForbidden();
        $this->assertSame('employee', $employee->fresh()->effectiveRoleCode());
    }

    public function test_owner_and_manager_self_protection_is_enforced(): void
    {
        [$tenant, $branch, $manager] = $this->managerContext();
        $owner = $this->user($tenant, 'owner', 'OwnerPassword');
        $token = $this->loginEmail($manager, 'ManagerPassword');

        foreach ([
            ['post', "/api/v1/employees/{$owner->id}/deactivate", []],
            ['post', "/api/v1/employees/{$owner->id}/archive", []],
            ['post', "/api/v1/employees/{$owner->id}/reset-password", ['temporaryPassword' => 'OwnerReset1', 'temporaryPassword_confirmation' => 'OwnerReset1']],
            ['put', "/api/v1/employees/{$owner->id}", ['name' => 'Changed']],
            ['post', "/api/v1/employees/{$manager->id}/deactivate", []],
            ['post', "/api/v1/employees/{$manager->id}/reset-password", ['temporaryPassword' => 'ManagerReset1', 'temporaryPassword_confirmation' => 'ManagerReset1']],
        ] as [$method, $url, $payload]) {
            $this->withToken($token)->{$method.'Json'}($url, $payload)->assertForbidden();
        }
        $this->assertTrue($owner->fresh()->is_active);
        $this->assertFalse($owner->fresh()->trashed());
    }

    public function test_role_changes_revoke_sessions_and_cross_tenant_branches_are_atomic(): void
    {
        [$tenant, $branch, $manager] = $this->managerContext();
        $employee = $this->user($tenant, 'employee', 'EmployeePass', 'worker');
        app(UserBranchAssignmentService::class)->assign($employee, $branch);
        $employeeToken = $this->postJson('/api/v1/auth/login', ['username' => 'worker', 'password' => 'EmployeePass'])->assertOk()->json('data.accessToken');
        $managerToken = $this->loginEmail($manager, 'ManagerPassword');
        $managerRole = TenantRole::query()->where('tenant_id', $tenant->id)->where('code', 'manager')->firstOrFail();

        $this->withToken($managerToken)->putJson("/api/v1/employees/{$employee->id}", [
            'roleId' => $managerRole->id, 'temporaryPassword' => 'NewManagerPass', 'temporaryPassword_confirmation' => 'NewManagerPass',
        ])->assertOk()->assertJsonPath('data.role.code', 'manager')->assertJsonPath('data.mustChangePassword', true);
        $this->withToken($employeeToken)->getJson('/api/v1/auth/me')->assertUnauthorized()->assertJsonPath('code', 'TOKEN_REVOKED');
        $this->postJson('/api/v1/auth/login', ['email' => $employee->email, 'password' => 'NewManagerPass'])->assertOk();

        $other = Tenant::query()->create(['name' => 'Other Cafe', 'slug' => 'other-'.uniqid(), 'status' => 'active']);
        $foreignBranch = Branch::query()->create(['tenant_id' => $other->id, 'name' => 'Foreign', 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);
        $this->withToken($managerToken)->putJson("/api/v1/employees/{$employee->id}", ['branchIds' => [$branch->id, $foreignBranch->id]])->assertUnprocessable();
        $this->assertSame([$branch->id], $employee->fresh()->branches()->pluck('branches.id')->all());
    }

    public function test_password_reset_and_deactivation_revoke_every_target_token(): void
    {
        [$tenant, $branch, $manager] = $this->managerContext();
        $employee = $this->user($tenant, 'employee', 'EmployeePass', 'cashier');
        app(UserBranchAssignmentService::class)->assign($employee, $branch);
        $first = $this->postJson('/api/v1/auth/login', ['username' => 'cashier', 'password' => 'EmployeePass'])->json('data.accessToken');
        $this->postJson('/api/v1/auth/login', ['username' => 'cashier', 'password' => 'EmployeePass'])->assertOk();
        $managerToken = $this->loginEmail($manager, 'ManagerPassword');

        $this->withToken($managerToken)->postJson("/api/v1/employees/{$employee->id}/reset-password", ['temporaryPassword' => 'ResetPass1', 'temporaryPassword_confirmation' => 'ResetPass1'])->assertOk();
        $this->assertSame(2, ApiToken::query()->where('user_id', $employee->id)->whereNotNull('revoked_at')->count());
        $this->withToken($first)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->postJson('/api/v1/auth/login', ['username' => 'cashier', 'password' => 'EmployeePass'])->assertUnauthorized();

        $freshToken = $this->postJson('/api/v1/auth/login', ['username' => 'cashier', 'password' => 'ResetPass1'])->assertOk()->json('data.accessToken');
        $this->withToken($managerToken)->postJson("/api/v1/employees/{$employee->id}/deactivate")->assertOk()->assertJsonPath('data.status', 'deactivated');
        $this->withToken($freshToken)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    /** @return array{Tenant, Branch, User} */
    private function managerContext(): array
    {
        $tenant = Tenant::query()->create(['name' => 'Primary Cafe', 'slug' => 'primary-'.uniqid(), 'status' => 'active']);
        $branch = Branch::query()->create(['tenant_id' => $tenant->id, 'name' => 'Main', 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);
        $manager = $this->user($tenant, 'manager', 'ManagerPassword');
        app(UserBranchAssignmentService::class)->assign($manager, $branch);

        return [$tenant, $branch, $manager];
    }

    private function user(Tenant $tenant, string $role, string $password, ?string $username = null): User
    {
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($tenant->id);
        $code = $role === 'cashier' ? 'employee' : $role;

        return User::query()->create([
            'tenant_id' => $tenant->id, 'tenant_role_id' => $roles[$code]->id, 'name' => ucfirst($role),
            'email' => uniqid($role, true).'@example.test', 'username' => $username, 'password' => Hash::make($password),
            'role' => $role === 'employee' ? 'cashier' : $role, 'is_active' => true,
        ]);
    }

    private function loginEmail(User $user, string $password): string
    {
        return $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => $password])->assertOk()->json('data.accessToken');
    }
}
