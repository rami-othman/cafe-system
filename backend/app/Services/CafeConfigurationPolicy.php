<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;

/**
 * Narrow v1 boundary for tenant Cafe Configuration. This deliberately stays
 * separate from the future granular permission matrix.
 */
class CafeConfigurationPolicy
{
    public function assertCanManageBranches(User $actor): void
    {
        if (! $actor->isOwner()) {
            throw new AuthorizationException('You are not allowed to manage cafe configuration.');
        }
    }
}
