<?php

namespace Tests\Feature;

use App\Support\FinanceAccess;
use App\Services\BranchAccessService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class Phase12AuthorizationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_explicit_permissions_drive_non_manager_access_and_no_rows_deny(): void
    {
        $this->seed(); [$tenant, $owner] = $this->tenantAndOwner();
        $cashier = $this->user($tenant, 'cashier'); $manager = $this->user($tenant, 'manager');
        $this->getJson('/api/v1/finance/transactions', $this->headers($tenant, $cashier))->assertForbidden();
        $this->getJson('/api/v1/finance/transactions', $this->headers($tenant, $manager))->assertForbidden();
        DB::table('finance_role_permissions')->insert(['tenant_id' => $tenant, 'role' => 'cashier', 'permission' => 'finance.view', 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/v1/finance/transactions', $this->headers($tenant, $cashier))->assertForbidden();
        $this->putJson('/api/v1/finance/settings/role-permissions/cashier', ['permissions' => ['finance.transactions.view']], $this->headers($tenant, $owner))->assertOk()->assertJsonPath('data.permissions.0', 'finance.transactions.view');
        $this->getJson('/api/v1/finance/transactions', $this->headers($tenant, $cashier))->assertOk();
        $this->assertSame(['finance.transactions.view'], FinanceAccess::permissionsFor($tenant, 'cashier'));
        $this->assertDatabaseHas('activity_logs', ['tenant_id' => $tenant, 'action' => 'finance_role_permissions.replaced']);
    }

    public function test_role_permission_administration_is_owner_only_and_validates_input(): void
    {
        $this->seed(); [$tenant, $owner] = $this->tenantAndOwner(); $cashier = $this->user($tenant, 'cashier');
        $this->getJson('/api/v1/finance/settings/role-permissions/cashier', $this->headers($tenant, $cashier))->assertForbidden();
        $this->putJson('/api/v1/finance/settings/role-permissions/cashier', ['permissions' => ['not.a.permission']], $this->headers($tenant, $owner))->assertUnprocessable();
        $this->putJson('/api/v1/finance/settings/role-permissions/cashier', ['permissions' => ['finance.view', 'finance.view']], $this->headers($tenant, $owner))->assertUnprocessable();
        $this->putJson('/api/v1/finance/settings/role-permissions/owner', ['permissions' => []], $this->headers($tenant, $owner))->assertUnprocessable();
    }

    public function test_approval_rule_conflicts_are_rejected_and_branch_rule_is_distinct(): void
    {
        $this->seed(); [$tenant, $owner] = $this->tenantAndOwner(); $headers = $this->headers($tenant, $owner);
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $payload = ['actionType' => 'expense_approve', 'role' => 'cashier', 'maxAmount' => '100.00', 'isActive' => true];
        $this->postJson('/api/v1/finance/settings/approval-rules', $payload, $headers)->assertCreated();
        $this->postJson('/api/v1/finance/settings/approval-rules', $payload, $headers)->assertUnprocessable()->assertJsonValidationErrors('approvalRule');
        $this->postJson('/api/v1/finance/settings/approval-rules', $payload + ['branchId' => $branch, 'maxAmount' => '200.00'], $headers)->assertCreated()->assertJsonPath('data.branchId', $branch);
        $this->assertDatabaseHas('activity_logs', ['tenant_id' => $tenant, 'action' => 'finance_approval_rule.created']);
    }

    public function test_operational_branch_access_uses_active_assignments_and_ignores_tenant_headers(): void
    {
        $this->seed();
        [$tenant, $owner] = $this->tenantAndOwner();
        $active = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Active scope', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $inactive = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Inactive scope', 'is_active' => false, 'created_at' => now(), 'updated_at' => now()]);
        $manager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'employee');
        foreach ([$manager, $employee] as $user) {
            DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $user, 'branch_id' => $active, 'created_at' => now(), 'updated_at' => now()]);
            DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $user, 'branch_id' => $inactive, 'created_at' => now(), 'updated_at' => now()]);
        }

        $access = app(BranchAccessService::class);
        $this->assertContains($active, $access->accessibleBranchIds(\App\Models\User::findOrFail($owner)));
        $this->assertNotContains($inactive, $access->accessibleBranchIds(\App\Models\User::findOrFail($owner)));
        $this->assertSame([$active], $access->accessibleBranchIds(\App\Models\User::findOrFail($manager)));
        $this->assertSame([$active], $access->accessibleBranchIds(\App\Models\User::findOrFail($employee)));

        try {
            $access->authorize(\App\Models\User::findOrFail($owner), $inactive);
            $this->fail('Inactive branches must not be operational.');
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $exception) {
            $this->assertSame(404, $exception->getStatusCode());
        }

        $otherTenant = (int) DB::table('tenants')->insertGetId(['name' => 'Other tenant', 'slug' => 'phase12-other', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $foreign = (int) DB::table('branches')->insertGetId(['tenant_id' => $otherTenant, 'name' => 'Foreign branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/v1/warehouses?branchId='.$foreign, array_merge($this->headers($tenant, $manager), ['X-Tenant-Id' => $otherTenant]))->assertNotFound();
    }

    private function tenantAndOwner(): array { $tenant = (int) DB::table('tenants')->orderBy('id')->value('id'); return [$tenant, (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id')]; }
    private function user(int $tenant, string $role): int { return (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => ucfirst($role).' user', 'email' => "$role-$tenant-".uniqid().'@example.test', 'password' => bcrypt('password'), 'role' => $role, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]); }
    private function headers(int $tenant, int $user): array { $token = "phase12-$tenant-$user"; DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'phase12-test'], ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]); return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenant]; }
}
