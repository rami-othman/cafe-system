<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;

class CafeConfigurationPolicy
{
    public function assertCanManageBranches(User $actor): void
    {
        if (! $actor->isOwner()) {
            throw new AuthorizationException('You are not allowed to manage cafe configuration.');
        }
    }
}
