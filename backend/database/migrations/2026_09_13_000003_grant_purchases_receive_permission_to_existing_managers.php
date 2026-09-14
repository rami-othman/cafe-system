<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Mirrors 2026_09_12_000003_grant_purchases_permissions_to_existing_managers:
     * FinanceAccess::CATALOG is the source of truth for which permission
     * strings exist, but existing tenants' `finance_role_permissions` rows
     * for the 'manager' role must be explicitly backfilled whenever a new
     * string is added — owners always get the full catalog implicitly.
     */
    public function up(): void
    {
        $now = now();
        foreach (DB::table('users')->where('role', 'manager')->distinct()->pluck('tenant_id') as $tenantId) {
            DB::table('finance_role_permissions')->updateOrInsert(
                ['tenant_id' => $tenantId, 'role' => 'manager', 'permission' => 'finance.purchases.receive'],
                ['created_at' => $now, 'updated_at' => $now],
            );
        }
    }

    public function down(): void
    {
        DB::table('finance_role_permissions')->where('permission', 'finance.purchases.receive')->delete();
    }
};
