<?php

namespace App\Support;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TenantContext
{
    public static function id(Request $request): int
    {
        $authenticatedTenantId = (int) $request->attributes->get('tenant_id', 0);

        if ($authenticatedTenantId > 0) {
            return $authenticatedTenantId;
        }

        if ($request->attributes->get('tenant_context_protected')) {
            abort(401, 'Authenticated tenant context is required.');
        }

        // Temporary legacy fallback for routes not yet moved to the Auth boundary.
        $tenantId = (int) $request->header('X-Tenant-Id', 0);

        if ($tenantId > 0) {
            return $tenantId;
        }

        return (int) DB::table('tenants')->orderBy('id')->value('id');
    }
}