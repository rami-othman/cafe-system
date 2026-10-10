<?php

namespace App\Domain\Discount;

use App\Models\User;
use App\Services\DefaultTenantRoleService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Tenant-role authorization boundary for Discount administration and POS use. */
final class DiscountAccess
{
    public const VIEW = 'discounts.view';

    public const MANAGE = 'discounts.manage';

    public const APPLY_CONFIGURED = 'discounts.apply_configured';

    public const APPLY_MANUAL = 'discounts.apply_manual';

    public const SETTINGS_MANAGE = 'discounts.settings.manage';

    public const SUPPRESS_AUTOMATIC = 'discounts.automatic.suppress';

    public const CATALOG = [self::VIEW, self::MANAGE, self::APPLY_CONFIGURED, self::APPLY_MANUAL];

    public const ALL_PERMISSIONS = [...self::CATALOG, self::SETTINGS_MANAGE, self::SUPPRESS_AUTOMATIC];

    /** Administrative Discount Policy access; never available to the Employee role. */
    public const ADMINISTRATIVE = [self::VIEW, self::MANAGE];

    /** The only Discount grants the Employee role may hold: POS use, not administration. */
    public const EMPLOYEE_ASSIGNABLE = [self::APPLY_CONFIGURED, self::APPLY_MANUAL];

    public function allows(Request $request, string $permission): bool
    {
        $actor = $request->attributes->get('auth_user');
        if (! $actor instanceof User || ! in_array($permission, self::ALL_PERMISSIONS, true)) {
            return false;
        }
        if (in_array($permission, [self::SETTINGS_MANAGE, self::SUPPRESS_AUTOMATIC], true) && (! in_array($actor->effectiveRoleCode(), ['owner', 'manager'], true)
            || (int) $actor->tenant_id !== (int) $request->attributes->get('tenant_id')
            || ($actor->tenantRole && (int) $actor->tenantRole->tenant_id !== (int) $actor->tenant_id))) {
            return false;
        }
        if ($actor->isOwner()) {
            return true;
        }
        // Enforced here, not only by the stored grants, so a stale legacy
        // discounts.view/discounts.manage row on the Employee role is inert.
        if (in_array($permission, self::ADMINISTRATIVE, true) && $actor->effectiveRoleCode() === DefaultTenantRoleService::EMPLOYEE) {
            return false;
        }

        return DB::table('discount_role_permissions')
            ->where('tenant_id', $actor->tenant_id)
            ->where('role', $actor->effectiveRoleCode())
            ->where('permission', $permission)
            ->exists();
    }

    /** Coupon secrets are visible only to actors who may manage Discount Policies. */
    public function canSeeCouponCodes(Request $request): bool
    {
        return $this->allows($request, self::MANAGE);
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
