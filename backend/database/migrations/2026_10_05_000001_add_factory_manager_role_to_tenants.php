<?php

use App\Services\DefaultTenantRoleService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $service = app(DefaultTenantRoleService::class);
        foreach (DB::table('tenants')->pluck('id') as $tenantId) {
            $service->ensureForTenant((int) $tenantId);
        }
    }

    public function down(): void
    {
        DB::table('tenant_roles')->where('code', DefaultTenantRoleService::FACTORY_MANAGER)->delete();
    }
};
