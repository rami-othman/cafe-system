<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Resolves tenant Finance configuration by stable mapping key, never account database ID. */
final class SalesAccountResolver
{
    /** @return array{accountsReceivable:string,revenue:string,taxPayable:string,cogs:string,inventory:string} */
    public function postingAccounts(int $tenantId): array
    {
        return [
            'accountsReceivable' => $this->accountsReceivable($tenantId),
            'revenue' => $this->code($tenantId, 'sales.revenue', 'revenue', 'credit'),
            'taxPayable' => $this->code($tenantId, 'sales.tax_payable', 'liabilities', 'credit'),
            'cogs' => $this->code($tenantId, 'sales.cost_of_goods_sold', 'cost_of_sales', 'debit'),
            'inventory' => $this->code($tenantId, 'sales.inventory_asset', 'assets', 'debit'),
        ];
    }

    /** The single AR control account code — shared by invoice posting (credit) and customer payment settlement (debit). */
    public function accountsReceivable(int $tenantId): string
    {
        return $this->code($tenantId, 'sales.accounts_receivable', 'assets', 'debit');
    }

    /** @return array{accountsReceivable:string,salesReturns:string,taxPayable:string,cogs:string,inventory:string,customerCredit:string} */
    public function creditNoteAccounts(int $tenantId): array
    {
        return [
            'accountsReceivable' => $this->accountsReceivable($tenantId),
            'salesReturns' => $this->code($tenantId, 'sales.sales_returns', 'revenue', 'debit'),
            'taxPayable' => $this->code($tenantId, 'sales.tax_payable', 'liabilities', 'credit'),
            'cogs' => $this->code($tenantId, 'sales.cost_of_goods_sold', 'cost_of_sales', 'debit'),
            'inventory' => $this->code($tenantId, 'sales.inventory_asset', 'assets', 'debit'),
            'customerCredit' => $this->code($tenantId, 'sales.customer_credit', 'liabilities', 'credit'),
        ];
    }

    /** The unapplied customer-credit control account — shared by Credit Notes (credit) and Customer Refunds (debit). */
    public function customerCredit(int $tenantId): string
    {
        return $this->code($tenantId, 'sales.customer_credit', 'liabilities', 'credit');
    }

    private function code(int $tenantId, string $key, string $group, string $balance): string
    {
        $account = DB::table('sales_account_mappings as mappings')->join('financial_accounts as accounts', 'accounts.id', '=', 'mappings.financial_account_id')
            ->where('mappings.tenant_id', $tenantId)->where('mappings.mapping_key', $key)->where('accounts.tenant_id', $tenantId)
            ->where('accounts.is_active', true)->whereNull('accounts.deleted_at')->select('accounts.code', 'accounts.account_group', 'accounts.normal_balance')->first();
        if (! $account || $account->account_group !== $group || $account->normal_balance !== $balance) {
            throw ValidationException::withMessages(['finance' => "SALES_ACCOUNT_NOT_CONFIGURED: {$key}"]);
        }
        return $account->code;
    }
}
