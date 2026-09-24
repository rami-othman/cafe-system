<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

/**
 * Shared actor authorization for administrative console commands
 * (shifts:reconcile-overlap, shifts:adopt-close-config). Reuses the existing
 * tenant_role authorization model (DefaultTenantRoleService) instead of
 * inventing a second permission system: the actor must be an active member
 * of the given tenant holding the Owner or Manager role.
 */
final class AdminCommandActorGuard
{
    private const PRIVILEGED_ROLES = [DefaultTenantRoleService::OWNER, DefaultTenantRoleService::MANAGER];

    /** @return array{code: string, message: string}|null null when the actor is valid */
    public function invalidReason(int $tenantId, ?int $actorId): ?array
    {
        if (! $actorId) {
            return ['code' => 'ACTOR_INVALID', 'message' => 'A valid --actor user id of this tenant is required.'];
        }

        $user = DB::table('users')->where('tenant_id', $tenantId)->where('id', $actorId)->whereNull('deleted_at')->first();
        if (! $user) {
            return ['code' => 'ACTOR_INVALID', 'message' => "User {$actorId} does not belong to tenant {$tenantId}."];
        }
        if (! $user->is_active) {
            return ['code' => 'ACTOR_INACTIVE', 'message' => "User {$actorId} is not active."];
        }

        $roleCode = $user->tenant_role_id
            ? DB::table('tenant_roles')->where('tenant_id', $tenantId)->where('id', $user->tenant_role_id)->value('code')
            : $user->role;
        if (! in_array($roleCode, self::PRIVILEGED_ROLES, true)) {
            return ['code' => 'ACTOR_NOT_AUTHORIZED', 'message' => "User {$actorId} does not have an administrative or finance role required for this operation."];
        }

        return null;
    }
}
