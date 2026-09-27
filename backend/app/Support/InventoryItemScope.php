<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class InventoryItemScope
{
    public static function assertForBranch(int $tenant, object $item, ?int $branch): void
    {
        $scope = $branch && DB::table('branches')->where('tenant_id', $tenant)->where('id', $branch)->value('branch_type') === 'factory' ? $branch : null;
        $owner = $item->owner_branch_id === null ? null : (int) $item->owner_branch_id;
        if ($owner !== $scope) throw ValidationException::withMessages(['lines' => 'هذه المادة تتبع نطاقاً آخر (المعمل/المقهى).']);
    }
}
