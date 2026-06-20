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

        $tenantId = (int) $request->header('X-Tenant-Id', 0);

        if ($tenantId > 0) {
            return $tenantId;
        }

        return (int) DB::table('tenants')->orderBy('id')->value('id');
    }
}
