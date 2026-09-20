<?php

use App\Support\FinanceAccess;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * FinanceAccess::permissionsFor() used to union a live
 * defaultPermissionsForRole('manager') (the full catalog) into every
 * manager's permission set, which made finance_role_permissions inert for
 * that role — any manager was implicitly fully trusted regardless of what
 * was configured. That was a regression (see commit f58c61c); manager
 * permissions are meant to be entirely table-driven, same as the
 * "grant X to existing managers" migrations already assume.
 *
 * Removing the implicit default now makes any manager row that never had an
 * explicit finance_role_permissions grant lose access it effectively had
 * before. This backfills the full catalog for every existing manager so
 * already-provisioned tenants see no behavior change; from here on, new
 * grants/restrictions for a manager go through
 * FinanceRolePermissionController::replace as intended.
 */
return new class extends Migration
{
    public function up(): void
    {
        $now = now();
        foreach (DB::table('users')->select('tenant_id')->where('role', 'manager')->distinct()->pluck('tenant_id') as $tenantId) {
            foreach (FinanceAccess::defaultPermissionsForRole('manager') as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'role' => 'manager', 'permission' => $permission],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            }
        }
    }

    public function down(): void
    {
        // Additive backfill only; not reversed, to avoid stripping
        // permissions an owner may have deliberately kept since.
    }
};
