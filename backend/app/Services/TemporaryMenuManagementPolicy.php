<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;

/**
 * Transitional authorization boundary for the administrative Menu Management
 * surface. Replace this single policy with Permission Catalog checks in the
 * final permissions phase; do not distribute role checks across controllers.
 */
class TemporaryMenuManagementPolicy
{
    public function canManage(User $actor): bool
    {
        return in_array($actor->effectiveRoleCode(), [
            DefaultTenantRoleService::OWNER,
            DefaultTenantRoleService::MANAGER,
        ], true);
    }

    public function assertCanManage(User $actor): void
    {
        if (! $this->canManage($actor)) {
            throw new AuthorizationException('You are not allowed to manage menus.');
        }
    }
}
