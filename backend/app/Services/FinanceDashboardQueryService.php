<?php

namespace App\Services;

use App\Support\Money;
use App\Support\SafeMath;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * The top-level composer for GET /finance/dashboard. It is a read model: it
 * never writes to daily_closings, journal_entries, or any other business
 * table — every figure comes from an authoritative query service built in
 * an earlier phase (or a thin, purpose-built KPI/alert layer added in this
 * phase that itself only reads).
 */
final class FinanceDashboardQueryService
{
    public function __construct(
        private readonly FinanceKpiQueryService $kpi,
        private readonly FinanceAlertQueryService $alerts,
        private readonly DailyClosingSummaryService $dailyClosingSummary,
        private readonly DailyClosingReadinessService $dailyClosingReadiness,
        private readonly FinancialTransactionQueryService $transactions,
        private readonly FinancialReconciliationQueryService $reconciliations,
    ) {}

    public function summary(Request $request, array $context): array
    {
        $current = $this->kpi->salesAndProfit($context, $context['dateFrom'], $context['dateTo']);
        $currentExpenses = $this->kpi->operatingExpenses($context, $context['dateFrom'], $context['dateTo']);
        $currentCashBanks = $this->kpi->cashBanks($context, $context['dateTo']);
        $currentPayables = $this->kpi->supplierPayables($context['tenantId'], $context['dateTo']);

        $comparison = null;
        $comparisonExpenses = null;
        $comparisonCashBanks = null;
        $comparisonPayables = null;
        if ($context['comparisonFrom'] !== null) {
            $comparison = $this->kpi->salesAndProfit($context, $context['comparisonFrom'], $context['comparisonTo']);
            $comparisonExpenses = $this->kpi->operatingExpenses($context, $context['comparisonFrom'], $context['comparisonTo']);
            $comparisonCashBanks = $this->kpi->cashBanks($context, $context['comparisonTo']);
            $comparisonPayables = $this->kpi->supplierPayables($context['tenantId'], $context['comparisonTo']);
        }

        $operatingProfitCents = $current['grossProfitCents'] - $currentExpenses['amountCents'];
        $comparisonOperatingProfitCents = $comparison !== null ? $comparison['grossProfitCents'] - $comparisonExpenses['amountCents'] : null;
        $operatingProfitReliable = $current['grossProfitReliable'];

        $kpis = [
            'netSales' => [...$this->change($current['netSalesCents'], $comparison['netSalesCents'] ?? null), 'breakdown' => $current['netSales']],
            'grossProfit' => [...$this->change($current['grossProfitCents'], $comparison['grossProfitCents'] ?? null), 'reliable' => $current['grossProfitReliable'], 'marginPercentage' => $current['grossProfit']['marginPercentage'], 'cogs' => $current['cogs']],
            'operatingExpenses' => [...$this->change($currentExpenses['amountCents'], $comparisonExpenses['amountCents'] ?? null), 'expenseCount' => $currentExpenses['count']],
            'operatingProfit' => [...$this->change($operatingProfitCents, $comparisonOperatingProfitCents), 'reliable' => $operatingProfitReliable, 'marginPercentage' => $operatingProfitReliable ? SafeMath::ratioPercentage($operatingProfitCents, $current['netSalesCents']) : null],
            'cashBanks' => $this->balanceKpi($currentCashBanks['total'], $comparisonCashBanks['total'] ?? null) + ['cash' => $currentCashBanks['cash'], 'banks' => $currentCashBanks['banks'], 'total' => $currentCashBanks['total'], 'asOfDate' => $currentCashBanks['asOfDate'], 'accounts' => $currentCashBanks['accounts']],
            'supplierPayables' => $this->balanceKpi($currentPayables['outstanding'], $comparisonPayables['outstanding'] ?? null, 'outstanding') + $currentPayables,
        ];

        $reconciliation = $this->reconciliations->summaryForFinanceContext($context['tenantId'], $context['actorId'], $context);
        $alerts = $this->alerts->alerts($context, $context['dateFrom'], $context['dateTo'], $reconciliation);

        $dataQuality = [
            'sales' => 'complete',
            'cogs' => $current['cogs']['coverageStatus'],
            'expenses' => 'complete',
            'cashBanks' => 'complete',
            'payables' => 'complete',
            'hasBlockingFinancialIntegrityIssue' => collect($alerts)->contains(fn (array $alert) => $alert['severity'] === 'critical'),
        ];

        $recentTransactions = $this->transactions->list($request, $context['tenantId'], $context['actorId'], [
            'dateFrom' => $context['dateFrom'], 'dateTo' => $context['dateTo'], 'branchId' => $context['branchId'], 'perPage' => 15,
        ])['data'];

        return [
            'context' => [
                'dateFrom' => $context['dateFrom'], 'dateTo' => $context['dateTo'], 'timezone' => $context['timezone'], 'currency' => $context['currency'],
                'comparison' => ['mode' => $context['comparisonMode'], 'from' => $context['comparisonFrom'], 'to' => $context['comparisonTo']],
                'branches' => $context['authorizedBranches'], 'selectedBranchId' => $context['branchId'],
            ],
            'kpis' => $kpis,
            'dataQuality' => $dataQuality,
            'alerts' => array_values($alerts),
            'recentTransactions' => $recentTransactions,
            'dailyClosing' => ['latestClosing' => $this->latestClosing($context)],
            'reconciliation' => $reconciliation['types'],
        ];
    }

    private function change(int $currentCents, ?int $previousCents): array
    {
        return [
            'current' => Money::decimal($currentCents),
            'previous' => $previousCents === null ? null : Money::decimal($previousCents),
            'absoluteChange' => $previousCents === null ? null : Money::decimal($currentCents - $previousCents),
            'percentageChange' => $previousCents === null ? null : SafeMath::percentageChange($currentCents, $previousCents),
            'changeState' => $previousCents === null ? null : SafeMath::changeState($currentCents, $previousCents),
        ];
    }

    /** Balance-style comparison: compares ending balances at each cutoff, never a summed flow. */
    private function balanceKpi(string $currentDecimal, ?string $previousDecimal, string $currentKey = 'total'): array
    {
        $currentCents = $this->signedCents($currentDecimal);
        $previousCents = $previousDecimal === null ? null : $this->signedCents($previousDecimal);

        return [
            'previous' . ucfirst($currentKey) => $previousDecimal,
            'absoluteChange' => $previousCents === null ? null : Money::decimal($currentCents - $previousCents),
            'percentageChange' => $previousCents === null ? null : SafeMath::percentageChange($currentCents, $previousCents),
            'changeState' => $previousCents === null ? null : SafeMath::changeState($currentCents, $previousCents),
        ];
    }

    private function signedCents(string $amount): int
    {
        $amount = trim($amount);
        return str_starts_with($amount, '-') ? -Money::cents(substr($amount, 1)) : Money::cents($amount);
    }

    private function latestClosing(array $context): ?array
    {
        $row = DB::table('daily_closings as c')->join('branches as b', 'b.id', '=', 'c.branch_id')
            ->where('c.tenant_id', $context['tenantId'])->whereIn('c.branch_id', $context['scopeBranchIds'])
            ->orderByDesc('c.business_date')->orderByDesc('c.id')
            ->first(['c.id', 'c.business_date', 'c.branch_id', 'b.name as branch_name', 'c.status', 'c.cash_difference', 'c.actual_cash']);
        if (! $row) {
            return null;
        }

        $blockerCount = 0;
        $readinessState = 'closed';
        if ($row->status !== 'closed') {
            $summary = $this->dailyClosingSummary->summarize($context['tenantId'], (int) $row->branch_id, $row->business_date);
            $result = $this->dailyClosingReadiness->evaluate($context['tenantId'], (int) $row->branch_id, $row->business_date, $summary, $row->actual_cash);
            $readinessState = $result['readiness'];
            $blockerCount = count($result['blockers']);
        }

        return [
            'businessDate' => $row->business_date,
            'branch' => ['id' => (int) $row->branch_id, 'name' => $row->branch_name],
            'status' => $row->status,
            'readiness' => $readinessState,
            'difference' => $row->cash_difference,
            'blockerCount' => $blockerCount,
        ];
    }

    /** Compact status only — no per-session matching detail (that remains Phase 8's own responsibility). */
}
