<?php

namespace App\Support;

use Illuminate\Http\Request;

class TenantContext
{
    public static function id(Request $request): int
    {
        $authenticatedTenantId = (int) $request->attributes->get('tenant_id', 0);

        if ($authenticatedTenantId > 0) {
            return $authenticatedTenantId;
        }

        // Header-selected tenants are retained only for legacy non-inventory
        // feature tests. Production request scope must come from the token.
        if (app()->environment('testing')) {
            $testTenantId = (int) $request->header('X-Tenant-Id', 0);
            if ($testTenantId > 0) {
                return $testTenantId;
            }
        }

        abort(401, 'Unauthenticated tenant context.');
    }
}
