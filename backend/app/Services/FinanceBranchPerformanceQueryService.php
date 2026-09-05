<?php

namespace App\Services;

use App\Support\Money;
use App\Support\SafeMath;
use Illuminate\Support\Facades\DB;

/**
 * Per-branch comparison for every branch the actor is authorized for.
 * Company-wide (branch_id NULL) expenses are never allocated to any
 * branch's own figures — they are surfaced once, separately, as
 * unallocatedCompanyExpenses, per policy.
 */
final class FinanceBranchPerformanceQueryService
{
    public function __construct(private readonly FinanceKpiQueryService $kpi) {}

    public function perBranch(array $context, string $dateFrom, string $dateTo): array
    {
        $branches = [];
        foreach ($context['authorizedBranches'] as $branch) {
            $branchContext = ['tenantId' => $context['tenantId'], 'timezone' => $context['timezone'], 'branchId' => $branch['id'], 'scopeBranchIds' => [$branch['id']], 'authorizedBranchIds' => $context['authorizedBranchIds']];
            $sales = $this->kpi->salesAndProfit($branchContext, $dateFrom, $dateTo);
            $expenses = $this->kpi->operatingExpenses($branchContext, $dateFrom, $dateTo);
            $operatingProfitCents = $sales['grossProfitCents'] - $expenses['amountCents'];

            $branches[] = [
                'branch' => $branch,
                'netSales' => $sales['netSales']['netSales'],
                'cogs' => $sales['cogs']['amount'],
                'grossProfit' => $sales['grossProfit']['amount'],
                'operatingExpenses' => $expenses['amount'],
                'operatingProfit' => Money::decimal($operatingProfitCents),
                'grossMarginPercentage' => $sales['grossProfitReliable'] ? SafeMath::ratioPercentage($sales['grossProfitCents'], $sales['netSalesCents']) : null,
                'dataQuality' => ['cogs' => $sales['cogs']['coverageStatus']],
                'comparisonReliable' => $sales['grossProfitReliable'],
            ];
        }

        return ['branches' => $branches, 'unallocatedCompanyExpenses' => $this->unallocatedCompanyExpenses($context['tenantId'], $dateFrom, $dateTo)];
    }

    private function unallocatedCompanyExpenses(int $tenantId, string $dateFrom, string $dateTo): string
    {
        $row = DB::table('journal_entry_lines as lines')
            ->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $tenantId)->where('entries.tenant_id', $tenantId)
            ->where('entries.status', 'posted')->where('accounts.account_group', 'expenses')
            ->whereNull('entries.branch_id')
            ->where('entries.entry_date', '>=', $dateFrom)->where('entries.entry_date', '<=', $dateTo)
            ->selectRaw('COALESCE(SUM(lines.debit),0) debit, COALESCE(SUM(lines.credit),0) credit')->first();

        return Money::decimal(Money::cents($row->debit ?: '0') - Money::cents($row->credit ?: '0'));
    }
}
