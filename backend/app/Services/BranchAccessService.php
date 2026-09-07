<?php

namespace App\Services;

use App\Models\Branch;
use App\Models\User;
use Illuminate\Http\Request;

class BranchAccessService
{
    public function canAccessBranch(User $user, Branch $branch): bool
    {
        if ((int) $user->tenant_id !== (int) $branch->tenant_id) {
            return false;
        }

        // This service defines operational access. Inactive branches retain
        // their historical records, but may not be selected or used for new
        // tenant operations by any role, including the implicit Owner scope.
        if ($branch->trashed() || ! $branch->is_active) {
            return false;
        }

        if ($user->isOwner()) {
            return true;
        }

        return $user->branches()->whereKey($branch->id)->exists();
    }

    /**
     * Resolve a branch inside the authenticated tenant and enforce the single
     * operational branch-access policy.  A foreign-tenant branch is treated
     * as missing so tenant boundaries do not disclose its existence.
     */
    public function authorize(User $user, int $branchId): Branch
    {
        $branch = Branch::query()
            ->where('tenant_id', $user->tenant_id)
            ->whereNull('deleted_at')
            ->where('is_active', true)
            ->find($branchId);

        abort_if(! $branch, 404, 'Branch not found.');
        abort_unless($this->canAccessBranch($user, $branch), 403, 'This branch is not assigned to the authenticated user.');

        return $branch;
    }

    /** @return array<int, int> */
    public function accessibleBranchIds(User $user): array
    {
        if ($user->isOwner()) {
            return Branch::query()->where('tenant_id', $user->tenant_id)->whereNull('deleted_at')->where('is_active', true)->pluck('id')->map(fn ($id) => (int) $id)->all();
        }

        return $user->branches()->whereNull('branches.deleted_at')->where('branches.is_active', true)->pluck('branches.id')->map(fn ($id) => (int) $id)->all();
    }

    public function authorizeRequestBranch(Request $request, int $branchId): Branch
    {
        $user = $request->attributes->get('auth_user');
        abort_unless($user instanceof User, 401, 'Authenticated user is required.');

        return $this->authorize($user, $branchId);
    }
}
