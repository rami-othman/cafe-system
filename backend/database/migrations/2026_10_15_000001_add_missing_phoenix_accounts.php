<?php

use App\Services\PhinixRemapService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Adds the Phoenix accounts the imported file lacked (61 misc. revenue, 62/621-629 deductions, 63-65,
 * 7/71) and moves the cash-overage default from 61 to 65. Idempotent; configuration only.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('financial_accounts', 'catalog_source') || ! Schema::hasTable('sales_account_mappings')) {
            return;
        }
        $service = app(PhinixRemapService::class);
        foreach (DB::table('tenants')->pluck('id') as $tenantId) {
            if ($service->isPhinixTenant((int) $tenantId)) {
                $service->remapConfiguration((int) $tenantId, true);
            }
        }
    }

    public function down(): void {}
};
