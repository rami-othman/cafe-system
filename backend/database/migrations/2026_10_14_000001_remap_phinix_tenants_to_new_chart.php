<?php

use App\Services\PhinixRemapService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Configuration only (no journal is posted): every tenant that already imported the phinix chart
 * is re-pointed to it, so a deploy to the server fixes mappings, payment methods, cash locations,
 * expense categories and party accounts in one go. Balances are moved separately and deliberately
 * with `php artisan finance:remap-to-phinix {tenant} --balances --apply`.
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
