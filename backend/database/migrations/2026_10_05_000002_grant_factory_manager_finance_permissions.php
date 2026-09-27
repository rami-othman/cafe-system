<?php

use App\Services\DefaultTenantRoleService;
use App\Support\FinanceAccess;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Decision 6 (26/09/2026): the factory_manager sees Finance in full, but
     * only for the factory branch (branch scoping itself is a later phase —
     * see FACTORY_EXECUTION_PROMPTS_2026-09-26.md prompt 5). This migration
     * backfills existing tenants; DefaultTenantRoleService::ensureForTenant
     * seeds the same grant (minus the same exclusions) for every tenant going
     * forward, so newly created tenants are covered too.
     *
     * Excluded (see DefaultTenantRoleService::FACTORY_MANAGER_FINANCE_EXCLUDED_PERMISSIONS):
     *  - finance.settings.view / finance.settings.manage: tenant-wide Finance
     *    configuration (currency, fiscal year, etc.), not a branch concern.
     *  - finance.periods.manage / finance.periods.lock: accounting period
     *    close/lock affects the whole tenant ledger, not one branch.
     *  - finance.accounts.manage: the chart of accounts structure is shared
     *    across all branches; only Owner may change it. finance.accounts.view
     *    (read) is kept.
     * Role-permission management itself (FinanceRolePermissionController)
     * is not part of FinanceAccess::CATALOG — it is gated by an explicit
     * isOwner() check, so it needs no exclusion here.
     */
    public function up(): void
    {
        $now = now();
        $permissions = array_values(array_diff(FinanceAccess::CATALOG, DefaultTenantRoleService::FACTORY_MANAGER_FINANCE_EXCLUDED_PERMISSIONS));
        foreach (DB::table('tenants')->pluck('id') as $tenantId) {
            foreach ($permissions as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'role' => DefaultTenantRoleService::FACTORY_MANAGER, 'permission' => $permission],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            }
        }
    }

    public function down(): void
    {
        DB::table('finance_role_permissions')->where('role', DefaultTenantRoleService::FACTORY_MANAGER)->delete();
    }
};
