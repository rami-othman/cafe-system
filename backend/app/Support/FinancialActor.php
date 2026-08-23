<?php

namespace App\Support;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class FinancialActor
{
    public static function id(Request $request, int $tenantId): ?int
    {
        $authenticated = $request->attributes->get('auth_user');
        $requestedId = is_array($authenticated) ? (int) ($authenticated['id'] ?? 0) : (int) $request->header('X-User-Id', 0);
        if ($requestedId <= 0) {
            return null;
        }

        $user = DB::table('users')->where('tenant_id', $tenantId)->where('id', $requestedId)->where('is_active', true)->whereNull('deleted_at')->first();
        abort_unless($user, 403, 'The selected user is not allowed for this tenant.');
        abort_unless(in_array($user->role, ['owner', 'manager'], true), 403, 'Finance setup requires an owner or manager.');

        return (int) $user->id;
    }

    public static function assertBranchAccess(?int $actorId, int $tenantId, ?int $branchId): void
    {
        if (! $actorId || ! $branchId) {
            return;
        }

        $role = DB::table('users')->where('id', $actorId)->value('role');
        if ($role === 'owner') {
            return;
        }

        $allowed = DB::table('user_branches')->where('tenant_id', $tenantId)->where('user_id', $actorId)->where('branch_id', $branchId)->exists();
        if (! $allowed) {
            throw new HttpException(403, 'The selected branch is not assigned to this user.');
        }
    }
}
