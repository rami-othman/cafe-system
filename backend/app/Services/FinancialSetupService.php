<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class FinancialSetupService
{
    /**
     * Read-only readiness check used by the dashboard. It reports only missing
     * configuration that prevents financial posting or materially degrades it;
     * it does not invent a second setup model.
     */
    public function financeReadiness(int $tenantId): array
    {
        $requiredCodes = collect($this->defaultAccounts())->pluck('code')->all();
        $activeCodes = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->pluck('code')->all();
        $missingAccounts = array_values(array_diff($requiredCodes, $activeCodes));

        $issues = [];
        if ($missingAccounts !== []) {
            $issues[] = ['code' => 'REQUIRED_ACCOUNTS_MISSING', 'severity' => 'critical', 'accountCodes' => $missingAccounts];
        }

        $locations = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('is_active', true)->pluck('id')->all();
        if ($locations === []) {
            $issues[] = ['code' => 'CASH_BANK_DESTINATION_MISSING', 'severity' => 'critical', 'accountCodes' => []];
        }

        $invalidMethods = DB::table('payment_methods as methods')
            ->leftJoin('financial_accounts as accounts', 'accounts.id', '=', 'methods.financial_account_id')
            ->leftJoin('financial_locations as locations', 'locations.id', '=', 'methods.financial_location_id')
            ->where('methods.tenant_id', $tenantId)->where('methods.is_active', true)
            ->where(function ($query): void {
                $query->whereNull('accounts.id')->orWhere('accounts.is_active', false)
                    ->orWhere(function ($location): void { $location->whereNotNull('methods.financial_location_id')->where(function ($q): void { $q->whereNull('locations.id')->orWhere('locations.is_active', false); }); });
            })->get(['methods.code']);
        if ($invalidMethods->isNotEmpty()) {
            $issues[] = ['code' => 'PAYMENT_DESTINATION_INVALID', 'severity' => 'warning', 'paymentMethodCodes' => $invalidMethods->pluck('code')->values()->all()];
        }

        return ['ready' => $issues === [], 'issues' => $issues];
    }

    /** @return array<int, array<string, string|bool>> */
    public function defaultAccounts(): array
    {
        return [
            ['code' => '1010', 'name_ar' => 'درج النقدية', 'name_en' => 'Cash Drawer', 'account_group' => 'assets', 'normal_balance' => 'debit'],
            ['code' => '1020', 'name_ar' => 'الخزنة الرئيسية', 'name_en' => 'Main Safe', 'account_group' => 'assets', 'normal_balance' => 'debit'],
            ['code' => '1030', 'name_ar' => 'الحساب البنكي', 'name_en' => 'Bank Account', 'account_group' => 'assets', 'normal_balance' => 'debit'],
            ['code' => '1100', 'name_ar' => 'أصل المخزون', 'name_en' => 'Inventory Asset', 'account_group' => 'assets', 'normal_balance' => 'debit'],
            ['code' => '1500', 'name_ar' => 'الأصول الثابتة', 'name_en' => 'Fixed Assets', 'account_group' => 'assets', 'normal_balance' => 'debit'],
            ['code' => '1590', 'name_ar' => 'مجمع الإهلاك', 'name_en' => 'Accumulated Depreciation', 'account_group' => 'assets', 'normal_balance' => 'credit'],
            ['code' => '2000', 'name_ar' => 'الحسابات الدائنة', 'name_en' => 'Accounts Payable', 'account_group' => 'liabilities', 'normal_balance' => 'credit'],
            ['code' => '2010', 'name_ar' => 'ضريبة المبيعات المستحقة', 'name_en' => 'Sales Tax Payable', 'account_group' => 'liabilities', 'normal_balance' => 'credit'],
            ['code' => '3000', 'name_ar' => 'حقوق الملكية', 'name_en' => 'Equity', 'account_group' => 'equity', 'normal_balance' => 'credit'],
            ['code' => '4000', 'name_ar' => 'إيرادات المبيعات', 'name_en' => 'Sales Revenue', 'account_group' => 'revenue', 'normal_balance' => 'credit'],
            ['code' => '4010', 'name_ar' => 'الخصومات الممنوحة', 'name_en' => 'Discounts Given', 'account_group' => 'revenue', 'normal_balance' => 'debit'],
            ['code' => '4020', 'name_ar' => 'مرتجعات المبيعات', 'name_en' => 'Sales Returns', 'account_group' => 'revenue', 'normal_balance' => 'debit'],
            ['code' => '5000', 'name_ar' => 'تكلفة البضاعة المباعة', 'name_en' => 'Cost of Goods Sold', 'account_group' => 'cost_of_sales', 'normal_balance' => 'debit'],
            ['code' => '5010', 'name_ar' => 'هدر وفروقات المخزون', 'name_en' => 'Waste / Inventory Variance', 'account_group' => 'cost_of_sales', 'normal_balance' => 'debit'],
            ['code' => '6100', 'name_ar' => 'مصروف الإيجار', 'name_en' => 'Rent Expense', 'account_group' => 'expenses', 'normal_balance' => 'debit'],
            ['code' => '6110', 'name_ar' => 'مصروف الرواتب', 'name_en' => 'Salaries Expense', 'account_group' => 'expenses', 'normal_balance' => 'debit'],
            ['code' => '6120', 'name_ar' => 'مصروف الخدمات', 'name_en' => 'Utilities Expense', 'account_group' => 'expenses', 'normal_balance' => 'debit'],
            ['code' => '6130', 'name_ar' => 'مصروف الصيانة', 'name_en' => 'Maintenance Expense', 'account_group' => 'expenses', 'normal_balance' => 'debit'],
            ['code' => '6140', 'name_ar' => 'مصروف التسويق', 'name_en' => 'Marketing Expense', 'account_group' => 'expenses', 'normal_balance' => 'debit'],
            ['code' => '6190', 'name_ar' => 'مصروفات متنوعة', 'name_en' => 'Miscellaneous Expense', 'account_group' => 'expenses', 'normal_balance' => 'debit'],
        ];
    }

    public function ensureForTenant(int $tenantId, ?int $initialBranchId = null, ?int $actorId = null): void
    {
        DB::transaction(function () use ($tenantId, $initialBranchId, $actorId): void {
            $now = now();
            foreach ($this->defaultAccounts() as $account) {
                DB::table('financial_accounts')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'code' => $account['code']],
                    $account + ['is_active' => true, 'is_system_protected' => true, 'updated_by' => $actorId, 'updated_at' => $now, 'created_by' => $actorId, 'created_at' => $now],
                );
            }

            $this->ensureCashAndBankDefaults($tenantId, $actorId);

            $this->ensureCentralWarehouse($tenantId, $actorId);
            if ($initialBranchId) {
                $this->ensureBranchMainWarehouse($tenantId, $initialBranchId, $actorId);
            }
        });
    }

    /** Creates configuration only; balances remain entirely journal-derived. */
    private function ensureCashAndBankDefaults(int $tenantId, ?int $actorId): void
    {
        $now = now();
        $accounts = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', ['1010', '1020', '1030'])->pluck('id', 'code');
        foreach ([
            ['code' => 'CASH-DRAWER', 'name' => 'Cash Drawer', 'kind' => 'cash', 'type' => 'cash_drawer', 'accountCode' => '1010'],
            ['code' => 'MAIN-SAFE', 'name' => 'Main Safe', 'kind' => 'cash', 'type' => 'main_safe', 'accountCode' => '1020'],
            ['code' => 'BANK', 'name' => 'Bank', 'kind' => 'bank', 'type' => 'bank', 'accountCode' => '1030'],
        ] as $location) {
            $accountId = $accounts[$location['accountCode']] ?? null;
            if (! $accountId) continue;
            DB::table('financial_locations')->updateOrInsert(['tenant_id' => $tenantId, 'code' => $location['code']], ['branch_id' => null, 'financial_account_id' => $accountId, 'name' => $location['name'], 'kind' => $location['kind'], 'type' => $location['type'], 'bank_name' => null, 'masked_reference' => null, 'is_active' => true, 'updated_by' => $actorId, 'updated_at' => $now, 'created_by' => $actorId, 'created_at' => $now]);
        }
        $drawerId = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('code', 'CASH-DRAWER')->value('id');
        if ($drawerId && isset($accounts['1010'])) DB::table('payment_methods')->updateOrInsert(['tenant_id' => $tenantId, 'code' => 'CASH'], ['name' => 'Cash', 'type' => 'cash', 'financial_account_id' => $accounts['1010'], 'financial_location_id' => $drawerId, 'is_active' => true, 'sort_order' => 1, 'updated_by' => $actorId, 'updated_at' => $now, 'created_by' => $actorId, 'created_at' => $now]);
    }

    public function ensureCentralWarehouse(int $tenantId, ?int $actorId = null): void
    {
        $now = now();
        DB::table('warehouses')->updateOrInsert(
            ['tenant_id' => $tenantId, 'code' => 'CENTRAL'],
            [
                'branch_id' => null,
                'name' => 'المستودع المركزي',
                'type' => 'central',
                'is_active' => true,
                'notes' => 'مستودع مركزي مشترك لفروع المنشأة.',
                'updated_by' => $actorId,
                'updated_at' => $now,
                'created_by' => $actorId,
                'created_at' => $now,
            ],
        );
        DB::table('warehouses')
            ->where('tenant_id', $tenantId)
            ->where('code', 'CENTRAL')
            ->update([
                'name' => 'Central Warehouse',
                'notes' => 'Shared warehouse for cross-branch inventory operations.',
                'updated_at' => $now,
            ]);
    }

    public function ensureBranchMainWarehouse(int $tenantId, int $branchId, ?int $actorId = null): void
    {
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->first();
        if (! $branch) {
            return;
        }

        $now = now();
        DB::table('warehouses')->updateOrInsert(
            ['tenant_id' => $tenantId, 'code' => 'BR-'.$branchId.'-MAIN'],
            [
                'branch_id' => $branchId,
                'name' => 'المخزن الرئيسي - '.$branch->name,
                'type' => 'branch_main',
                'is_active' => true,
                'notes' => 'مخزن الفرع الرئيسي.',
                'updated_by' => $actorId,
                'updated_at' => $now,
                'created_by' => $actorId,
                'created_at' => $now,
            ],
        );
        DB::table('warehouses')
            ->where('tenant_id', $tenantId)
            ->where('code', 'BR-'.$branchId.'-MAIN')
            ->update([
                'name' => $branch->name.' — Main Store',
                'notes' => 'Primary operational warehouse for '.$branch->name.'.',
                'updated_at' => $now,
            ]);
    }
}
