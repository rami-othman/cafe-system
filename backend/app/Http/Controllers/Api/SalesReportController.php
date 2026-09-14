<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BusinessDayRangeResolver;
use App\Services\FinancialReportContext;
use App\Services\SalesReportingQueryService;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\SafeMath;
use App\Support\TenantContext;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Sales & Profitability: the operational POS+Manual union report (docs/sales
 * ADR-09). Never a source for financial statements — see
 * FinancialReportController for the ledger-based reports.
 */
final class SalesReportController extends Controller
{
    public function __construct(
        private readonly FinancialReportContext $contexts,
        private readonly SalesReportingQueryService $sales,
    ) {}

    public function salesProfitability(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $filters = $request->validate(['dateFrom' => ['nullable', 'date_format:Y-m-d'], 'dateTo' => ['nullable', 'date_format:Y-m-d'], 'branchId' => ['nullable', 'integer'], 'comparison' => ['nullable', 'in:previous_period,none']]);
        $ctx = $this->contexts->resolve($tenant, FinancialActor::id($request, $tenant), $filters);
        $branchIds = $ctx['branchId'] !== null ? [$ctx['branchId']] : $ctx['authorizedBranchIds'];

        $summary = $this->sales->salesAndProfit($tenant, $branchIds, $ctx['dateFrom'], $ctx['dateTo'], $ctx['timezone']);
        $comparison = $ctx['comparisonFrom'] ? $this->sales->salesAndProfit($tenant, $branchIds, $ctx['comparisonFrom'], $ctx['comparisonTo'], $ctx['timezone']) : null;
        $collection = $this->sales->collectionSummary($tenant, $branchIds, $ctx['dateFrom'], $ctx['dateTo'], $ctx['timezone']);
        $collectionComparison = $comparison ? $this->sales->collectionSummary($tenant, $branchIds, $ctx['comparisonFrom'], $ctx['comparisonTo'], $ctx['timezone']) : null;
        $transactionCount = $this->transactionCount($tenant, $branchIds, $ctx['dateFrom'], $ctx['dateTo'], $ctx['timezone']);
        $transactionCountComparison = $comparison ? $this->transactionCount($tenant, $branchIds, $ctx['comparisonFrom'], $ctx['comparisonTo'], $ctx['timezone']) : null;

        $orderRows = $this->posOrderRows($tenant, $branchIds, $ctx['timezone'], $ctx['dateFrom'], $ctx['dateTo']);
        $refundRows = $this->posRefundRows($tenant, $branchIds, $ctx['timezone'], $ctx['dateFrom'], $ctx['dateTo']);

        $metric = fn (int $current, ?int $previous): array => ['value' => Money::decimal($current), 'previousValue' => $previous === null ? null : Money::decimal($previous)];
        $percentMetric = fn (?float $current, ?float $previous): array => ['value' => $current, 'previousValue' => $previous];

        return response()->json(['data' => [
            'currency' => $ctx['currency'],
            'branches' => DB::table('branches')->whereIn('id', $ctx['authorizedBranchIds'])->get(['id', 'name'])->map(fn (object $b) => ['id' => (int) $b->id, 'name' => $b->name])->all(),
            'kpis' => [
                'grossSales' => $metric($summary['grossSalesCents'], $comparison['grossSalesCents'] ?? null),
                'netSales' => $metric($summary['netSalesCents'], $comparison['netSalesCents'] ?? null),
                'discounts' => $metric($summary['discountsCents'], $comparison['discountsCents'] ?? null),
                'refunds' => $metric($summary['reductionsCents'], $comparison['reductionsCents'] ?? null),
                'cogs' => $metric($summary['cogsCents'], $comparison['cogsCents'] ?? null),
                'grossProfit' => $metric($summary['grossProfitCents'], $comparison['grossProfitCents'] ?? null),
                'grossMargin' => $percentMetric($summary['marginPercentage'], $comparison['marginPercentage'] ?? null),
                'averageOrderValue' => $metric($transactionCount > 0 ? intdiv($summary['netSalesCents'], $transactionCount) : 0, $transactionCountComparison ? ($transactionCountComparison > 0 ? intdiv($comparison['netSalesCents'], $transactionCountComparison) : 0) : null),
                'cashCollected' => $metric($collection['cashCollectedCents'], $collectionComparison['cashCollectedCents'] ?? null),
                'bankCollected' => $metric($collection['bankCollectedCents'], $collectionComparison['bankCollectedCents'] ?? null),
            ],
            'salesBySource' => $this->salesBySourceRows($summary),
            'dailyTrend' => $this->trend($orderRows, $refundRows, $ctx['timezone'], $ctx['dateFrom'], $ctx['dateTo'], 'day'),
            'weeklyTrend' => $this->trend($orderRows, $refundRows, $ctx['timezone'], $ctx['dateFrom'], $ctx['dateTo'], 'week'),
            'monthlyTrend' => $this->trend($orderRows, $refundRows, $ctx['timezone'], $ctx['dateFrom'], $ctx['dateTo'], 'month'),
            'hourlySales' => $this->hourlySales($orderRows, $ctx['timezone']),
            'categorySales' => $this->categorySales($tenant, $branchIds, $ctx),
            'branchPerformance' => $this->branchPerformance($tenant, $branchIds, $ctx),
            'products' => $this->sales->productPerformance($tenant, $branchIds, $ctx['dateFrom'], $ctx['dateTo'], $ctx['timezone']),
        ]]);
    }

    /** POS order count + posted Manual Invoice count — the denominator for a blended average-transaction-value KPI. */
    private function transactionCount(int $tenant, array $branchIds, string $dateFrom, string $dateTo, string $timezone): int
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($timezone, $dateFrom, $dateTo);
        $orders = DB::table('orders')->where('tenant_id', $tenant)->whereIn('branch_id', $branchIds)
            ->whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])->whereNull('deleted_at')
            ->whereBetween('closed_at', [$range['start'], $range['end']])->count();
        $invoices = DB::table('sales_invoices')->where('tenant_id', $tenant)->whereIn('branch_id', $branchIds)->where('status', 'posted')
            ->whereBetween('invoice_date', [$dateFrom, $dateTo])->count();

        return $orders + $invoices;
    }

    private function salesBySourceRows(array $summary): array
    {
        $pos = $summary['pos']['netSalesCents']; $manual = $summary['manualInvoice']['netSalesCents']; $total = $pos + $manual;

        return [
            ['name' => 'pos', 'netSales' => Money::decimal($pos), 'percent' => $total === 0 ? 0.0 : round($pos * 100 / $total, 2)],
            ['name' => 'manual_invoice', 'netSales' => Money::decimal($manual), 'percent' => $total === 0 ? 0.0 : round($manual * 100 / $total, 2)],
        ];
    }

    private function posOrderRows(int $tenant, array $branchIds, string $timezone, string $dateFrom, string $dateTo): Collection
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($timezone, $dateFrom, $dateTo);

        return DB::table('orders')->where('tenant_id', $tenant)->whereIn('branch_id', $branchIds)
            ->whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])->whereNull('deleted_at')
            ->whereBetween('closed_at', [$range['start'], $range['end']])
            ->get(['id', 'branch_id', 'closed_at', 'subtotal', 'discount_total', 'cogs_total']);
    }

    private function posRefundRows(int $tenant, array $branchIds, string $timezone, string $dateFrom, string $dateTo): Collection
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($timezone, $dateFrom, $dateTo);

        return DB::table('payment_refunds')->where('tenant_id', $tenant)->whereIn('branch_id', $branchIds)->where('status', 'completed')
            ->whereBetween('refunded_at', [$range['start'], $range['end']])
            ->get(['order_id', 'refunded_at', 'amount']);
    }

    /** @return array<int, array{date:string,netSales:float,grossProfit:float}> POS-only breakdown (spec: no manual-invoice union needed for timing/pattern charts). */
    private function trend(Collection $orders, Collection $refunds, string $timezone, string $dateFrom, string $dateTo, string $grain): array
    {
        $bucketKey = fn (CarbonImmutable $date): string => match ($grain) {
            'week' => $date->startOfWeek()->toDateString(),
            'month' => $date->startOfMonth()->toDateString(),
            default => $date->toDateString(),
        };

        $buckets = [];
        foreach ($orders as $row) {
            $local = CarbonImmutable::parse($row->closed_at, 'UTC')->setTimezone($timezone);
            $key = $bucketKey($local);
            $buckets[$key]['netSales'] = ($buckets[$key]['netSales'] ?? 0) + Money::cents($row->subtotal) - Money::cents($row->discount_total);
            $buckets[$key]['cogs'] = ($buckets[$key]['cogs'] ?? 0) + Money::cents($row->cogs_total ?? '0');
        }
        foreach ($refunds as $row) {
            $local = CarbonImmutable::parse($row->refunded_at, 'UTC')->setTimezone($timezone);
            $key = $bucketKey($local);
            $buckets[$key]['netSales'] = ($buckets[$key]['netSales'] ?? 0) - Money::cents($row->amount);
        }

        ksort($buckets);

        return collect($buckets)->map(fn (array $b, string $date) => ['date' => $date, 'netSales' => round((float) Money::decimal($b['netSales'] ?? 0), 2), 'grossProfit' => round((float) Money::decimal(($b['netSales'] ?? 0) - ($b['cogs'] ?? 0)), 2)])->values()->all();
    }

    /** @return array<int, array{label:string,sales:float}> */
    private function hourlySales(Collection $orders, string $timezone): array
    {
        $buckets = array_fill(0, 24, 0);
        foreach ($orders as $row) {
            $hour = (int) CarbonImmutable::parse($row->closed_at, 'UTC')->setTimezone($timezone)->format('G');
            $buckets[$hour] += Money::cents($row->subtotal) - Money::cents($row->discount_total);
        }

        return collect($buckets)->map(fn (int $cents, int $hour) => ['label' => str_pad((string) $hour, 2, '0', STR_PAD_LEFT).':00', 'sales' => round((float) Money::decimal($cents), 2)])->values()->all();
    }

    /** @return array<int, array{name:string,netSales:float,percent:float}> POS product categories, net of item-level discount (refunds not prorated — a secondary breakdown, not a headline KPI). */
    private function categorySales(int $tenant, array $branchIds, array $ctx): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($ctx['timezone'], $ctx['dateFrom'], $ctx['dateTo']);
        $rows = DB::table('order_items as i')->join('orders as o', 'o.id', '=', 'i.order_id')
            ->leftJoin('products as p', 'p.id', '=', 'i.product_id')->leftJoin('categories as c', 'c.id', '=', 'p.category_id')
            ->where('o.tenant_id', $tenant)->whereIn('o.branch_id', $branchIds)
            ->whereIn('o.payment_status', ['paid', 'partially_refunded', 'refunded'])->whereNull('o.deleted_at')->whereNull('i.deleted_at')
            ->whereBetween('o.closed_at', [$range['start'], $range['end']])
            ->selectRaw("COALESCE(c.name, 'غير مصنف') as name, SUM(i.total - i.discount_total) as net")
            ->groupBy('c.name')->orderByDesc('net')->get();
        $total = $rows->sum('net');

        return $rows->map(fn (object $r) => ['name' => $r->name, 'netSales' => round((float) Money::decimal(Money::cents($r->net)), 2), 'percent' => $total == 0 ? 0.0 : round(((float) $r->net) * 100 / (float) $total, 2)])->all();
    }

    /** @return array<int, array{name:string,netSales:float,orders:int,grossProfit:float,margin:float}> */
    private function branchPerformance(int $tenant, array $branchIds, array $ctx): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($ctx['timezone'], $ctx['dateFrom'], $ctx['dateTo']);
        $rows = DB::table('orders as o')->join('branches as b', 'b.id', '=', 'o.branch_id')
            ->where('o.tenant_id', $tenant)->whereIn('o.branch_id', $branchIds)
            ->whereIn('o.payment_status', ['paid', 'partially_refunded', 'refunded'])->whereNull('o.deleted_at')
            ->whereBetween('o.closed_at', [$range['start'], $range['end']])
            ->selectRaw('b.id, b.name, COUNT(*) as orders_count, SUM(o.subtotal - o.discount_total) as net, COALESCE(SUM(o.cogs_total),0) as cogs')
            ->groupBy('b.id', 'b.name')->orderByDesc('net')->get();

        return $rows->map(function (object $r): array {
            $net = Money::cents($r->net); $grossProfit = $net - Money::cents($r->cogs);

            return ['name' => $r->name, 'netSales' => round((float) Money::decimal($net), 2), 'orders' => (int) $r->orders_count, 'grossProfit' => round((float) Money::decimal($grossProfit), 2), 'margin' => SafeMath::ratioPercentage($grossProfit, $net) ?? 0.0];
        })->values()->all();
    }
}
