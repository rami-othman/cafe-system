<?php

namespace App\Services;

use App\Support\BranchScope;
use App\Support\Money;
use App\Support\SafeMath;
use Illuminate\Support\Facades\DB;

/**
 * Authoritative KPI math for the Finance Dashboard. Every figure here is
 * read from data already recognized as financial truth by an earlier
 * phase — orders.total/cogs_total (Phase 4's own recipe-costed sale
 * consumption), posted journal_entry_lines (the ledger, Phases 1-2),
 * SupplierPayableQueryService (Phase 5) — never re-derived from scratch.
 * All money math is done in integer cents; no floats.
 */
final class FinanceKpiQueryService
{
    public function __construct(private readonly SupplierPayableQueryService $payables) {}

    /**
     * Net Sales + COGS/Gross Profit for one period, in a single orders-table
     * pass. cogs_total is NULL until SaleConsumptionService has processed an
     * order (see Phase 4) — NULL means "not yet covered", never "zero".
     */
    public function salesAndProfit(array $context, string $dateFrom, string $dateTo): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($context['timezone'], $dateFrom, $dateTo);

        $orders = DB::table('orders')->where('tenant_id', $context['tenantId'])
            ->whereIn('branch_id', $context['scopeBranchIds'])
            ->whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])
            ->whereNull('deleted_at')->whereBetween('closed_at', [$range['start'], $range['end']])
            ->selectRaw('COALESCE(SUM(subtotal),0) subtotal, COALESCE(SUM(discount_total),0) discounts, COALESCE(SUM(tax_total),0) tax, COALESCE(SUM(service_total),0) service, COALESCE(SUM(cogs_total),0) cogs, COUNT(*) order_count, SUM(CASE WHEN cogs_total IS NULL THEN 1 ELSE 0 END) missing_cogs')
            ->first();

        $refundsCents = Money::cents(DB::table('payment_refunds')->where('tenant_id', $context['tenantId'])
            ->whereIn('branch_id', $context['scopeBranchIds'])->where('status', 'completed')
            ->whereBetween('refunded_at', [$range['start'], $range['end']])->sum('amount') ?: '0');

        $grossCents = Money::cents($orders->subtotal ?: '0') + Money::cents($orders->tax ?: '0') + Money::cents($orders->service ?: '0');
        $discountsCents = Money::cents($orders->discounts ?: '0');
        $netSalesCents = $grossCents - $discountsCents - $refundsCents;

        $orderCount = (int) $orders->order_count;
        $uncovered = (int) $orders->missing_cogs;
        $covered = $orderCount - $uncovered;
        $coverageStatus = $orderCount === 0 || $uncovered === 0 ? 'complete' : ($covered === 0 ? 'unavailable' : 'partial');
        $cogsCents = Money::cents($orders->cogs ?: '0');
        $grossProfitCents = $netSalesCents - $cogsCents;
        $reliable = $coverageStatus === 'complete';

        return [
            'netSalesCents' => $netSalesCents,
            'netSales' => ['grossSales' => Money::decimal($grossCents), 'discounts' => Money::decimal($discountsCents), 'refunds' => Money::decimal($refundsCents), 'netSales' => Money::decimal($netSalesCents)],
            'cogsCents' => $cogsCents,
            'cogs' => ['amount' => Money::decimal($cogsCents), 'coverageStatus' => $coverageStatus, 'coveredSalesCount' => $covered, 'uncoveredSalesCount' => $uncovered, 'coveragePercentage' => $orderCount === 0 ? null : SafeMath::ratioPercentage($covered, $orderCount)],
            'grossProfitCents' => $grossProfitCents,
            'grossProfitReliable' => $reliable,
            'grossProfit' => ['amount' => Money::decimal($grossProfitCents), 'reliable' => $reliable, 'marginPercentage' => $reliable ? SafeMath::ratioPercentage($grossProfitCents, $netSalesCents) : null],
        ];
    }

    /** Accounting-effective Operating Expenses: posted ledger activity against expenses-group accounts only (never cost_of_sales/waste). */
    public function operatingExpenses(array $context, string $dateFrom, string $dateTo): array
    {
        $query = DB::table('journal_entry_lines as lines')
            ->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $context['tenantId'])->where('entries.tenant_id', $context['tenantId'])
            ->where('entries.status', 'posted')->where('accounts.account_group', 'expenses')
            ->where('entries.entry_date', '>=', $dateFrom)->where('entries.entry_date', '<=', $dateTo);
        BranchScope::apply($query, 'entries.branch_id', $context['branchId'], $context['authorizedBranchIds']);
        $row = $query->selectRaw('COALESCE(SUM(lines.debit),0) debit, COALESCE(SUM(lines.credit),0) credit, COUNT(DISTINCT entries.id) count')->first();

        $cents = Money::cents($row->debit ?: '0') - Money::cents($row->credit ?: '0');

        return ['amountCents' => $cents, 'amount' => Money::decimal($cents), 'count' => (int) $row->count];
    }

    /** Cash & Banks balance as of $asOfDate — posted ledger truth only, never a manually editable field. */
    public function cashBanks(array $context, string $asOfDate): array
    {
        // The date/status filter must live in a conditional SUM, not the LEFT
        // JOIN's ON clause: an ON-clause filter only nulls out entries.* for
        // a non-matching journal_entries row, it does NOT drop the already
        // (unconditionally) joined journal_entry_lines row from the SUM.
        $query = DB::table('financial_locations as locations')
            ->join('financial_accounts as accounts', 'accounts.id', '=', 'locations.financial_account_id')
            ->leftJoin('journal_entry_lines as lines', 'lines.financial_account_id', '=', 'accounts.id')
            ->leftJoin('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->where('locations.tenant_id', $context['tenantId'])->whereIn('locations.kind', ['cash', 'bank'])->where('locations.is_active', true);
        BranchScope::apply($query, 'locations.branch_id', $context['branchId'], $context['authorizedBranchIds']);
        $rows = $query->groupBy('locations.id', 'accounts.normal_balance', 'locations.kind')
            ->selectRaw(
                "locations.id, locations.kind, accounts.normal_balance,
                 COALESCE(SUM(CASE WHEN entries.status = 'posted' AND entries.entry_date <= ? THEN lines.debit ELSE 0 END),0) debit,
                 COALESCE(SUM(CASE WHEN entries.status = 'posted' AND entries.entry_date <= ? THEN lines.credit ELSE 0 END),0) credit",
                [$asOfDate, $asOfDate],
            )
            ->get();

        $cashCents = 0;
        $bankCents = 0;
        $accounts = [];
        foreach ($rows as $row) {
            $balance = $row->normal_balance === 'credit' ? Money::cents($row->credit ?: '0') - Money::cents($row->debit ?: '0') : Money::cents($row->debit ?: '0') - Money::cents($row->credit ?: '0');
            if ($row->kind === 'cash') {
                $cashCents += $balance;
            } else {
                $bankCents += $balance;
            }
            $accounts[] = ['financialLocationId' => (int) $row->id, 'kind' => $row->kind, 'balance' => Money::decimal($balance)];
        }

        return ['cash' => Money::decimal($cashCents), 'banks' => Money::decimal($bankCents), 'total' => Money::decimal($cashCents + $bankCents), 'asOfDate' => $asOfDate, 'accounts' => $accounts];
    }

    /**
     * Supplier Payables is a company-wide balance-sheet figure, exactly like
     * Cash & Banks — it is never filtered by the Dashboard's branch scope
     * (no branch-allocation rule exists for AP, and inventing one is out of
     * scope per policy), so a branch filter never changes this number.
     */
    public function supplierPayables(int $tenantId, string $asOfDate): array
    {
        $snapshot = $this->payables->snapshotAsOf($tenantId, $asOfDate);

        return [
            'outstanding' => $snapshot['outstanding'],
            'overdue' => $snapshot['overdue'],
            'openInvoiceCount' => $snapshot['openInvoiceCount'],
            'overdueInvoiceCount' => $snapshot['overdueInvoiceCount'],
            'asOfDate' => $asOfDate,
            'scope' => 'tenant',
        ];
    }

    /** Operating expenses grouped by real Expense Category (the `expenses` domain's own canonical categorization). */
    public function expenseBreakdown(array $context, string $dateFrom, string $dateTo): array
    {
        $query = DB::table('expenses as e')
            ->join('expense_categories as c', 'c.id', '=', 'e.expense_category_id')
            ->where('e.tenant_id', $context['tenantId'])->where('e.status', 'paid')
            ->whereDate('e.expense_date', '>=', $dateFrom)->whereDate('e.expense_date', '<=', $dateTo);
        BranchScope::apply($query, 'e.branch_id', $context['branchId'], $context['authorizedBranchIds']);
        $rows = $query->groupBy('c.id', 'c.code', 'c.name')->selectRaw('c.id, c.code, c.name, COALESCE(SUM(e.total_amount),0) amount')->orderByDesc('amount')->get();

        $totalCents = $rows->sum(fn ($row) => Money::cents($row->amount ?: '0'));

        return $rows->map(function ($row) use ($totalCents) {
            $cents = Money::cents($row->amount ?: '0');

            return ['categoryId' => (int) $row->id, 'code' => $row->code, 'name' => $row->name, 'amount' => Money::decimal($cents), 'percentageOfTotal' => SafeMath::ratioPercentage($cents, $totalCents)];
        })->values()->all();
    }

    /** Payment activity by configured payment method, plus legacy (unmapped) methods by their raw string. */
    public function paymentMethodBreakdown(array $context, string $dateFrom, string $dateTo): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($context['timezone'], $dateFrom, $dateTo);

        $gross = DB::table('payments as p')->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('p.tenant_id', $context['tenantId'])->whereIn('p.branch_id', $context['scopeBranchIds'])
            ->where('p.status', 'completed')->whereNull('p.deleted_at')->whereBetween('p.paid_at', [$range['start'], $range['end']])
            ->groupByRaw('COALESCE(pm.id, 0), COALESCE(pm.code, p.method), COALESCE(pm.name, p.method)')
            ->selectRaw("COALESCE(pm.id, 0) as key, COALESCE(pm.code, p.method) as code, COALESCE(pm.name, p.method) as name, COALESCE(SUM(p.amount),0) as gross, COUNT(*) as count")
            ->get()->keyBy('key');

        $refunds = DB::table('payment_refunds as r')->join('payments as p', 'p.id', '=', 'r.payment_id')
            ->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('r.tenant_id', $context['tenantId'])->whereIn('r.branch_id', $context['scopeBranchIds'])
            ->where('r.status', 'completed')->whereBetween('r.refunded_at', [$range['start'], $range['end']])
            ->groupByRaw('COALESCE(pm.id, 0)')->selectRaw('COALESCE(pm.id, 0) as key, COALESCE(SUM(r.amount),0) as total')->pluck('total', 'key');

        return $gross->map(function ($row) use ($refunds) {
            $grossCents = Money::cents($row->gross ?: '0');
            $refundCents = Money::cents($refunds[$row->key] ?? '0');

            return [
                'paymentMethodId' => (int) $row->key ?: null,
                'code' => $row->code,
                'name' => $row->name,
                'grossReceived' => Money::decimal($grossCents),
                'refunds' => Money::decimal($refundCents),
                'netReceived' => Money::decimal($grossCents - $refundCents),
                'transactionCount' => (int) $row->count,
            ];
        })->values()->all();
    }
}
