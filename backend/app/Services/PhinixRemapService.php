<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;

/**
 * Moves a tenant that imported the phinix chart of accounts off the legacy seeded accounts
 * (1010, 1100, 4000 …) and onto the new chart: it creates the few accounts the new chart lacks,
 * re-points every ledger mapping / payment method / cash location / expense category / branch
 * variance account, re-homes old party accounts, and (separately, on request) moves the legacy
 * balances to the new accounts with ONE journal entry. History is never rewritten.
 */
final class PhinixRemapService
{
    /**
     * Accounts the phinix catalog lacks: code => [name, parent code, optional group, optional normal balance].
     * 61–65 and 7/71 exist in the original Phoenix program but were missing from the imported file.
     */
    public const NEW_ACCOUNTS = [
        '225' => ['ضريبة مبيعات مستحقة', '22'],
        '226' => ['أرصدة دائنة للعملاء', '22'],
        '36' => ['تكلفة المبيعات', '3'],
        '517' => ['هدر وفروقات مخزون', '5'],
        '61' => ['إيرادات مختلفة', '6'],
        '62' => ['خصم الغياب او المخالفات', '6'],
        '621' => ['خصم الغياب او المخالفات محمدايهم بشير', '62'],
        '622' => ['خصم الغياب او المخالفات محمد بربور', '62'],
        '623' => ['خصم الغياب او المخالفات ايهم عساف', '62'],
        '624' => ['خصم الغياب او المخالفات امتنان السوادي', '62'],
        '625' => ['خصم الغياب او المخالفات انس بعيون', '62'],
        '626' => ['خصم الغياب او المخالفات نور حمادة', '62'],
        '627' => ['خصم الغياب او المخالفات محمد الرفاعي', '62'],
        '628' => ['خصم الغياب او المخالفات يزن الرفاعي', '62'],
        '629' => ['خصم الغياب او المخالفات فداء قرقور', '62'],
        '63' => ['ارباح راس مالية', '6'],
        '64' => ['ارباح فرق عملة', '6'],
        '65' => ['ارباح فرق اغلاق صندوق', '6'],
        '7' => ['البضاعة', null, 'cost_of_sales', 'debit'],
        '71' => ['بضاعة اول المدة', '7'],
    ];

    /** Name the first remap gave account 61 before it was known to be "miscellaneous revenue" in Phoenix. */
    private const OLD_OVER_NAME = 'إيراد زيادة صندوق';

    /** Legacy seeded account code => its home in the phinix chart. (1030 bank has no equivalent and stays.) */
    public const LEGACY_TO_NEW = [
        '1010' => '131', '1020' => '132', '1040' => '136', '1100' => '124', '1200' => '121',
        '2000' => '223', '2010' => '225', '2020' => '226', '3000' => '211',
        '4000' => '41', '4010' => '43', '4020' => '42', '4030' => '41', '4040' => '65',
        '5000' => '36', '5010' => '517',
        '6100' => '513', '6110' => '501', '6120' => '502', '6130' => '507', '6140' => '504', '6180' => '510', '6190' => '5049',
    ];

    /** Mapping key => account code in the phinix chart. */
    public const MAPPINGS = [
        'sales.revenue' => '41', 'sales.discount_given' => '43', 'sales.tax_payable' => '225',
        'sales.cost_of_goods_sold' => '36', 'sales.inventory_asset' => '124', 'sales.sales_returns' => '42',
        'sales.customer_credit' => '226', 'sales.accounts_receivable' => '121',
        'sales.additional_charge_revenue' => '41', 'sales.manual_adjustment' => '41',
        'inventory.variance' => '517', 'inventory.opening_equity' => '211',
        'cash.over' => '65', 'cash.short' => '510', 'cash.drawer' => '131',
    ];

    public function isPhinixTenant(int $tenantId): bool
    {
        return Schema::hasColumn('financial_accounts', 'catalog_source')
            && DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('catalog_source', 'phinix')
                ->whereIn('code', ['131', '41', '124'])->count() === 3;
    }

    /** @return array<string,int> what was (or, in dry-run, would be) changed */
    public function remapConfiguration(int $tenantId, bool $apply): array
    {
        if (! $this->isPhinixTenant($tenantId)) {
            throw new RuntimeException('The tenant has not imported the phinix chart of accounts.');
        }
        $report = ['accountsCreated' => 0, 'mappings' => 0, 'paymentMethods' => 0, 'locations' => 0, 'expenseCategories' => 0, 'branchVariance' => 0, 'partyAccounts' => 0, 'accountsFixed' => 0];
        $run = function () use ($tenantId, $apply, &$report): void {
            $now = now();
            $byCode = fn (string $code) => DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', $code)->whereNull('deleted_at')->first();

            foreach (self::NEW_ACCOUNTS as $code => $def) {
                [$name, $parentCode] = $def;
                if ($byCode($code)) {
                    continue;
                }
                $parent = $parentCode === null ? null : ($byCode($parentCode) ?? throw new RuntimeException("Parent account {$parentCode} is missing."));
                $report['accountsCreated']++;
                if ($apply) {
                    DB::table('financial_accounts')->insert([
                        'tenant_id' => $tenantId, 'parent_account_id' => $parent?->id, 'code' => $code,
                        'name_ar' => $name, 'name_en' => $name,
                        'account_group' => $def[2] ?? $parent->account_group,
                        'normal_balance' => $def[3] ?? $parent->normal_balance, 'is_active' => true, 'is_system_protected' => true,
                        'catalog_source' => 'phinix', 'created_at' => $now, 'updated_at' => $now,
                    ]);
                }
            }

            // Account 61 was first created here as "cash overage"; in Phoenix 61 is miscellaneous revenue and
            // cash-close overage is 65. Rename it and move the overage mapping / branch choices to 65.
            $misc = $byCode('61');
            if ($misc && $misc->name_ar === self::OLD_OVER_NAME) {
                $report['accountsFixed']++;
                if ($apply) {
                    $over = $byCode('65');
                    DB::table('financial_accounts')->where('id', $misc->id)->update(['name_ar' => 'إيرادات مختلفة', 'name_en' => 'إيرادات مختلفة', 'updated_at' => $now]);
                    if ($over) {
                        DB::table('sales_account_mappings')->where('tenant_id', $tenantId)->where('mapping_key', 'cash.over')
                            ->where('financial_account_id', $misc->id)->update(['financial_account_id' => $over->id, 'updated_at' => $now]);
                        if (Schema::hasColumn('branches', 'cash_over_account_id')) {
                            DB::table('branches')->where('tenant_id', $tenantId)->where('cash_over_account_id', $misc->id)
                                ->update(['cash_over_account_id' => $over->id, 'updated_at' => $now]);
                        }
                    }
                }
            }

            $legacyIds = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', array_keys(self::LEGACY_TO_NEW))->pluck('code', 'id');
            $newId = fn (string $code): ?int => ($row = $byCode($code)) ? (int) $row->id : null;
            $translate = function (?int $legacyAccountId) use ($legacyIds, $newId): ?int {
                $legacyCode = $legacyAccountId === null ? null : ($legacyIds[$legacyAccountId] ?? null);

                return $legacyCode === null ? null : $newId(self::LEGACY_TO_NEW[$legacyCode]);
            };

            foreach (self::MAPPINGS as $key => $code) {
                $target = $newId($code);
                $current = DB::table('sales_account_mappings')->where('tenant_id', $tenantId)->where('mapping_key', $key)->first();
                // Only legacy (or missing) mappings are moved: an owner's deliberate choice is never overwritten.
                if ($target === null || ($current && ! isset($legacyIds[$current->financial_account_id]))) {
                    continue;
                }
                $report['mappings']++;
                if ($apply) {
                    DB::table('sales_account_mappings')->updateOrInsert(
                        ['tenant_id' => $tenantId, 'mapping_key' => $key],
                        ['financial_account_id' => $target, 'updated_at' => $now] + ($current ? [] : ['created_at' => $now]),
                    );
                }
            }

            foreach (['payment_methods' => 'paymentMethods', 'financial_locations' => 'locations'] as $table => $counter) {
                foreach (DB::table($table)->where('tenant_id', $tenantId)->get(['id', 'financial_account_id']) as $row) {
                    $to = $translate($row->financial_account_id ? (int) $row->financial_account_id : null);
                    if ($to === null) {
                        continue;
                    }
                    $report[$counter]++;
                    if ($apply) {
                        DB::table($table)->where('id', $row->id)->update(['financial_account_id' => $to, 'updated_at' => $now]);
                    }
                }
            }

            foreach (DB::table('expense_categories')->where('tenant_id', $tenantId)->get(['id', 'financial_account_id']) as $row) {
                $to = $translate($row->financial_account_id ? (int) $row->financial_account_id : null);
                if ($to === null) {
                    continue;
                }
                $report['expenseCategories']++;
                if ($apply) {
                    DB::table('expense_categories')->where('id', $row->id)->update(['financial_account_id' => $to, 'updated_at' => $now]);
                }
            }

            if (Schema::hasColumn('branches', 'cash_variance_account_id')) {
                foreach (DB::table('branches')->where('tenant_id', $tenantId)->get(['id', 'cash_variance_account_id', 'cash_over_account_id']) as $branch) {
                    $patch = [];
                    foreach (['cash_variance_account_id', 'cash_over_account_id'] as $column) {
                        $to = $translate($branch->{$column} ? (int) $branch->{$column} : null);
                        if ($to !== null) {
                            $patch[$column] = $to;
                        }
                    }
                    if ($patch !== []) {
                        $report['branchVariance']++;
                        if ($apply) {
                            DB::table('branches')->where('id', $branch->id)->update($patch + ['updated_at' => $now]);
                        }
                    }
                }
            }

            // Person accounts created before the import still hang under the legacy receivable / payable parents.
            foreach (['1200' => '121', '2000' => '223'] as $legacyParent => $newParent) {
                $from = $byCode($legacyParent);
                $to = $byCode($newParent);
                if (! $from || ! $to) {
                    continue;
                }
                $query = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $from->id)->whereNull('deleted_at')
                    ->whereRaw("code ~ '^[PS][0-9]+$'");
                $report['partyAccounts'] += (clone $query)->count();
                if ($apply) {
                    $query->update(['parent_account_id' => $to->id, 'catalog_source' => 'phinix', 'updated_at' => $now]);
                }
            }
        };

        $apply ? DB::transaction($run) : $run();

        return $report;
    }

    /**
     * One journal entry that moves every legacy account's posted balance (per cash location) to its
     * phinix account. Returns the lines it would post (dry run) or the new entry id.
     *
     * @return array{lines: array<int, array<string,mixed>>, entryId: ?int}
     */
    public function transferBalances(Request $request, int $tenantId, bool $apply, ?string $date, ?int $actorId): array
    {
        if (! $this->isPhinixTenant($tenantId)) {
            throw new RuntimeException('The tenant has not imported the phinix chart of accounts.');
        }
        $accounts = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')->get(['id', 'code'])->keyBy('code');
        $lines = [];
        foreach (self::LEGACY_TO_NEW as $legacyCode => $newCode) {
            $legacy = $accounts->get($legacyCode);
            $new = $accounts->get($newCode);
            if (! $legacy || ! $new) {
                continue;
            }
            $rows = DB::table('journal_entry_lines as l')->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')
                ->where('l.tenant_id', $tenantId)->where('e.status', 'posted')->where('l.financial_account_id', $legacy->id)
                ->groupBy('l.financial_location_id')
                ->selectRaw('l.financial_location_id as location_id, COALESCE(SUM(l.debit),0) - COALESCE(SUM(l.credit),0) as net')->get();
            foreach ($rows as $row) {
                $net = round((float) $row->net, 2);
                if ($net == 0.0) {
                    continue;
                }
                $locationId = $row->location_id !== null ? (int) $row->location_id : null;
                $amount = number_format(abs($net), 2, '.', '');
                $description = "إعادة تصنيف {$legacyCode} إلى {$newCode}";
                $lines[] = ['accountCode' => $legacyCode, 'debit' => $net < 0 ? $amount : '0.00', 'credit' => $net > 0 ? $amount : '0.00', 'financialLocationId' => $locationId, 'description' => $description];
                $lines[] = ['accountCode' => $newCode, 'debit' => $net > 0 ? $amount : '0.00', 'credit' => $net < 0 ? $amount : '0.00', 'financialLocationId' => $locationId, 'description' => $description];
            }
        }
        if (! $apply || $lines === []) {
            return ['lines' => $lines, 'entryId' => null];
        }
        $entryId = app(AccountingPostingService::class)->post($request, $tenantId, [
            'sourceType' => 'legacy_reclassification', 'sourceId' => $tenantId, 'sourceEvent' => 'LEGACY_TO_PHINIX',
            'entryDate' => $date ?? now()->toDateString(),
            'description' => 'إعادة تصنيف أرصدة الحسابات القديمة إلى الشجرة الجديدة',
            'lines' => $lines,
        ], $actorId);

        return ['lines' => $lines, 'entryId' => $entryId];
    }
}
