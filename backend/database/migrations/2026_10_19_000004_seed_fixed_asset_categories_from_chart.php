<?php

use App\Services\FixedAssets\AssetCatalogService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * For tenants whose chart has "11 الموجودات الثابتة" (the Phinix chart): one asset category per
 * fixed-asset group with its asset / accumulated / expense accounts pre-linked. Idempotent and
 * configuration only — no journal entries.
 */
return new class extends Migration
{
    public function up(): void
    {
        $service = app(AssetCatalogService::class);
        foreach (DB::table('tenants')->pluck('id') as $tenantId) {
            if (DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '11')->whereNull('deleted_at')->exists()) {
                $service->seedFromChart((int) $tenantId);
            }
        }
    }

    public function down(): void {}
};
