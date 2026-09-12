<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Phase 4 needs a liability control account for unapplied customer credit
 * (a Credit Note that exceeds an invoice's outstanding AR — see docs/sales
 * ADR "Credit Note Ownership"). No such account exists yet (only 2000 AP
 * and 2010 Sales Tax Payable are liabilities). This adds the protected
 * default account 2020 and maps it, plus maps the already-existing 4020
 * "Sales Returns" contra-revenue account, for every existing tenant.
 */
return new class extends Migration
{
    public function up(): void
    {
        $now = now();
        DB::table('tenants')->orderBy('id')->each(function (object $tenant) use ($now): void {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenant->id)->where('code', '2020')->first();
            if ($account && ($account->account_group !== 'liabilities' || $account->normal_balance !== 'credit')) {
                throw new RuntimeException("Tenant {$tenant->id} has an incompatible account 2020; expected a liabilities account with credit normal balance.");
            }
            if (! $account) {
                $accountId = DB::table('financial_accounts')->insertGetId([
                    'tenant_id' => $tenant->id, 'code' => '2020', 'name_ar' => 'أرصدة دائنة للعملاء', 'name_en' => 'Customer Credit Balance',
                    'account_group' => 'liabilities', 'normal_balance' => 'credit', 'is_active' => true, 'is_system_protected' => true,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
            } else {
                $accountId = $account->id;
            }
            DB::table('sales_account_mappings')->updateOrInsert(
                ['tenant_id' => $tenant->id, 'mapping_key' => 'sales.customer_credit'],
                ['financial_account_id' => $accountId, 'updated_at' => $now, 'created_at' => $now],
            );

            $returnsAccountId = DB::table('financial_accounts')->where('tenant_id', $tenant->id)->where('code', '4020')->where('account_group', 'revenue')->where('normal_balance', 'debit')->value('id');
            if ($returnsAccountId && ! DB::table('sales_account_mappings')->where('tenant_id', $tenant->id)->where('mapping_key', 'sales.sales_returns')->exists()) {
                DB::table('sales_account_mappings')->insert(['tenant_id' => $tenant->id, 'mapping_key' => 'sales.sales_returns', 'financial_account_id' => $returnsAccountId, 'created_at' => $now, 'updated_at' => $now]);
            }
        });
    }

    public function down(): void
    {
        DB::table('sales_account_mappings')->whereIn('mapping_key', ['sales.customer_credit', 'sales.sales_returns'])->delete();
    }
};
