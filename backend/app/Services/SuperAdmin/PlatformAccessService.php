<?php

namespace App\Services\SuperAdmin;

use App\Models\User;
use Illuminate\Support\Facades\DB;

class PlatformAccessService
{
    public function isPlatformAdmin(User $user): bool
    {
        return $user->tenant_id === null && $user->is_active && DB::table('platform_role_user')
            ->where('user_id', $user->id)->exists();
    }

    public function hasPermission(User $user, string $permission): bool
    {
        if (! $this->isPlatformAdmin($user)) {
            return false;
        }

        return DB::table('platform_role_user as role_user')
            ->join('platform_roles as roles', 'roles.id', '=', 'role_user.platform_role_id')
            ->leftJoin('platform_permission_role as permission_role', 'permission_role.platform_role_id', '=', 'roles.id')
            ->leftJoin('platform_permissions as permissions', 'permissions.id', '=', 'permission_role.platform_permission_id')
            ->where('role_user.user_id', $user->id)
            ->where(fn ($query) => $query->where('roles.is_root', true)->orWhere('permissions.key', $permission))
            ->exists();
    }
}
