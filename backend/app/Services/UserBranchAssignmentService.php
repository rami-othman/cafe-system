<?php

namespace App\Services;

use App\Models\Branch;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;

class UserBranchAssignmentService
{
    public function assign(User $user, Branch $branch): void
    {
        $this->sync($user, [$branch->id], false);
    }

    /** @param array<int, int> $branchIds */
    public function sync(User $user, array $branchIds, bool $requireAtLeastOne = true): void
    {
        $branchIds = array_values(array_unique(array_map('intval', $branchIds)));
        if ($requireAtLeastOne && $branchIds === []) {
            throw new DomainException('Active non-owner users require at least one branch assignment.');
        }

        $validCount = DB::table('branches')
            ->where('tenant_id', $user->tenant_id)
            ->whereNull('deleted_at')
            ->where('is_active', true)
            ->whereIn('id', $branchIds)
            ->count();
        if ($validCount !== count($branchIds)) {
            throw new DomainException('One or more branches are not active branches of this tenant.');
        }

        $user->branches()->sync(collect($branchIds)->mapWithKeys(fn (int $id) => [$id => ['tenant_id' => $user->tenant_id]])->all());
    }
}
