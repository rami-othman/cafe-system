<?php

namespace App\Support;

use App\Models\User;
use App\Services\BranchAccessService;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class FinancialActor
{
    public static function id(Request $request, int $tenantId): ?int
    {
        $authenticated = $request->attributes->get('auth_user');
        if (! $authenticated instanceof User) {
            throw new HttpException(401, 'Authenticated actor is required.');
        }

        $requestedId = (int) $authenticated->id;

        $user = User::query()->where('tenant_id', $tenantId)->where('id', $requestedId)->where('is_active', true)->first();
        abort_unless($user, 403, 'The selected user is not allowed for this tenant.');
        return (int) $user->id;
    }

    public static function assertBranchAccess(?int $actorId, int $tenantId, ?int $branchId): void
    {
        if (! $actorId) {
            throw new HttpException(401, 'Authenticated actor is required.');
        }
        if (! $branchId) {
            return;
        }

        app(BranchAccessService::class)->authorize(self::user($actorId, $tenantId), $branchId);
    }

    /** @return list<int> */
    public static function operationalBranchIds(int $actorId, int $tenantId): array
    {
        return app(BranchAccessService::class)->accessibleBranchIds(self::user($actorId, $tenantId));
    }

    private static function user(int $actorId, int $tenantId): User
    {
        $actor = User::query()->with('tenantRole')->where('tenant_id', $tenantId)->where('id', $actorId)->where('is_active', true)->first();
        if (! $actor) {
            throw new HttpException(403, 'The selected user is not allowed for this tenant.');
        }

        return $actor;
    }
}
