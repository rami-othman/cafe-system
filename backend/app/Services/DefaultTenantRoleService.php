<?php

namespace App\Services;

use App\Models\TenantRole;
use Illuminate\Support\Facades\DB;

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
