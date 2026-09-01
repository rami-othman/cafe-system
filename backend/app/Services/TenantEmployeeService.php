<?php

namespace App\Services;

use App\Models\TenantRole;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class TenantEmployeeService
{
    public function __construct(
        private readonly DefaultTenantRoleService $roles,
        private readonly UserBranchAssignmentService $branches,
        private readonly UserLifecycleService $lifecycle,
    ) {}

    /** @param array<string, mixed> $data */
    public function create(int $tenantId, array $data): User
    {
        return DB::transaction(function () use ($tenantId, $data): User {
            $role = $this->assignableRole($tenantId, (int) $data['roleId']);
            $this->assertPassword($role, $data['temporaryPassword']);
            $this->assertUsernameAvailable($tenantId, $data['username'] ?? null);
            $this->assertRoleIdentity($role, $data['email'] ?? null, $data['username'] ?? null);
            $this->assertBranchIds($data['branchIds']);

            $user = User::query()->create([
                'tenant_id' => $tenantId,
                'tenant_role_id' => $role->id,
                'name' => $data['name'],
                'email' => isset($data['email']) ? mb_strtolower(trim($data['email'])) : null,
                'username' => $data['username'] ?? null,
                'password' => Hash::make($data['temporaryPassword']),
                'role' => $this->roles->canonicalLegacyRole($role->code),
                'is_active' => true,
                'must_change_password' => true,
            ]);
            $this->branches->sync($user, $data['branchIds']);

            return $user->fresh(['tenantRole', 'branches']);
        });
    }

    /** @param array<string, mixed> $data */
    public function update(User $user, array $data): User
    {
        return DB::transaction(function () use ($user, $data): User {
            $user = User::withTrashed()->with(['tenantRole', 'branches'])->lockForUpdate()->findOrFail($user->id);
            $role = isset($data['roleId']) ? $this->assignableRole((int) $user->tenant_id, (int) $data['roleId']) : $this->currentRole($user);
            $email = array_key_exists('email', $data) ? $data['email'] : $user->email;
            $username = array_key_exists('username', $data) ? $data['username'] : $user->username;
            $roleChanged = (int) $user->tenant_role_id !== (int) $role->id;
            $identityChanged = mb_strtolower((string) $user->email) !== mb_strtolower((string) $email)
                || User::normalizeUsername((string) ($user->username ?? '')) !== User::normalizeUsername((string) ($username ?? ''));

            $this->assertUsernameAvailable((int) $user->tenant_id, $username, $user->id);
            $this->assertRoleIdentity($role, $email, $username);
            if ($roleChanged) {
                if (! array_key_exists('temporaryPassword', $data)) {
                    throw ValidationException::withMessages(['temporaryPassword' => 'A new temporary password is required when changing role.']);
                }
                $this->assertPassword($role, $data['temporaryPassword']);
            }
            if (array_key_exists('branchIds', $data)) {
                $this->assertBranchIds($data['branchIds']);
            } elseif ($user->is_active && $user->branches->isEmpty()) {
                throw new DomainException('Active non-owner users require at least one branch assignment.');
            }

            $payload = ['tenant_role_id' => $role->id, 'role' => $this->roles->canonicalLegacyRole($role->code)];
            foreach (['name', 'email', 'username'] as $field) {
                if (array_key_exists($field, $data)) {
                    $payload[$field] = $field === 'email' && $data[$field] ? mb_strtolower(trim($data[$field])) : $data[$field];
                }
            }
            if ($roleChanged) {
                $payload['password'] = Hash::make($data['temporaryPassword']);
                $payload['must_change_password'] = true;
            }
            $user->forceFill($payload)->save();
            if (array_key_exists('branchIds', $data)) {
                $this->branches->sync($user, $data['branchIds']);
            }
            if ($roleChanged || $identityChanged) {
                $this->lifecycle->revokeAllUserTokens($user);
            }

            return $user->fresh(['tenantRole', 'branches']);
        });
    }

    public function resetPassword(User $user, string $temporaryPassword): User
    {
        return DB::transaction(function () use ($user, $temporaryPassword): User {
            $user = User::withTrashed()->with('tenantRole')->lockForUpdate()->findOrFail($user->id);
            $role = $this->currentRole($user);
            $this->assertPassword($role, $temporaryPassword);
            $user->forceFill(['password' => Hash::make($temporaryPassword), 'must_change_password' => true])->save();
            $this->lifecycle->revokeAllUserTokens($user);

            return $user;
        });
    }

    public function assertCanReactivate(User $user): void
    {
        if ($user->isOwner() || ! $user->tenant_role_id || $user->branches()->count() < 1) {
            throw new DomainException('This user cannot be activated without an assignable role and branch assignment.');
        }
    }

    private function currentRole(User $user): TenantRole
    {
        $role = $user->tenantRole;
        if (! $role) {
            $roles = $this->roles->ensureForTenant((int) $user->tenant_id);
            $role = $roles[$user->effectiveRoleCode()] ?? null;
        }
        if (! $role) {
            throw new DomainException('The user has no valid tenant role.');
        }

        return $role;
    }

    private function assignableRole(int $tenantId, int $roleId): TenantRole
    {
        $this->roles->ensureForTenant($tenantId);
        $role = TenantRole::query()->forTenant($tenantId)->find($roleId);
        if (! $role || ! $this->roles->isAssignable($role)) {
            throw ValidationException::withMessages(['roleId' => 'Select an active Manager or Employee role for this tenant.']);
        }

        return $role;
    }

    private function assertRoleIdentity(TenantRole $role, ?string $email, ?string $username): void
    {
        if ($role->code === DefaultTenantRoleService::MANAGER && ! filled($email)) {
            throw ValidationException::withMessages(['email' => 'Managers require an email address.']);
        }
        if ($role->code === DefaultTenantRoleService::EMPLOYEE && ! filled($username)) {
            throw ValidationException::withMessages(['username' => 'Employees require a username.']);
        }
    }

    private function assertPassword(TenantRole $role, string $password): void
    {
        $minimum = $role->code === DefaultTenantRoleService::MANAGER ? 10 : 8;
        if (mb_strlen($password) < $minimum) {
            throw ValidationException::withMessages(['temporaryPassword' => "Temporary password must be at least {$minimum} characters."]);
        }
    }

    /** @param array<int, mixed> $branchIds */
    private function assertBranchIds(array $branchIds): void
    {
        if ($branchIds === [] || count($branchIds) !== count(array_unique(array_map('intval', $branchIds)))) {
            throw ValidationException::withMessages(['branchIds' => 'Provide one or more unique branch IDs.']);
        }
    }

    private function assertUsernameAvailable(int $tenantId, ?string $username, ?int $exceptUserId = null): void
    {
        if (! filled($username)) {
            return;
        }
        $query = User::withTrashed()->where('tenant_id', $tenantId)->where('normalized_username', User::normalizeUsername($username));
        if ($exceptUserId) {
            $query->where('id', '!=', $exceptUserId);
        }
        if ($query->exists()) {
            throw ValidationException::withMessages(['username' => 'This username is already in use for this tenant.']);
        }
    }
}
