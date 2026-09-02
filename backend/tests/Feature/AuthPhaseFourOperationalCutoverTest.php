<?php

namespace Tests\Feature;

use App\Models\Branch;
use App\Models\Tenant;
use App\Models\User;
use App\Services\UserBranchAssignmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthPhaseFourOperationalCutoverTest extends TestCase
{
    use RefreshDatabase;

    public function test_operational_boundary_requires_bearer_and_ignores_x_tenant_id(): void
    {
        [$tenantA, $branchA, $owner] = $this->tenantBranchUser('A', 'owner');
        [$tenantB, $branchB] = $this->tenantBranchUser('B', 'owner');

        $this->getJson('/api/v1/branches', ['Authorization' => ''])->assertUnauthorized();

        $token = $this->authenticateTenantUser($tenantA->id, $owner);
        $this->withToken($token)->getJson('/api/v1/branches', ['X-Tenant-Id' => (string) $tenantB->id])
            ->assertOk()
            ->assertJsonPath('data.0.id', $branchA->id)
            ->assertJsonMissing(['id' => $branchB->id]);
    }

    public function test_assigned_branch_list_and_shift_owner_are_authenticated(): void
    {
        [$tenant, $allowed] = $this->tenantBranchUser('A', 'owner');
        $blocked = Branch::query()->create(['tenant_id' => $tenant->id, 'name' => 'Blocked', 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);
        $employee = User::query()->create([
            'tenant_id' => $tenant->id, 'name' => 'Cashier', 'username' => 'cashier', 'normalized_username' => 'cashier',
            'email' => 'cashier@example.test', 'password' => Hash::make('password'), 'role' => 'cashier', 'is_active' => true,
        ]);
        app(UserBranchAssignmentService::class)->assign($employee, $allowed);
        $token = $this->authenticateTenantUser($tenant->id, $employee);

        $this->withToken($token)->getJson('/api/v1/branches')->assertOk()
            ->assertJsonPath('data.0.id', $allowed->id)->assertJsonCount(1, 'data');
        $this->withToken($token)->postJson('/api/v1/shifts/current', ['branchId' => $blocked->id, 'openingCash' => 0])->assertForbidden();
        $this->withToken($token)->postJson('/api/v1/shifts/current', ['branchId' => $allowed->id, 'openingCash' => 0, 'userId' => 999])->assertUnprocessable();
        $opened = $this->withToken($token)->postJson('/api/v1/shifts/current', ['branchId' => $allowed->id, 'openingCash' => 0])->assertCreated();
        $this->assertDatabaseHas('shifts', ['id' => $opened->json('data.id'), 'user_id' => $employee->id, 'branch_id' => $allowed->id]);
    }

    public function test_order_payment_and_availability_use_authenticated_actor(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
        $owner = User::query()->where('tenant_id', $tenantId)->where('role', 'owner')->firstOrFail();
        $token = $this->authenticateTenantUser($tenantId, $owner);
        $now = now();
        $shiftId = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'user_id' => $owner->id,
            'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $orderId = DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_number' => 'AUTH4-001', 'type' => 'takeaway',
            'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 10, 'tax_total' => 0, 'total' => 10,
            'shift_id' => $shiftId,
            'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now,
        ]);

        $this->withToken($token)->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => 10, 'idempotencyKey' => 'auth4-payment'])->assertOk();
        $this->assertDatabaseHas('payments', ['order_id' => $orderId, 'cashier_id' => $owner->id]);

        $productId = (int) DB::table('products')->where('tenant_id', $tenantId)->orderBy('id')->value('id');
        $this->withToken($token)->putJson("/api/v1/admin/catalog/products/{$productId}/operational-availability", ['branchId' => $branchId, 'channel' => 'pos', 'status' => 'sold_out'])->assertOk();
        $this->assertDatabaseHas('product_operational_availabilities', ['tenant_id' => $tenantId, 'product_id' => $productId, 'branch_id' => $branchId, 'updated_by' => $owner->id]);
    }

    public function test_current_shift_and_pos_state_only_report_the_authenticated_users_open_shift(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('shift-state', 'owner');
        $other = User::query()->create([
            'tenant_id' => $tenant->id, 'name' => 'Other Cashier',
            'email' => 'other-shift@example.test', 'password' => Hash::make('password'),
            'role' => 'cashier', 'is_active' => true,
        ]);
        $now = now();
        DB::table('shifts')->insert([
            'tenant_id' => $tenant->id, 'branch_id' => $branch->id, 'user_id' => $other->id,
            'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->getJson("/api/v1/shifts/current?branchId={$branch->id}")
            ->assertOk()->assertJsonPath('data', null);
        $this->withToken($token)->getJson("/api/v1/pos/state?branchId={$branch->id}")
            ->assertOk()->assertJsonPath('data.terminal.status', 'closed')
            ->assertJsonPath('data.currentShift', null);

        $shiftId = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant->id, 'branch_id' => $branch->id, 'user_id' => $owner->id,
            'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);

        $this->withToken($token)->getJson("/api/v1/shifts/current?branchId={$branch->id}")
            ->assertOk()->assertJsonPath('data.id', $shiftId)
            ->assertJsonPath('data.userId', $owner->id);
        $this->withToken($token)->getJson("/api/v1/pos/state?branchId={$branch->id}")
            ->assertOk()->assertJsonPath('data.terminal.status', 'open')
            ->assertJsonPath('data.currentShift.id', $shiftId);
    }

    public function test_payment_requires_the_authenticated_users_open_shift_for_the_order_branch(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('payment-shift', 'owner');
        $otherBranch = Branch::query()->create([
            'tenant_id' => $tenant->id, 'name' => 'Other Branch', 'timezone' => 'UTC',
            'currency' => 'SYP', 'is_active' => true,
        ]);
        $other = User::query()->create([
            'tenant_id' => $tenant->id, 'name' => 'Other Cashier',
            'email' => 'other-payment@example.test', 'password' => Hash::make('password'),
            'role' => 'cashier', 'is_active' => true,
        ]);
        $token = $this->authenticateTenantUser($tenant->id, $owner);
        $now = now();

        $withoutShift = $this->createPayableOrder($tenant->id, $branch->id, null, 'SHIFT-NONE', $now);
        $this->withToken($token)->postJson("/api/v1/orders/{$withoutShift}/pay", [
            'method' => 'cash', 'amount' => 10, 'idempotencyKey' => 'shift-none',
        ])->assertUnprocessable()->assertJsonValidationErrors('shiftId');

        $otherUserShift = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant->id, 'branch_id' => $branch->id, 'user_id' => $other->id,
            'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $otherUserOrder = $this->createPayableOrder($tenant->id, $branch->id, $otherUserShift, 'SHIFT-OTHER-USER', $now);
        $this->withToken($token)->postJson("/api/v1/orders/{$otherUserOrder}/pay", [
            'method' => 'cash', 'amount' => 10, 'idempotencyKey' => 'shift-other-user',
        ])->assertUnprocessable()->assertJsonValidationErrors('shiftId');

        $otherBranchShift = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant->id, 'branch_id' => $otherBranch->id, 'user_id' => $owner->id,
            'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $otherBranchOrder = $this->createPayableOrder($tenant->id, $branch->id, $otherBranchShift, 'SHIFT-OTHER-BRANCH', $now);
        $this->withToken($token)->postJson("/api/v1/orders/{$otherBranchOrder}/pay", [
            'method' => 'cash', 'amount' => 10, 'idempotencyKey' => 'shift-other-branch',
        ])->assertUnprocessable()->assertJsonValidationErrors('shiftId');

        $validShift = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant->id, 'branch_id' => $branch->id, 'user_id' => $owner->id,
            'opening_cash' => 0, 'status' => 'open', 'opened_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $validOrder = $this->createPayableOrder($tenant->id, $branch->id, $validShift, 'SHIFT-VALID', $now);
        $this->withToken($token)->postJson("/api/v1/orders/{$validOrder}/pay", [
            'method' => 'cash', 'amount' => 10, 'idempotencyKey' => 'shift-valid',
        ])->assertOk();
        $this->assertDatabaseHas('payments', [
            'order_id' => $validOrder, 'shift_id' => $validShift, 'cashier_id' => $owner->id,
        ]);
    }

    public function test_temporary_menu_management_boundary_allows_owner_and_manager_but_forbids_employee_api_access(): void
    {
        [$tenant, , $owner] = $this->tenantBranchUser('menu-owner', 'owner');
        [, , $manager] = $this->tenantBranchUser('menu-manager', 'manager');
        // Keep each actor in one tenant: create the manager and employee under
        // the owner tenant to exercise only the temporary role policy.
        $manager->update(['tenant_id' => $tenant->id]);
        $employee = User::query()->create([
            'tenant_id' => $tenant->id, 'name' => 'Cashier', 'username' => 'menu-cashier',
            'normalized_username' => 'menu-cashier', 'email' => 'menu-cashier@example.test',
            'password' => Hash::make('password'), 'role' => 'cashier', 'is_active' => true,
        ]);

        $this->withToken($this->authenticateTenantUser($tenant->id, $owner))
            ->getJson('/api/v1/admin/menus')->assertOk();
        $this->withToken($this->authenticateTenantUser($tenant->id, $manager))
            ->getJson('/api/v1/admin/menus')->assertOk();
        $this->withToken($this->authenticateTenantUser($tenant->id, $employee))
            ->getJson('/api/v1/admin/menus')->assertForbidden();
    }

    public function test_manager_cannot_open_a_published_menu_version_for_an_unassigned_branch(): void
    {
        [$tenant, $allowed] = $this->tenantBranchUser('version-scope', 'owner');
        $blocked = Branch::query()->create([
            'tenant_id' => $tenant->id, 'name' => 'Blocked', 'timezone' => 'UTC',
            'currency' => 'SYP', 'is_active' => true,
        ]);
        $manager = User::query()->create([
            'tenant_id' => $tenant->id, 'name' => 'Manager', 'email' => 'version-manager@example.test',
            'password' => Hash::make('password'), 'role' => 'manager', 'is_active' => true,
        ]);
        app(UserBranchAssignmentService::class)->assign($manager, $allowed);
        $now = now();
        $publication = DB::table('menu_publications')->insertGetId([
            'tenant_id' => $tenant->id, 'status' => 'published', 'published_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $version = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $tenant->id, 'menu_publication_id' => $publication,
            'branch_id' => $blocked->id, 'channel' => 'pos', 'version_number' => 1,
            'payload_json' => json_encode(['context' => ['schemaVersion' => 3], 'menus' => []]),
            'checksum' => str_repeat('a', 64), 'status' => 'current', 'published_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);

        $this->withToken($this->authenticateTenantUser($tenant->id, $manager))
            ->getJson("/api/v1/admin/menu-management/versions/{$version}")
            ->assertForbidden();
    }

    /** @return array{Tenant, Branch, User} */
    private function tenantBranchUser(string $name, string $role): array
    {
        $tenant = Tenant::query()->create(['name' => "Tenant {$name}", 'slug' => 'tenant-'.strtolower($name).'-'.uniqid(), 'status' => 'active']);
        $branch = Branch::query()->create(['tenant_id' => $tenant->id, 'name' => "Branch {$name}", 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);
        $user = User::query()->create(['tenant_id' => $tenant->id, 'name' => ucfirst($role), 'email' => strtolower($name).'-'.uniqid().'@example.test', 'password' => Hash::make('password'), 'role' => $role, 'is_active' => true]);

        return [$tenant, $branch, $user];
    }

    private function createPayableOrder(int $tenantId, int $branchId, ?int $shiftId, string $number, $now): int
    {
        return DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'shift_id' => $shiftId,
            'order_number' => $number, 'type' => 'takeaway', 'status' => 'draft',
            'payment_status' => 'unpaid', 'subtotal' => 10, 'tax_total' => 0, 'total' => 10,
            'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now,
        ]);
    }
}
