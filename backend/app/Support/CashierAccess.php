<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * The single authorization boundary for the Cashier operational surface.
 *
 * Deliberately narrow: two read permissions, mapped by tenant role code. This
 * grants no finance.*, inventory.*, reports.* or accounting.* ability — the
 * dashboard's finance and inventory sections are additionally gated by the
 * actor's existing FinanceAccess / InventoryAccess permissions, so this class
 * can never widen what a Cashier may already see elsewhere.
 */
final class CashierAccess
{
    /** Read the Cashier's own operational shift dashboard. */
    public const DASHBOARD_VIEW = 'cashier.dashboard.view';

    /** Read quantities (never valuation) for the effective POS warehouse. */
    public const INVENTORY_VIEW = 'cashier.inventory.view';

    public const CATALOG = [self::DASHBOARD_VIEW, self::INVENTORY_VIEW];

    /**
     * Every operational tenant role runs shifts at a POS, so each may read its
     * own operational dashboard. Scope — not role — is what keeps one actor out
     * of another's drawer: the service filters to the caller's own open shift
     * and to branches BranchAccessService already allows.
     *
     * @var array<string, list<string>>
     */
    private const ROLE_PERMISSIONS = [
        'owner' => self::CATALOG,
        'manager' => self::CATALOG,
        'employee' => self::CATALOG,
    ];

    public static function actor(Request $request): User
    {
        $tenantId = (int) $request->attributes->get('tenant_id', 0);
        $authenticated = $request->attributes->get('auth_user');
        $userId = $authenticated instanceof User ? (int) $authenticated->id : 0;

        if ($tenantId <= 0 || $userId <= 0) {
            throw new HttpException(401, 'Unauthenticated.');
        }

        $user = User::query()->with('tenantRole')
            ->where('tenant_id', $tenantId)->where('id', $userId)->where('is_active', true)->first();

        if (! $user) {
            throw new HttpException(401, 'Unauthenticated.');
        }

        return $user;
    }

    public static function allows(Request $request, string $permission): bool
    {
        $permissions = self::ROLE_PERMISSIONS[self::actor($request)->effectiveRoleCode()] ?? [];

        return in_array($permission, $permissions, true);
    }

    public static function authorize(Request $request, string $permission): void
    {
        if (! self::allows($request, $permission)) {
            throw new HttpException(403, 'CASHIER_PERMISSION_DENIED');
        }
    }
}
