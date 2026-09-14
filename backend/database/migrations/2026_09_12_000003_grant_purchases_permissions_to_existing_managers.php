<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Mirrors 2026_09_10_000018_grant_voucher_permissions_to_existing_managers:
     * FinanceAccess::CATALOG is the source of truth for which permission
     * strings exist, but existing tenants' `finance_role_permissions` rows
     * for the 'manager' role must be explicitly backfilled whenever a new
     * string is added to the catalog — owners always get the full catalog
     * implicitly, so this only affects the manager role.
     */
    public function up(): void
    {
        $now = now();
        $permissions = ['finance.purchases.view', 'finance.purchases.create', 'finance.purchases.edit', 'finance.purchases.post'];
        foreach (DB::table('users')->where('role', 'manager')->distinct()->pluck('tenant_id') as $tenantId) {
            foreach ($permissions as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'role' => 'manager', 'permission' => $permission],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            }
        }
    }

    public function down(): void
    {
        DB::table('finance_role_permissions')->whereIn('permission', ['finance.purchases.view', 'finance.purchases.create', 'finance.purchases.edit', 'finance.purchases.post'])->delete();
    }
};
