<?php

use App\Services\CashBoxSyncService;
use App\Services\PhinixRemapService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Every account directly under 13 "الأموال الجاهزة" becomes a box. Existing boxes are untouched. */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('financial_accounts', 'catalog_source')) {
            return;
        }
        $remap = app(PhinixRemapService::class);
        $sync = app(CashBoxSyncService::class);
        foreach (DB::table('tenants')->pluck('id') as $tenantId) {
            if ($remap->isPhinixTenant((int) $tenantId)) {
                $sync->syncTenant((int) $tenantId);
            }
        }
    }

    public function down(): void {}
};
