<?php

namespace Tests\Feature\Manufacturing;

use App\Models\Branch;
use App\Models\Tenant;
use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Services\FinancialSetupService;
use App\Services\UserBranchAssignmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Phase 1 of the factory separation plan: an independent factory_manager
 * role, scoped to manufacturing + finance, with no cafe operational access.
 * See docs/FACTORY_EXECUTION_PROMPTS_2026-09-26.md prompt 1.
 */
class FactoryManagerRoleTest extends TestCase
{
    use RefreshDatabase;

    private Tenant $tenant;

    private Branch $cafeBranch;

    private Branch $factoryBranch;

    protected function setUp(): void
    {
        parent::setUp();
        $this->tenant = Tenant::query()->create(['name' => 'Factory Phase 1', 'slug' => 'factory-phase1-'.uniqid(), 'status' => 'active']);
        $this->cafeBranch = Branch::query()->create(['tenant_id' => $this->tenant->id, 'name' => 'Cafe Branch', 'branch_type' => 'cafe', 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);
        $this->factoryBranch = Branch::query()->create(['tenant_id' => $this->tenant->id, 'name' => 'Factory Branch', 'branch_type' => 'factory', 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);
    }

    public function test_factory_manager_role_is_provisioned_for_every_tenant(): void
    {
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($this->tenant->id);
        $this->assertArrayHasKey(DefaultTenantRoleService::FACTORY_MANAGER, $roles);
        $this->assertSame('factory_manager', $roles[DefaultTenantRoleService::FACTORY_MANAGER]->code);
    }

    public function test_factory_manager_with_factory_branch_reaches_manufacturing_and_finance_but_not_cafe_operations(): void
    {
        $owner = $this->user('owner', 'OwnerPassword1');
        app(FinancialSetupService::class)->ensureForTenant($this->tenant->id, $this->cafeBranch->id, $owner->id);
        app(FinancialSetupService::class)->ensureForTenant($this->tenant->id, $this->factoryBranch->id, $owner->id);

        $factoryManager = $this->user(DefaultTenantRoleService::FACTORY_MANAGER, 'FactoryPass1');
        app(UserBranchAssignmentService::class)->assign($factoryManager, $this->factoryBranch);
        $token = $this->loginEmail($factoryManager, 'FactoryPass1');

        // Session capabilities.
        $me = $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk()->json('data.user');
        $this->assertTrue($me['isFactoryUser']);
        $this->assertSame([$this->factoryBranch->id], $me['factoryBranchIds']);
        $this->assertNotEmpty($me['manufacturingCapabilities']);
        $this->assertContains('manufacturing.view', $me['manufacturingCapabilities']);
        $this->assertNotEmpty($me['financeCapabilities']);

        // Manufacturing endpoints reachable.
        $this->withToken($token)->getJson('/api/v1/manufacturing/overview')->assertOk();
        $this->withToken($token)->getJson('/api/v1/manufacturing/recipes')->assertOk();

        // Finance endpoints reachable (full catalog, minus the excluded facility-wide settings).
        $this->withToken($token)->getJson('/api/v1/finance/purchases')->assertOk();
        $this->withToken($token)->getJson('/api/v1/finance/vouchers')->assertOk();

        // Cafe operational surface is blocked at 403, not merely hidden.
        $this->withToken($token)->postJson('/api/v1/shifts/current', ['branchId' => $this->cafeBranch->id])->assertForbidden();
        $this->withToken($token)->postJson('/api/v1/orders', ['branchId' => $this->cafeBranch->id])->assertForbidden();
        $this->withToken($token)->getJson('/api/v1/discounts')->assertForbidden();
        $this->withToken($token)->getJson('/api/v1/cafe-configuration/profile')->assertForbidden();
        $this->withToken($token)->getJson('/api/v1/cashier/dashboard')->assertForbidden();
        $this->withToken($token)->getJson('/api/v1/cashier/inventory')->assertForbidden();
    }

    public function test_factory_manager_without_a_factory_branch_is_rejected(): void
    {
        $factoryManager = $this->user(DefaultTenantRoleService::FACTORY_MANAGER, 'FactoryPass1');
        // Deliberately no branch assignment at all: manufacturing must be
        // unreachable, and the API must never resolve a "current" branch.
        $token = $this->loginEmail($factoryManager, 'FactoryPass1');

        $this->withToken($token)->getJson('/api/v1/manufacturing/overview')
            ->assertForbidden()
            ->assertJsonPath('message', 'لا يوجد معمل مرتبط بحسابك.');

        $me = $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk()->json('data.user');
        $this->assertSame([], $me['manufacturingCapabilities']);
    }

    public function test_factory_manager_cannot_be_assigned_a_cafe_branch(): void
    {
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($this->tenant->id);
        $factoryRole = $roles[DefaultTenantRoleService::FACTORY_MANAGER];
        $owner = $this->user('owner', 'OwnerPassword1');
        $token = $this->loginEmail($owner, 'OwnerPassword1');

        $this->withToken($token)->postJson('/api/v1/employees', [
            'name' => 'Factory User', 'email' => 'factory.user@example.test', 'roleId' => $factoryRole->id,
            'branchIds' => [$this->cafeBranch->id], 'temporaryPassword' => 'FactoryTemp1', 'temporaryPassword_confirmation' => 'FactoryTemp1',
        ])->assertStatus(422);

        $this->assertDatabaseMissing('users', ['email' => 'factory.user@example.test']);

        // Valid creation with a factory branch succeeds.
        $this->withToken($token)->postJson('/api/v1/employees', [
            'name' => 'Factory User', 'email' => 'factory.user@example.test', 'roleId' => $factoryRole->id,
            'branchIds' => [$this->factoryBranch->id], 'temporaryPassword' => 'FactoryTemp1', 'temporaryPassword_confirmation' => 'FactoryTemp1',
        ])->assertCreated()->assertJsonPath('data.role.code', 'factory_manager');
    }

    public function test_changing_an_existing_cafe_users_role_to_factory_manager_requires_factory_branches(): void
    {
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($this->tenant->id);
        $factoryRole = $roles[DefaultTenantRoleService::FACTORY_MANAGER];
        $owner = $this->user('owner', 'OwnerPassword1');
        $token = $this->loginEmail($owner, 'OwnerPassword1');

        $manager = $this->user('manager', 'ManagerPassword1');
        app(UserBranchAssignmentService::class)->assign($manager, $this->cafeBranch);

        // Role change alone (no branchIds payload): still tied to the cafe branch -> rejected.
        $this->withToken($token)->putJson("/api/v1/employees/{$manager->id}", [
            'roleId' => $factoryRole->id, 'temporaryPassword' => 'FactoryTemp1', 'temporaryPassword_confirmation' => 'FactoryTemp1',
        ])->assertStatus(422);
        $this->assertSame('manager', $manager->fresh()->effectiveRoleCode());

        // Role change with a factory branchIds payload succeeds.
        $this->withToken($token)->putJson("/api/v1/employees/{$manager->id}", [
            'roleId' => $factoryRole->id, 'branchIds' => [$this->factoryBranch->id],
            'temporaryPassword' => 'FactoryTemp1', 'temporaryPassword_confirmation' => 'FactoryTemp1',
        ])->assertOk()->assertJsonPath('data.role.code', 'factory_manager');
        $this->assertSame('factory_manager', $manager->fresh()->effectiveRoleCode());
    }

    public function test_cafe_manager_has_no_manufacturing_access_and_owner_is_unaffected(): void
    {
        $owner = $this->user('owner', 'OwnerPassword1');
        $manager = $this->user('manager', 'ManagerPassword1');
        app(UserBranchAssignmentService::class)->assign($manager, $this->cafeBranch);
        $employee = $this->user('employee', 'EmployeePassword1', 'cashier-1');
        app(UserBranchAssignmentService::class)->assign($employee, $this->cafeBranch);

        $managerToken = $this->loginEmail($manager, 'ManagerPassword1');
        $this->withToken($managerToken)->getJson('/api/v1/manufacturing/overview')->assertForbidden();
        $managerMe = $this->withToken($managerToken)->getJson('/api/v1/auth/me')->assertOk()->json('data.user');
        $this->assertSame([], $managerMe['manufacturingCapabilities']);
        $this->assertFalse($managerMe['isFactoryUser']);

        $employeeToken = $this->postJson('/api/v1/auth/login', ['username' => 'cashier-1', 'password' => 'EmployeePassword1'])->assertOk()->json('data.accessToken');
        $this->withToken($employeeToken)->getJson('/api/v1/manufacturing/overview')->assertForbidden();

        $ownerToken = $this->loginEmail($owner, 'OwnerPassword1');
        $this->withToken($ownerToken)->getJson('/api/v1/manufacturing/overview')->assertOk();
        $ownerMe = $this->withToken($ownerToken)->getJson('/api/v1/auth/me')->assertOk()->json('data.user');
        $this->assertNotEmpty($ownerMe['manufacturingCapabilities']);
    }

    /**
     * Phase 2 gap fix: InventoryAccess had no factory_manager entry at all,
     * so every inventory call (materials, warehouses, stock counts) 403'd
     * for the role that the Manufacturing "materials"/"الجرد" tabs actually
     * run as. Also verifies FactoryWarehouseScope rejects a stock count
     * against a warehouse outside the factory branch (shared or another
     * branch's), matching what the UI relies on for "the factory warehouse
     * is picked automatically, nothing else is offered".
     */
    public function test_factory_manager_reaches_inventory_and_stock_counts_scoped_to_the_factory_warehouse(): void
    {
        $owner = $this->user('owner', 'OwnerPassword1');
        app(FinancialSetupService::class)->ensureForTenant($this->tenant->id, $this->cafeBranch->id, $owner->id);
        app(FinancialSetupService::class)->ensureForTenant($this->tenant->id, $this->factoryBranch->id, $owner->id);
        $factoryWarehouseId = (int) DB::table('branches')->where('id', $this->factoryBranch->id)->value('default_warehouse_id');
        $cafeWarehouseId = (int) DB::table('branches')->where('id', $this->cafeBranch->id)->value('pos_inventory_warehouse_id');
        $this->assertNotSame(0, $factoryWarehouseId);
        $this->assertNotSame($factoryWarehouseId, $cafeWarehouseId);

        $factoryManager = $this->user(DefaultTenantRoleService::FACTORY_MANAGER, 'FactoryPass1');
        app(UserBranchAssignmentService::class)->assign($factoryManager, $this->factoryBranch);
        $token = $this->loginEmail($factoryManager, 'FactoryPass1');

        // Was a flat 403 before the InventoryAccess fix.
        $this->withToken($token)->getJson('/api/v1/inventory/items')->assertOk();
        $this->withToken($token)->getJson('/api/v1/warehouses')->assertOk();

        // The factory's own warehouse is accepted.
        $this->withToken($token)->postJson('/api/v1/inventory/counts', [
            'branchId' => $this->factoryBranch->id,
            'warehouseId' => $factoryWarehouseId,
            'countDate' => now()->toDateString(),
        ])->assertCreated();

        // A cafe (or any non-factory) warehouse is rejected server-side, not
        // just hidden from the picker.
        $this->withToken($token)->postJson('/api/v1/inventory/counts', [
            'branchId' => $this->factoryBranch->id,
            'warehouseId' => $cafeWarehouseId,
            'countDate' => now()->toDateString(),
        ])->assertUnprocessable();
    }

    public function test_finance_permission_grant_migration_is_idempotent(): void
    {
        $before = DB::table('finance_role_permissions')->where('tenant_id', $this->tenant->id)->where('role', 'factory_manager')->count();
        $migration = require database_path('migrations/2026_10_05_000002_grant_factory_manager_finance_permissions.php');
        $migration->up();
        $migration->up();
        $after = DB::table('finance_role_permissions')->where('tenant_id', $this->tenant->id)->where('role', 'factory_manager')->count();
        $this->assertGreaterThan($before, $after);

        $secondCount = DB::table('finance_role_permissions')->where('tenant_id', $this->tenant->id)->where('role', 'factory_manager')->count();
        $this->assertSame($after, $secondCount);
        $this->assertDatabaseMissing('finance_role_permissions', ['tenant_id' => $this->tenant->id, 'role' => 'factory_manager', 'permission' => 'finance.settings.manage']);
    }

    private function user(string $role, string $password, ?string $username = null): User
    {
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($this->tenant->id);

        return User::query()->create([
            'tenant_id' => $this->tenant->id, 'tenant_role_id' => $roles[$role]->id, 'name' => ucfirst($role),
            'email' => uniqid($role, true).'@example.test', 'username' => $username, 'password' => Hash::make($password),
            'role' => $role === 'employee' ? 'cashier' : $role, 'is_active' => true,
        ]);
    }

    private function loginEmail(User $user, string $password): string
    {
        return $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => $password])->assertOk()->json('data.accessToken');
    }
}
