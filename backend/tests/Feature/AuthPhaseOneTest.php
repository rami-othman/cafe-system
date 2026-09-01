<?php

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\Branch;
use App\Models\Tenant;
use App\Models\User;
use App\Services\BranchAccessService;
use App\Services\UserBranchAssignmentService;
use App\Services\UserLifecycleService;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class AuthPhaseOneTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware(['api.token', 'password.changed'])->get('/api/v1/auth-test/gated', fn () => response()->json(['data' => ['ok' => true]]));
    }

    public function test_role_aware_login_hashes_tokens_and_returns_session_identity(): void
    {
        $tenant = $this->tenant();
        $owner = $this->user($tenant, 'owner', 'OwnerPassword');
        $manager = $this->user($tenant, 'manager', 'ManagerPass');
        $employee = $this->user($tenant, 'cashier', 'Cashier1', 'Rami');
        $branch = $this->branch($tenant);
        app(UserBranchAssignmentService::class)->assign($employee, $branch);

        $ownerResponse = $this->postJson('/api/v1/auth/login', ['email' => $owner->email, 'password' => 'OwnerPassword', 'deviceName' => 'Owner laptop'])->assertOk();
        $this->postJson('/api/v1/auth/login', ['email' => $manager->email, 'password' => 'ManagerPass'])->assertOk();
        $employeeResponse = $this->postJson('/api/v1/auth/login', ['username' => 'rami', 'password' => 'Cashier1'])->assertOk()
            ->assertJsonPath('data.user.id', $employee->id)->assertJsonPath('data.branchAccess.allBranches', false)
            ->assertJsonPath('data.branchAccess.branchIds.0', $branch->id);

        $token = $ownerResponse->json('data.accessToken');
        $this->assertNotEmpty($token);
        $this->assertDatabaseMissing('api_tokens', ['token_hash' => $token]);
        $this->assertDatabaseHas('api_tokens', ['token_hash' => hash('sha256', $token), 'user_id' => $owner->id]);
        $employeeResponse->assertJsonPath('data.tokenType', 'Bearer');
        $this->assertTrue(Hash::check('Cashier1', $employee->fresh()->password));
    }

    public function test_login_rejects_ambiguous_identifier_wrong_role_and_is_rate_limited(): void
    {
        $tenant = $this->tenant();
        $owner = $this->user($tenant, 'owner', 'OwnerPassword');
        $employee = $this->user($tenant, 'cashier', 'Cashier1', 'employee');

        $this->postJson('/api/v1/auth/login', ['email' => $owner->email, 'username' => 'employee', 'password' => 'OwnerPassword'])->assertUnprocessable();
        $this->postJson('/api/v1/auth/login', ['username' => 'employee', 'password' => 'Cashier1'])->assertOk();
        $this->postJson('/api/v1/auth/login', ['username' => 'employee', 'password' => 'bad'])->assertUnauthorized()->assertJsonPath('code', 'INVALID_CREDENTIALS');
        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->postJson('/api/v1/auth/login', ['email' => $owner->email, 'password' => 'bad'])->assertUnauthorized();
        }
        $this->postJson('/api/v1/auth/login', ['email' => $owner->email, 'password' => 'bad'])->assertStatus(429);
    }

    public function test_logout_is_per_device_and_revoked_or_expired_tokens_are_rejected(): void
    {
        $tenant = $this->tenant();
        $owner = $this->user($tenant, 'owner', 'OwnerPassword');
        $first = $this->loginEmail($owner, 'OwnerPassword');
        $second = $this->loginEmail($owner, 'OwnerPassword');

        $this->withToken($first)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->withToken($first)->getJson('/api/v1/auth/me')->assertUnauthorized()->assertJsonPath('code', 'TOKEN_REVOKED');
        $this->withToken($second)->getJson('/api/v1/auth/me')->assertOk();
        ApiToken::query()->where('token_hash', hash('sha256', $second))->update(['expires_at' => now()->subSecond()]);
        $this->withToken($second)->getJson('/api/v1/auth/me')->assertUnauthorized()->assertJsonPath('code', 'TOKEN_EXPIRED');
    }

    public function test_password_change_gate_and_authenticated_tenant_context_cannot_be_overridden(): void
    {
        $tenant = $this->tenant();
        $other = $this->tenant('Other');
        $owner = $this->user($tenant, 'owner', 'OwnerPassword', null, true);
        $token = $this->loginEmail($owner, 'OwnerPassword');

        $this->withToken($token)->getJson('/api/v1/auth-test/gated')->assertForbidden()->assertJsonPath('code', 'PASSWORD_CHANGE_REQUIRED');
        $this->withToken($token)->getJson('/api/v1/auth/me', ['X-Tenant-Id' => $other->id])->assertOk()->assertJsonPath('data.tenant.id', $tenant->id);
        $this->withToken($token)->postJson('/api/v1/auth/change-password', ['currentPassword' => 'OwnerPassword', 'newPassword' => 'ChangedOwner', 'newPassword_confirmation' => 'ChangedOwner'])->assertOk();
        $this->withToken($token)->getJson('/api/v1/auth-test/gated')->assertOk();
    }

    public function test_lifecycle_revokes_every_session_and_protects_owner(): void
    {
        $tenant = $this->tenant();
        $employee = $this->user($tenant, 'cashier', 'Cashier1', 'employee');
        $first = $this->postJson('/api/v1/auth/login', ['username' => 'employee', 'password' => 'Cashier1'])->json('data.accessToken');
        $second = $this->postJson('/api/v1/auth/login', ['username' => 'employee', 'password' => 'Cashier1'])->json('data.accessToken');

        app(UserLifecycleService::class)->deactivate($employee);
        $this->assertSame(2, ApiToken::query()->where('user_id', $employee->id)->whereNotNull('revoked_at')->count());
        $this->withToken($first)->getJson('/api/v1/auth/me')->assertUnauthorized();
        app(UserLifecycleService::class)->reactivate($employee->fresh());
        $this->withToken($second)->getJson('/api/v1/auth/me')->assertUnauthorized();

        $owner = $this->user($tenant, 'owner', 'OwnerPassword');
        $this->expectException(\DomainException::class);
        app(UserLifecycleService::class)->archive($owner);
    }

    public function test_tenant_lifecycle_and_branch_access_are_enforced(): void
    {
        $tenant = $this->tenant();
        $other = $this->tenant('Other');
        $owner = $this->user($tenant, 'owner', 'OwnerPassword');
        $employee = $this->user($tenant, 'cashier', 'Cashier1', 'employee');
        $branch = $this->branch($tenant);
        $foreignBranch = $this->branch($other);
        app(UserBranchAssignmentService::class)->assign($employee, $branch);

        $access = app(BranchAccessService::class);
        $this->assertTrue($access->canAccessBranch($owner, $branch));
        $this->assertTrue($access->canAccessBranch($employee, $branch));
        $this->assertFalse($access->canAccessBranch($employee, $foreignBranch));
        try {
            app(UserBranchAssignmentService::class)->assign($employee, $foreignBranch);
            $this->fail('Cross-tenant branch assignment must be rejected.');
        } catch (\DomainException) {
            // Expected domain boundary.
        }
        $token = $this->loginEmail($owner, 'OwnerPassword');
        $tenant->update(['status' => 'suspended']);
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertForbidden()->assertJsonPath('code', 'TENANT_NOT_OPERATIONAL');
        $tenant->update(['status' => 'active']);
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk();
    }

    public function test_username_is_normalized_per_tenant_but_reusable_across_tenants(): void
    {
        $tenant = $this->tenant();
        $this->user($tenant, 'cashier', 'Cashier1', 'Ahmad');
        $this->expectException(UniqueConstraintViolationException::class);
        $this->user($tenant, 'cashier', 'Cashier2', 'ahmad');
    }

    public function test_same_normalized_username_is_allowed_in_another_tenant(): void
    {
        $tenant = $this->tenant();
        $other = $this->tenant('Other');
        $this->user($tenant, 'cashier', 'Cashier1', 'Ahmad');
        $this->assertNotNull($this->user($other, 'cashier', 'Cashier1', 'ahmad')->id);
    }

    private function tenant(string $suffix = 'Primary'): Tenant
    {
        return Tenant::query()->create(['name' => $suffix.' Cafe', 'slug' => strtolower($suffix).'-'.uniqid(), 'status' => 'active']);
    }

    private function branch(Tenant $tenant): Branch
    {
        return Branch::query()->create(['tenant_id' => $tenant->id, 'name' => 'Branch '.uniqid(), 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);
    }

    private function user(Tenant $tenant, string $role, string $password, ?string $username = null, bool $mustChangePassword = false): User
    {
        return User::query()->create(['tenant_id' => $tenant->id, 'name' => ucfirst($role), 'email' => uniqid($role, true).'@example.test', 'username' => $username, 'normalized_username' => $username ? User::normalizeUsername($username) : null, 'password' => Hash::make($password), 'role' => $role, 'is_active' => true, 'must_change_password' => $mustChangePassword]);
    }

    private function loginEmail(User $user, string $password): string
    {
        return $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => $password])->assertOk()->json('data.accessToken');
    }
}
