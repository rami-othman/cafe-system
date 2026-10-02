<?php

use App\Services\FinancialSetupService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Sham Cash gets its own box (asset account 1040 + location SHAM-CASH + payment method), and the
 * customer wallet method is added. Existing names and mappings are never overwritten.
 */
return new class extends Migration
{
    public function up(): void
    {
        $now = now();
        foreach (DB::table('tenants')->pluck('id') as $tenantId) {
            if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1040')->exists()) {
                DB::table('financial_accounts')->insert([
                    'tenant_id' => $tenantId, 'code' => '1040', 'name_ar' => 'صندوق الشام كاش', 'name_en' => 'Sham Cash Box',
                    'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true,
                    'is_system_protected' => true, 'created_at' => $now, 'updated_at' => $now,
                ]);
            }
            app(FinancialSetupService::class)->ensureSettlementMethodDefaults((int) $tenantId);
        }
    }

    public function down(): void
    {
        // Configuration rows may already be referenced by payments; they are intentionally kept.
    }
};
