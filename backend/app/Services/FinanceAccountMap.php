<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * One place that answers "which ledger account does this posting use?" so no posting path
 * carries a hard-coded account code. A tenant maps each key to ONE of its accounts
 * (table sales_account_mappings); a tenant without a mapping row falls back to the legacy
 * seeded code, so old tenants keep working until they are remapped to the new chart.
 */
final class FinanceAccountMap
{
    /** key => legacy default code (used only when the tenant has no mapping row for the key). */
    public const LEGACY = [
        'sales.revenue' => '4000',
        'sales.discount_given' => '4010',
        'sales.tax_payable' => '2010',
        'sales.cost_of_goods_sold' => '5000',
        'sales.inventory_asset' => '1100',
        'sales.sales_returns' => '4020',
        'sales.customer_credit' => '2020',
        'sales.accounts_receivable' => '1200',
        'sales.additional_charge_revenue' => '4030',
        'sales.manual_adjustment' => '4030',
        'inventory.variance' => '5010',
        'inventory.opening_equity' => '3000',
        'cash.over' => '4040',
        'cash.short' => '6180',
        'cash.drawer' => '1010',
    ];

    /** The account row mapped to $key (active, not deleted), or null when none is usable. */
    public function account(int $tenantId, string $key): ?object
    {
        $mapped = DB::table('sales_account_mappings as m')
            ->join('financial_accounts as a', 'a.id', '=', 'm.financial_account_id')
            ->where('m.tenant_id', $tenantId)->where('m.mapping_key', $key)->where('a.tenant_id', $tenantId)
            ->where('a.is_active', true)->whereNull('a.deleted_at')
            ->first(['a.id', 'a.code', 'a.account_group', 'a.normal_balance']);
        if ($mapped) {
            return $mapped;
        }
        if (DB::table('sales_account_mappings')->where('tenant_id', $tenantId)->where('mapping_key', $key)->exists()) {
            return null; // mapped on purpose to an account that is no longer usable: do not silently use the legacy one
        }
        $legacy = self::LEGACY[$key] ?? null;

        return $legacy === null ? null : DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', $legacy)
            ->where('is_active', true)->whereNull('deleted_at')->first(['id', 'code', 'account_group', 'normal_balance']);
    }

    public function code(int $tenantId, string $key): string
    {
        $account = $this->account($tenantId, $key);
        if (! $account) {
            throw ValidationException::withMessages(['finance' => "ACCOUNT_NOT_CONFIGURED: {$key}"]);
        }

        return (string) $account->code;
    }

    public function id(int $tenantId, string $key): int
    {
        $account = $this->account($tenantId, $key);
        if (! $account) {
            throw ValidationException::withMessages(['finance' => "ACCOUNT_NOT_CONFIGURED: {$key}"]);
        }

        return (int) $account->id;
    }
}
