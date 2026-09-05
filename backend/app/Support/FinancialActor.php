<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
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

        $actor = User::query()->with('tenantRole')->where('tenant_id', $tenantId)->find($actorId);
        if ($actor?->effectiveRoleCode() === 'owner') {
            return;
        }

        $allowed = DB::table('user_branches')->where('tenant_id', $tenantId)->where('user_id', $actorId)->where('branch_id', $branchId)->exists();
        if (! $allowed) {
            throw new HttpException(403, 'The selected branch is not assigned to this user.');
        }
    }
}
