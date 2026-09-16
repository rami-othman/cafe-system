<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Scoped authorization boundary for the cashier "own shift bar check" flow.
 *
 * Owner/manager keep the exact coarse InventoryAccess role permissions they
 * already have. An employee (cashier) holds no general inventory permission
 * (see InventoryAccess::ROLE_PERMISSIONS) and may act only on their own,
 * currently open shift's shift_check stock count — never on a general
 * (full/cycle) count, a template definition, or another user's shift.
 */
final class BarCheckAccess
{
    private const EMPLOYEE = 'employee';

    private const ADMIN_ROLES = ['owner', 'manager'];

    /** GET bar-check-templates (index/show): read-only, branch-scoped in the controller. */
    public static function authorizeTemplatesRead(Request $request): void
    {
        $actor = InventoryAccess::actor($request);
        if (in_array($actor->effectiveRoleCode(), self::ADMIN_ROLES, true)) {
            InventoryAccess::authorize($request, 'inventory.counts.view');

            return;
        }
        self::assertEmployee($actor);
    }

    /** GET bar-checks (list): employees only ever see their own shifts (filtered in the controller). */
    public static function authorizeBarChecksIndex(Request $request): void
    {
        $actor = InventoryAccess::actor($request);
        if (in_array($actor->effectiveRoleCode(), self::ADMIN_ROLES, true)) {
            InventoryAccess::authorize($request, 'inventory.counts.view');

            return;
        }
        self::assertEmployee($actor);
    }

    /** POST bar-checks (start): the shiftId in the request body must be the employee's own open shift. */
    public static function authorizeStart(Request $request): void
    {
        $actor = InventoryAccess::actor($request);
        if (in_array($actor->effectiveRoleCode(), self::ADMIN_ROLES, true)) {
            InventoryAccess::authorize($request, 'inventory.counts.create');

            return;
        }
        self::assertEmployee($actor);
        self::assertOwnOpenShift($actor, (int) $request->input('shiftId', 0));
    }

    /**
     * GET/PUT/POST counts/{count}[/...]: the {count} route parameter must be
     * the employee's own shift_check row. Mutating permissions additionally
     * require the underlying shift to still be open.
     */
    public static function authorizeCount(Request $request, string $permission): void
    {
        $actor = InventoryAccess::actor($request);
        if (in_array($actor->effectiveRoleCode(), self::ADMIN_ROLES, true)) {
            InventoryAccess::authorize($request, $permission);

            return;
        }
        self::assertEmployee($actor);

        $countId = (int) $request->route('count');
        $count = DB::table('stock_counts')
            ->where('tenant_id', (int) $actor->tenant_id)
            ->where('id', $countId)
            ->first();

        if (! $count || $count->count_type !== 'shift_check' || $count->shift_id === null) {
            self::deny();
        }

        $shift = DB::table('shifts')
            ->where('tenant_id', (int) $actor->tenant_id)
            ->where('id', $count->shift_id)
            ->whereNull('deleted_at')
            ->first();

        if (! $shift || (int) $shift->user_id !== (int) $actor->id) {
            self::deny();
        }

        if ($permission !== 'inventory.counts.view' && $shift->status !== 'open') {
            throw new HttpException(403, 'This shift is no longer open.');
        }
    }

    private static function assertEmployee(User $actor): void
    {
        if ($actor->effectiveRoleCode() !== self::EMPLOYEE) {
            self::deny();
        }
    }

    private static function assertOwnOpenShift(User $actor, int $shiftId): void
    {
        if ($shiftId <= 0) {
            self::deny();
        }

        $shift = DB::table('shifts')
            ->where('tenant_id', (int) $actor->tenant_id)
            ->where('id', $shiftId)
            ->where('status', 'open')
            ->whereNull('deleted_at')
            ->first();

        if (! $shift || (int) $shift->user_id !== (int) $actor->id) {
            self::deny();
        }
    }

    private static function deny(): never
    {
        throw new HttpException(403, 'You do not have permission to perform this inventory action.');
    }
}
