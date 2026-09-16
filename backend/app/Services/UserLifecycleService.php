<?php

namespace App\Services;

use App\Models\ApiToken;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class UserLifecycleService
{
    public function deactivate(User $user): void
    {
        $this->assertLifecycleChangeAllowed($user);

        DB::transaction(function () use ($user): void {
            $user->forceFill(['is_active' => false])->save();
            $this->revokeAllUserTokens($user);
        });
    }

    public function reactivate(User $user): void
    {
        if ($user->trashed()) {
            throw new DomainException('Archived users must not be reactivated without an explicit restore workflow.');
        }

        $user->forceFill(['is_active' => true])->save();
    }

    public function archive(User $user): void
    {
        $this->assertLifecycleChangeAllowed($user);

        DB::transaction(function () use ($user): void {
            $user->forceFill(['is_active' => false])->save();
            $this->revokeAllUserTokens($user);
            $user->delete();
        });
    }

    public function revokeAllUserTokens(User $user): void
    {
        ApiToken::query()
            ->where('user_id', $user->id)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now(), 'updated_at' => now()]);
    }

    public function revokeAllUserTokensExcept(User $user, ApiToken $currentToken): void
    {
        ApiToken::query()
            ->where('user_id', $user->id)
            ->where('id', '!=', $currentToken->id)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now(), 'updated_at' => now()]);
    }

    /**
     * Changes password authority as one unit: a failure to revoke stale
     * sessions must leave both the password and the forced-change flag intact.
     */
    public function changePassword(User $user, string $newPassword, ApiToken $currentToken): void
    {
        DB::transaction(function () use ($user, $newPassword, $currentToken): void {
            $user->forceFill([
                'password' => Hash::make($newPassword),
                'must_change_password' => false,
            ])->save();
            $this->revokeAllUserTokensExcept($user, $currentToken);
        });
    }

    private function assertLifecycleChangeAllowed(User $user): void
    {
        if ($user->isOwner()) {
            throw new DomainException('The tenant owner is protected from generic lifecycle changes.');
        }
    }
}
