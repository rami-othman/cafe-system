<?php

namespace App\Services;

use App\Support\Money;
use App\Support\SafeMath;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Deterministic time-series buckets for the Dashboard's two trend charts.
 * Sales/refunds are timestamp-based (paid/closed/refunded_at) and are
 * bucketed by the tenant/branch-local business date (reusing Phase 9's
 * timezone semantics) rather than the naive UTC calendar date. Expense
 * ledger activity is bucketed directly by journal_entries.entry_date,
 * which already IS the local business date assigned at posting time.
 */
final class FinanceTrendQueryService
{
    /** @return array{granularity: string, series: array} */
    public function revenueExpensesTrend(array $context, string $dateFrom, string $dateTo): array
    {
        $granularity = $this->granularity($dateFrom, $dateTo);
        $buckets = $this->bucketList($dateFrom, $dateTo, $granularity);
        $sales = $this->salesByLocalDate($context, $dateFrom, $dateTo);
        $expenses = $this->expensesByEntryDate($context, $dateFrom, $dateTo, $granularity);

        $series = array_map(function (array $bucket) use ($sales, $expenses, $granularity): array {
            $netSalesCents = 0;
            foreach ($sales as $date => $day) {
                if ($this->bucketKeyForDate($date, $granularity) === $bucket['start']) {
                    $netSalesCents += $day['netSalesCents'];
                }
            }

            return ['periodStart' => $bucket['start'], 'periodEnd' => $bucket['end'], 'netSales' => Money::decimal($netSalesCents), 'operatingExpenses' => Money::decimal($expenses[$bucket['start']] ?? 0)];
        }, $buckets);

        return ['granularity' => $granularity, 'series' => $series];
    }

    /** @return array{granularity: string, series: array} */
    public function salesCogsGrossProfitTrend(array $context, string $dateFrom, string $dateTo): array
    {
        $granularity = $this->granularity($dateFrom, $dateTo);
        $buckets = $this->bucketList($dateFrom, $dateTo, $granularity);
        $sales = $this->salesByLocalDate($context, $dateFrom, $dateTo);

        $series = array_map(function (array $bucket) use ($sales, $granularity): array {
            $netSalesCents = 0;
            $cogsCents = 0;
            $orderCount = 0;
            $missing = 0;
            foreach ($sales as $date => $day) {
                if ($this->bucketKeyForDate($date, $granularity) !== $bucket['start']) {
                    continue;
                }
                $netSalesCents += $day['netSalesCents'];
                $cogsCents += $day['cogsCents'];
                $orderCount += $day['orderCount'];
                $missing += $day['missingCogs'];
            }
            $covered = $orderCount - $missing;
            $coverageStatus = $orderCount === 0 || $missing === 0 ? 'complete' : ($covered === 0 ? 'unavailable' : 'partial');

            return [
                'periodStart' => $bucket['start'], 'periodEnd' => $bucket['end'],
                'netSales' => Money::decimal($netSalesCents), 'cogs' => Money::decimal($cogsCents),
                'grossProfit' => Money::decimal($netSalesCents - $cogsCents),
                'cogsCoverage' => ['status' => $coverageStatus, 'coveredSalesCount' => $covered, 'uncoveredSalesCount' => $missing],
            ];
        }, $buckets);

        return ['granularity' => $granularity, 'series' => $series];
    }

    /** One row per LOCAL business date with netSalesCents/cogsCents/orderCount/missingCogs, from a single orders fetch + single refunds fetch. */
    private function salesByLocalDate(array $context, string $dateFrom, string $dateTo): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($context['timezone'], $dateFrom, $dateTo);
        $timezone = $context['timezone'];

        $orders = DB::table('orders')->where('tenant_id', $context['tenantId'])
            ->whereIn('branch_id', $context['scopeBranchIds'])
            ->whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])
            ->whereNull('deleted_at')->whereBetween('closed_at', [$range['start'], $range['end']])
            ->get(['closed_at', 'subtotal', 'discount_total', 'tax_total', 'service_total', 'cogs_total']);

        $refunds = DB::table('payment_refunds')->where('tenant_id', $context['tenantId'])
            ->whereIn('branch_id', $context['scopeBranchIds'])->where('status', 'completed')
            ->whereBetween('refunded_at', [$range['start'], $range['end']])->get(['refunded_at', 'amount']);

        $days = [];
        $blank = fn () => ['netSalesCents' => 0, 'cogsCents' => 0, 'orderCount' => 0, 'missingCogs' => 0];
        foreach ($orders as $order) {
            $date = Carbon::parse($order->closed_at)->setTimezone($timezone)->toDateString();
            $days[$date] ??= $blank();
            $net = Money::cents($order->subtotal ?: '0') + Money::cents($order->tax_total ?: '0') + Money::cents($order->service_total ?: '0') - Money::cents($order->discount_total ?: '0');
            $days[$date]['netSalesCents'] += $net;
            $days[$date]['orderCount']++;
            if ($order->cogs_total === null) {
                $days[$date]['missingCogs']++;
            } else {
                $days[$date]['cogsCents'] += Money::cents($order->cogs_total);
            }
        }
        foreach ($refunds as $refund) {
            $date = Carbon::parse($refund->refunded_at)->setTimezone($timezone)->toDateString();
            $days[$date] ??= $blank();
            $days[$date]['netSalesCents'] -= Money::cents($refund->amount);
        }

        return $days;
    }

    /** Grouped by entry_date (already the local business date) and re-keyed into the target bucket granularity. */
    private function expensesByEntryDate(array $context, string $dateFrom, string $dateTo, string $granularity): array
    {
        $query = DB::table('journal_entry_lines as lines')
            ->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $context['tenantId'])->where('entries.tenant_id', $context['tenantId'])
            ->where('entries.status', 'posted')->where('accounts.account_group', 'expenses')
            ->where('entries.entry_date', '>=', $dateFrom)->where('entries.entry_date', '<=', $dateTo);
        \App\Support\BranchScope::apply($query, 'entries.branch_id', $context['branchId'], $context['authorizedBranchIds']);
        $rows = $query->groupBy('entries.entry_date')->selectRaw('entries.entry_date as date, COALESCE(SUM(lines.debit),0) debit, COALESCE(SUM(lines.credit),0) credit')->get();

        $buckets = [];
        foreach ($rows as $row) {
            $key = $this->bucketKeyForDate($row->date, $granularity);
            $buckets[$key] = ($buckets[$key] ?? 0) + (Money::cents($row->debit ?: '0') - Money::cents($row->credit ?: '0'));
        }

        return $buckets;
    }

    private function granularity(string $dateFrom, string $dateTo): string
    {
        $days = CarbonImmutable::parse($dateFrom)->diffInDays(CarbonImmutable::parse($dateTo)) + 1;
        if ($days <= 31) {
            return 'day';
        }

        return $days <= 180 ? 'week' : 'month';
    }

    private function bucketKeyForDate(string $date, string $granularity): string
    {
        $d = CarbonImmutable::parse($date);

        return match ($granularity) {
            'week' => $d->startOfWeek(Carbon::MONDAY)->toDateString(),
            'month' => $d->startOfMonth()->toDateString(),
            default => $d->toDateString(),
        };
    }

    private function bucketList(string $dateFrom, string $dateTo, string $granularity): array
    {
        $from = CarbonImmutable::parse($dateFrom);
        $to = CarbonImmutable::parse($dateTo);
        $keys = [];
        for ($cursor = $from; $cursor->lte($to); $cursor = $cursor->addDay()) {
            $keys[$this->bucketKeyForDate($cursor->toDateString(), $granularity)] = true;
        }

        return array_map(function (string $key) use ($granularity, $dateTo): array {
            $start = CarbonImmutable::parse($key);
            $end = match ($granularity) {
                'week' => $start->addDays(6),
                'month' => $start->endOfMonth(),
                default => $start,
            };

            return ['start' => $key, 'end' => $end->toDateString() > $dateTo ? $dateTo : $end->toDateString()];
        }, array_keys($keys));
    }
}
