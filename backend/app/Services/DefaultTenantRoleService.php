<?php

namespace App\Services;

use App\Domain\Discount\DiscountAccess;
use App\Models\TenantRole;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class DefaultTenantRoleService
{
    public const OWNER = 'owner';

    public const MANAGER = 'manager';

    public const EMPLOYEE = 'employee';

    /** @return array<string, TenantRole> */
    public function ensureForTenant(int $tenantId): array
    {
        $now = now();
        foreach ([self::OWNER => 'Owner', self::MANAGER => 'Manager', self::EMPLOYEE => 'Employee'] as $code => $name) {
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
                foreach (DiscountAccess::CATALOG as $permission) {
                    DB::table('discount_role_permissions')->updateOrInsert(
                        ['tenant_id' => $tenantId, 'role' => $role, 'permission' => $permission],
                        ['created_at' => $now, 'updated_at' => $now],
                    );
                }
            }
        }

        return TenantRole::query()->forTenant($tenantId)->whereIn('code', [self::OWNER, self::MANAGER, self::EMPLOYEE])->get()->keyBy('code')->all();
    }

    public function canonicalLegacyRole(string $code): string
    {
        return $code === self::EMPLOYEE ? 'cashier' : $code;
    }

    public function isAssignable(TenantRole $role): bool
    {
        return $role->is_active && in_array($role->code, [self::MANAGER, self::EMPLOYEE], true);
    }
}
