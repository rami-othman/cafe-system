<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * The 2026_09_21 migration that introduced the
     * `sales.additional_charge_revenue` / `sales.manual_adjustment` mapping
     * keys was already recorded as run before its backfill loop populated
     * `sales_account_mappings` for existing tenants, so those tenants were
     * left without the mapping — posting any invoice with an additional
     * charge fails with SALES_ACCOUNT_NOT_CONFIGURED. Backfill it here from
     * each tenant's existing account 4030 (created by that same migration).
     */
    public function up(): void
    {
        $now = now();
        DB::table('tenants')->orderBy('id')->each(function (object $tenant) use ($now): void {
            $accountId = DB::table('financial_accounts')->where('tenant_id', $tenant->id)->where('code', '4030')->value('id');
            if (! $accountId) {
                return;
            }
            foreach (['sales.additional_charge_revenue', 'sales.manual_adjustment'] as $key) {
                DB::table('sales_account_mappings')->updateOrInsert(
                    ['tenant_id' => $tenant->id, 'mapping_key' => $key],
                    ['financial_account_id' => $accountId, 'updated_at' => $now, 'created_at' => $now],
                );
            }
        });
    }

    public function down(): void
    {
        DB::table('sales_account_mappings')->whereIn('mapping_key', ['sales.additional_charge_revenue', 'sales.manual_adjustment'])->delete();
    }
};
