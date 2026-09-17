<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private const PERMISSIONS = [
        'finance.vouchers.view',
        'finance.purchases.view',
        'finance.sales.view',
        // The Purchases/Sales/Vouchers screens all render reference-data
        // dropdowns (supplier, asset account, expense category, payment
        // method) from these three endpoints before a form is usable — the
        // three workspace-level permissions above only cover the workspace's
        // own list/detail routes, not the shared lookups its forms depend on.
        'finance.suppliers.view',
        'finance.accounts.view',
        'finance.settings.view',
        // Vouchers additionally needs the cash/bank location picker; Sales
        // additionally needs the customer picker and the "register payment"
        // dialog's receivables lookup.
        'finance.cash_accounts.view',
        'finance.customers.view',
        'finance.customer_payments.view',
    ];

    /**
     * The Downtown cashier has an explicitly limited finance surface: these
     * workspaces are visible, while all other financial areas remain hidden.
     * Mutating capabilities are intentionally not granted here.
     *
     * `finance_role_permissions.role` is matched against
     * `DefaultTenantRoleService::canonicalLegacyRole($actor->effectiveRoleCode())`
     * (see `FinanceAccess::permissionsFor`), and that translation maps the
     * `employee` tenant role to the legacy string `cashier` for finance
     * purposes specifically — unlike `CashierAccess`/`InventoryAccess`, which
     * key their own role maps on `employee` directly. The grant must target
     * `cashier` here, or `canonicalLegacyRole` never finds it.
     */
    public function up(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        if (! $tenantId) {
            return;
        }

        $now = now();
        foreach (self::PERMISSIONS as $permission) {
            DB::table('finance_role_permissions')->updateOrInsert(
                ['tenant_id' => $tenantId, 'role' => 'cashier', 'permission' => $permission],
                ['created_at' => $now, 'updated_at' => $now],
            );
        }
    }

    public function down(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        if ($tenantId) {
            DB::table('finance_role_permissions')
                ->where('tenant_id', $tenantId)
                ->where('role', 'cashier')
                ->whereIn('permission', self::PERMISSIONS)
                ->delete();
        }
    }
};
