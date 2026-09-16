<?php

namespace App\Domain\Discount;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Tenant-role authorization boundary for Discount administration and POS use. */
final class DiscountAccess
{
    public const VIEW = 'discounts.view';

    public const MANAGE = 'discounts.manage';

    public const APPLY_CONFIGURED = 'discounts.apply_configured';

    public const APPLY_MANUAL = 'discounts.apply_manual';

    public const CATALOG = [self::VIEW, self::MANAGE, self::APPLY_CONFIGURED, self::APPLY_MANUAL];

    public function allows(Request $request, string $permission): bool
    {
        $actor = $request->attributes->get('auth_user');
        if (! $actor instanceof User || ! in_array($permission, self::CATALOG, true)) {
            return false;
        }
        if ($actor->isOwner()) {
            return true;
        }

        return DB::table('discount_role_permissions')
            ->where('tenant_id', $actor->tenant_id)
            ->where('role', $actor->effectiveRoleCode())
            ->where('permission', $permission)
            ->exists();
    }

    public function authorize(Request $request, string $permission): void
    {
        abort_unless($this->allows($request, $permission), 403, 'Discount permission denied.');
    }

    public function assertOwner(Request $request): User
    {
        $actor = $request->attributes->get('auth_user');
        abort_unless($actor instanceof User && $actor->isOwner(), 403, 'Discount permission denied.');

        return $actor;
    }
}
