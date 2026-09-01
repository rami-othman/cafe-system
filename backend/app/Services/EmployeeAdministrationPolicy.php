<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;

class EmployeeAdministrationPolicy
{
    public function canManageEmployees(User $actor): bool
    {
        return in_array($actor->effectiveRoleCode(), [DefaultTenantRoleService::OWNER, DefaultTenantRoleService::MANAGER], true);
    }

    public function assertCanManageEmployees(User $actor): void
    {
        if (! $this->canManageEmployees($actor)) {
            throw new AuthorizationException('You are not allowed to manage employees.');
        }
    }

    public function assertCanManageTarget(User $actor, User $target): void
    {
        $this->assertCanManageEmployees($actor);
        if ($target->isOwner() || ($actor->effectiveRoleCode() === DefaultTenantRoleService::MANAGER && $actor->is($target))) {
            throw new AuthorizationException('This employee cannot be managed through this endpoint.');
        }
    }
}
