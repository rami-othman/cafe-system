<?php

namespace App\Services;

use App\Domain\Discount\DiscountAccess;
use App\Models\TenantRole;
use App\Support\FinanceAccess;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class DefaultTenantRoleService
{
    public const OWNER = 'owner';

    public const MANAGER = 'manager';

    public const EMPLOYEE = 'employee';

    public const FACTORY_MANAGER = 'factory_manager';

    /**
     * Decision 6 (26/09/2026): factory_manager sees Finance in full, minus
     * permissions that are facility-wide rather than branch-operational (see
     * the 2026_10_05_000002 migration for the per-permission rationale).
     */
    public const FACTORY_MANAGER_FINANCE_EXCLUDED_PERMISSIONS = [
        'finance.settings.view',
        'finance.settings.manage',
        'finance.periods.manage',
        'finance.periods.lock',
        'finance.accounts.manage',
    ];

    /** @return array<string, TenantRole> */
    public function ensureForTenant(int $tenantId): array
    {
        $now = now();
        $existingRoles = DB::table('tenant_roles')->where('tenant_id', $tenantId)->pluck('code')->all();
        foreach ([self::OWNER => 'Owner', self::MANAGER => 'Manager', self::EMPLOYEE => 'Employee', self::FACTORY_MANAGER => 'Factory Manager'] as $code => $name) {
            DB::table('tenant_roles')->updateOrInsert(
                ['tenant_id' => $tenantId, 'code' => $code],
                ['name' => $name, 'is_system' => true, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now],
            );
        }

        // Owners retain their architecture-level implicit access. At this
        // development stage managers and employees intentionally start with
        // the same explicit Discount grants; later custom-role work can
        // replace these defaults without changing the authorization boundary.
        if (Schema::hasTable('discount_role_permissions')) {
            foreach ([self::MANAGER, self::EMPLOYEE] as $role) {
                if (in_array($role, $existingRoles, true)) {
                    continue;
                }
                foreach (DiscountAccess::CATALOG as $permission) {
                    DB::table('discount_role_permissions')->updateOrInsert(
                        ['tenant_id' => $tenantId, 'role' => $role, 'permission' => $permission],
                        ['created_at' => $now, 'updated_at' => $now],
                    );
                }
            }
            // One-time grant only. A missing grant after initialization is an
            // Owner revocation, never a reason to restore it during provisioning.
            if (Schema::hasColumn('tenant_roles', 'discount_settings_grant_initialized')) {
                DB::transaction(function () use ($tenantId, $now): void {
                    $role = DB::table('tenant_roles')->where('tenant_id', $tenantId)->where('code', self::MANAGER)->lockForUpdate()->first();
                    if (! $role->discount_settings_grant_initialized) {
                        DB::table('discount_role_permissions')->insertOrIgnore([
                            'tenant_id' => $tenantId, 'role' => self::MANAGER,
                            'permission' => DiscountAccess::SETTINGS_MANAGE,
                            'created_at' => $now, 'updated_at' => $now,
                        ]);
                        DB::table('tenant_roles')->where('id', $role->id)->update(['discount_settings_grant_initialized' => true]);
                    }
                });
            }
        }

        // factory_manager's Finance grant is seeded here (not just by a
        // one-time migration) so it also reaches tenants created after the
        // migration ran — the same gap that already exists for manager's
        // Finance defaults would otherwise repeat for every new tenant.
        if (Schema::hasTable('finance_role_permissions')) {
            $permissions = array_values(array_diff(FinanceAccess::CATALOG, self::FACTORY_MANAGER_FINANCE_EXCLUDED_PERMISSIONS));
            foreach ($permissions as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'role' => self::FACTORY_MANAGER, 'permission' => $permission],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            }
        }

        return TenantRole::query()->forTenant($tenantId)->whereIn('code', [self::OWNER, self::MANAGER, self::EMPLOYEE, self::FACTORY_MANAGER])->get()->keyBy('code')->all();
    }

    public function canonicalLegacyRole(string $code): string
    {
        return $code === self::EMPLOYEE ? 'cashier' : $code;
    }

    public function isAssignable(TenantRole $role): bool
    {
        return $role->is_active && in_array($role->code, [self::MANAGER, self::EMPLOYEE, self::FACTORY_MANAGER], true);
    }
}
