<?php

namespace App\Services;

use App\Support\Money;
use App\Support\RefundTaxAllocation;
use App\Support\SafeMath;
use Illuminate\Support\Facades\DB;

/**
 * The single authoritative operational (non-GL) sales union: POS orders +
 * posted Manual Sales Invoices, net of posted Sales Credit Notes. Financial
 * statements (P&L/Balance Sheet/Cash Flow/GL) never use this service — they
 * derive from posted journals directly (FinancialReportQueryService). This
 * service exists because product quantities and a POS/Manual source split
 * are absent from the journal (docs/sales SALES_ARCHITECTURE_DECISIONS.md
 * ADR-09). Every method takes an already-resolved tenant/branch/date scope;
 * callers never pass raw request input.
 *
 * Revenue-domain sign conventions (verified against the posting services):
 *  - POS: `orders.subtotal`/`order_items.total` are GROSS (pre-discount);
 *    net = gross - discount_total (PosPricingService).
 *  - Manual invoice: `sales_invoice_lines.subtotal` is already NET of
 *    discount (SalesInvoicePostingService credits revenue by `subtotal`,
 *    `total = subtotal + tax`); gross = subtotal + discount_total.
 *  - Credit note lines carry no discount column; their `subtotal` is the
 *    net revenue reduction directly.
 * Customer Payments and Customer Refunds never appear here — they are
 * settlement events, not sales events (see collectionSummary() for those).
 */
final class SalesReportingQueryService
{
    /** POS + Manual − CreditNote revenue/COGS for the period, with each source broken out for salesBySource(). */
    public function salesAndProfit(int $tenantId, array $branchIds, string $dateFrom, string $dateTo, string $timezone): array
    {
        $pos = $this->posComponents($tenantId, $branchIds, $dateFrom, $dateTo, $timezone);
        $manual = $this->manualInvoiceComponents($tenantId, $branchIds, $dateFrom, $dateTo);
        $credit = $this->creditNoteComponents($tenantId, $branchIds, $dateFrom, $dateTo);

        $grossCents = $pos['grossCents'] + $manual['grossCents'];
        $discountsCents = $pos['discountsCents'] + $manual['discountsCents'];
        $reductionsCents = $pos['refundRevenueCents'] + $credit['netCents'];
        $taxCents = $pos['taxCents'] + $manual['taxCents'] - $pos['refundTaxCents'] - $credit['taxCents'];
        $netSalesCents = $grossCents - $discountsCents - $reductionsCents;
        $cogsCents = $pos['cogsCents'] + $manual['cogsCents'] - $credit['cogsCents'];
        $grossProfitCents = $netSalesCents - $cogsCents;

        return [
            'grossSalesCents' => $grossCents,
            'discountsCents' => $discountsCents,
            'reductionsCents' => $reductionsCents,
            'taxCents' => $taxCents,
            'netSalesCents' => $netSalesCents,
            'cogsCents' => $cogsCents,
            'grossProfitCents' => $grossProfitCents,
            'marginPercentage' => SafeMath::ratioPercentage($grossProfitCents, $netSalesCents),
            'pos' => ['netSalesCents' => $pos['netCents']],
            'manualInvoice' => ['netSalesCents' => $manual['netCents'] - $credit['netCents']],
        ];
    }

    /**
     * Manual Sales Invoice revenue/COGS, net of posted Sales Credit Notes,
     * for the period — the exact delta a POS-only KPI (Finance Dashboard's
     * `FinanceKpiQueryService::salesAndProfit()`) needs to add to become the
     * true POS+Manual−CreditNote union without re-deriving the POS side.
     */
    public function manualInvoiceNetOfCreditNotes(int $tenantId, array $branchIds, string $dateFrom, string $dateTo): array
    {
        $manual = $this->manualInvoiceComponents($tenantId, $branchIds, $dateFrom, $dateTo);
        $credit = $this->creditNoteComponents($tenantId, $branchIds, $dateFrom, $dateTo);

        return [
            'grossCents' => $manual['grossCents'] - $credit['netCents'],
            'discountsCents' => $manual['discountsCents'],
            'taxCents' => $manual['taxCents'] - $credit['taxCents'],
            'netCents' => $manual['netCents'] - $credit['netCents'],
            'cogsCents' => $manual['cogsCents'] - $credit['cogsCents'],
        ];
    }

    /** [{source, netSalesCents}] — Credit Notes already netted into manual_invoice (they only ever reference a manual invoice, never a POS order). */
    public function salesBySource(int $tenantId, array $branchIds, string $dateFrom, string $dateTo, string $timezone): array
    {
        $summary = $this->salesAndProfit($tenantId, $branchIds, $dateFrom, $dateTo, $timezone);

        return [
            ['source' => 'pos', 'netSalesCents' => $summary['pos']['netSalesCents']],
            ['source' => 'manual_invoice', 'netSalesCents' => $summary['manualInvoice']['netSalesCents']],
        ];
    }

    /** Cash/bank actually collected in the period — a settlement metric, deliberately independent of Revenue (spec §7/§32). */
    public function collectionSummary(int $tenantId, array $branchIds, string $dateFrom, string $dateTo, string $timezone): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($timezone, $dateFrom, $dateTo);

        $posCash = DB::table('payments as p')->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('p.tenant_id', $tenantId)->whereIn('p.branch_id', $branchIds)->where('p.status', 'completed')->whereNull('p.deleted_at')
            ->whereBetween('p.paid_at', [$range['start'], $range['end']])
            ->selectRaw("COALESCE(SUM(CASE WHEN pm.type = 'cash' OR (p.payment_method_id IS NULL AND p.method = 'cash') THEN p.amount ELSE 0 END),0) cash, COALESCE(SUM(CASE WHEN pm.type NOT IN ('cash') OR (p.payment_method_id IS NULL AND p.method != 'cash') THEN p.amount ELSE 0 END),0) other")
            ->first();
        $posRefundCash = DB::table('payment_refunds as r')->join('payments as p', 'p.id', '=', 'r.payment_id')->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('r.tenant_id', $tenantId)->whereIn('r.branch_id', $branchIds)->where('r.status', 'completed')
            ->whereBetween('r.refunded_at', [$range['start'], $range['end']])
            ->selectRaw("COALESCE(SUM(CASE WHEN pm.type = 'cash' OR (p.payment_method_id IS NULL AND p.method = 'cash') THEN r.amount ELSE 0 END),0) cash, COALESCE(SUM(CASE WHEN pm.type NOT IN ('cash') OR (p.payment_method_id IS NULL AND p.method != 'cash') THEN r.amount ELSE 0 END),0) other")
            ->first();

        $customerPaymentsByKind = DB::table('customer_payments as p')->join('financial_locations as l', 'l.id', '=', 'p.financial_location_id')
            ->where('p.tenant_id', $tenantId)->whereIn('p.branch_id', $branchIds)->where('p.status', 'posted')
            ->whereBetween('p.payment_date', [$dateFrom, $dateTo])
            ->selectRaw('l.kind, COALESCE(SUM(p.amount),0) total')->groupBy('l.kind')->pluck('total', 'kind');
        $customerRefundsByKind = DB::table('customer_refunds as r')->join('financial_locations as l', 'l.id', '=', 'r.financial_location_id')
            ->where('r.tenant_id', $tenantId)->whereIn('r.branch_id', $branchIds)->where('r.status', 'posted')
            ->whereBetween('r.refund_date', [$dateFrom, $dateTo])
            ->selectRaw('l.kind, COALESCE(SUM(r.amount),0) total')->groupBy('l.kind')->pluck('total', 'kind');

        $cashCents = Money::cents($posCash->cash ?? '0') - Money::cents($posRefundCash->cash ?? '0')
            + Money::cents($customerPaymentsByKind['cash'] ?? '0') - Money::cents($customerRefundsByKind['cash'] ?? '0');
        $bankCents = Money::cents($customerPaymentsByKind['bank'] ?? '0') - Money::cents($customerRefundsByKind['bank'] ?? '0');
        $otherCents = Money::cents($posCash->other ?? '0') - Money::cents($posRefundCash->other ?? '0');

        return ['cashCollectedCents' => $cashCents, 'bankCollectedCents' => $bankCents, 'otherCollectedCents' => $otherCents];
    }

    /**
     * Union of POS `order_items` + posted Manual `sales_invoice_lines`,
     * minus posted `sales_credit_note_lines` — grouped by product (fallback
     * to product name when the product was later deleted). Never derives
     * quantities from the journal (ADR-09).
     */
    public function productPerformance(int $tenantId, array $branchIds, string $dateFrom, string $dateTo, string $timezone): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($timezone, $dateFrom, $dateTo);

        $pos = DB::table('order_items as i')->join('orders as o', 'o.id', '=', 'i.order_id')
            ->where('o.tenant_id', $tenantId)->whereIn('o.branch_id', $branchIds)
            ->whereIn('o.payment_status', ['paid', 'partially_refunded', 'refunded'])->whereNull('o.deleted_at')->whereNull('i.deleted_at')
            ->whereBetween('o.closed_at', [$range['start'], $range['end']])
            ->selectRaw('i.product_id, i.product_name, SUM(i.quantity) quantity, SUM(i.total) gross, SUM(i.discount_total) discounts, COALESCE(SUM(i.cogs_total),0) cogs')
            ->groupBy('i.product_id', 'i.product_name')->get();

        $manual = DB::table('sales_invoice_lines as l')->join('sales_invoices as inv', 'inv.id', '=', 'l.sales_invoice_id')
            ->where('inv.tenant_id', $tenantId)->whereIn('inv.branch_id', $branchIds)->where('inv.status', 'posted')
            ->whereBetween('inv.invoice_date', [$dateFrom, $dateTo])
            ->selectRaw('l.product_id, l.product_name, SUM(l.quantity) quantity, SUM(l.subtotal + l.discount_total) gross, SUM(l.discount_total) discounts, COALESCE(SUM(l.cogs_total),0) cogs')
            ->groupBy('l.product_id', 'l.product_name')->get();

        $credit = DB::table('sales_credit_note_lines as l')->join('sales_credit_notes as n', 'n.id', '=', 'l.sales_credit_note_id')
            ->where('n.tenant_id', $tenantId)->whereIn('n.branch_id', $branchIds)->where('n.status', 'posted')
            ->whereBetween('n.credit_date', [$dateFrom, $dateTo])
            ->selectRaw('l.product_id, l.product_name, SUM(l.quantity) quantity, SUM(l.subtotal) net, COALESCE(SUM(l.cogs_total),0) cogs')
            ->groupBy('l.product_id', 'l.product_name')->get();

        $rows = [];
        $key = fn (object $r): string => $r->product_id !== null ? 'id:'.$r->product_id : 'name:'.$r->product_name;
        $ensure = function (string $k, object $r) use (&$rows): void {
            if (! isset($rows[$k])) {
                $rows[$k] = ['productId' => $r->product_id !== null ? (int) $r->product_id : null, 'name' => $r->product_name, 'quantity' => 0, 'grossCents' => 0, 'discountsCents' => 0, 'cogsCents' => 0];
            }
        };
        foreach ($pos as $r) { $k = $key($r); $ensure($k, $r); $rows[$k]['quantity'] += (float) $r->quantity; $rows[$k]['grossCents'] += Money::cents($r->gross); $rows[$k]['discountsCents'] += Money::cents($r->discounts); $rows[$k]['cogsCents'] += Money::cents($r->cogs); }
        foreach ($manual as $r) { $k = $key($r); $ensure($k, $r); $rows[$k]['quantity'] += (float) $r->quantity; $rows[$k]['grossCents'] += Money::cents($r->gross); $rows[$k]['discountsCents'] += Money::cents($r->discounts); $rows[$k]['cogsCents'] += Money::cents($r->cogs); }
        foreach ($credit as $r) { $k = $key($r); $ensure($k, $r); $rows[$k]['quantity'] -= (float) $r->quantity; $rows[$k]['grossCents'] -= Money::cents($r->net); $rows[$k]['cogsCents'] -= Money::cents($r->cogs); }

        $productIds = array_values(array_filter(array_column($rows, 'productId'), fn ($id) => $id !== null));
        $categories = $productIds === [] ? collect() : DB::table('products as p')->leftJoin('categories as c', 'c.id', '=', 'p.category_id')
            ->whereIn('p.id', $productIds)->pluck('c.name', 'p.id');

        return collect($rows)->map(function (array $row) use ($categories): array {
            $netCents = $row['grossCents'] - $row['discountsCents'];
            $grossProfitCents = $netCents - $row['cogsCents'];

            return [
                'productId' => $row['productId'],
                'name' => $row['name'],
                'category' => $row['productId'] !== null ? ($categories[$row['productId']] ?? null) : null,
                'quantity' => $row['quantity'],
                'grossSales' => Money::decimal($row['grossCents']),
                'discounts' => Money::decimal($row['discountsCents']),
                'netSales' => Money::decimal($netCents),
                'cogs' => Money::decimal($row['cogsCents']),
                'grossProfit' => Money::decimal($grossProfitCents),
                'margin' => SafeMath::ratioPercentage($grossProfitCents, $netCents),
            ];
        })->values()->all();
    }

    /** @return array{grossCents:int,discountsCents:int,taxCents:int,netCents:int,cogsCents:int,refundRevenueCents:int,refundTaxCents:int} */
    private function posComponents(int $tenantId, array $branchIds, string $dateFrom, string $dateTo, string $timezone): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($timezone, $dateFrom, $dateTo);
        $orders = DB::table('orders')->where('tenant_id', $tenantId)->whereIn('branch_id', $branchIds)
            ->whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])->whereNull('deleted_at')
            ->whereBetween('closed_at', [$range['start'], $range['end']])
            ->selectRaw('COALESCE(SUM(subtotal),0) subtotal, COALESCE(SUM(discount_total),0) discounts, COALESCE(SUM(tax_total),0) tax, COALESCE(SUM(cogs_total),0) cogs')
            ->first();

        [$refundRevenueCents, $refundTaxCents] = $this->posRefundRevenueAndTax($tenantId, $branchIds, $range['start'], $range['end']);
        $grossCents = Money::cents($orders->subtotal ?: '0');
        $discountsCents = Money::cents($orders->discounts ?: '0');
        $taxCents = Money::cents($orders->tax ?: '0');
        $cogsCents = Money::cents($orders->cogs ?: '0');

        return ['grossCents' => $grossCents, 'discountsCents' => $discountsCents, 'taxCents' => $taxCents, 'netCents' => $grossCents - $discountsCents - $refundRevenueCents, 'cogsCents' => $cogsCents, 'refundRevenueCents' => $refundRevenueCents, 'refundTaxCents' => $refundTaxCents];
    }

    /** @return array{0:int,1:int} Tax-exclusive refund revenue and tax-liability reversal, mirroring FinanceKpiQueryService::refundRevenueAndTax() for the same POS payment_refunds evidence. */
    private function posRefundRevenueAndTax(int $tenantId, array $branchIds, $start, $end): array
    {
        $rows = DB::table('payment_refunds as refunds')->join('orders', 'orders.id', '=', 'refunds.order_id')
            ->where('refunds.tenant_id', $tenantId)->whereIn('refunds.branch_id', $branchIds)
            ->where('refunds.status', 'completed')->where('refunds.refunded_at', '<=', $end)
            ->orderBy('refunds.order_id')->orderBy('refunds.refunded_at')->orderBy('refunds.id')
            ->get(['refunds.id', 'refunds.order_id', 'refunds.amount', 'refunds.refunded_at', 'orders.total as order_total', 'orders.tax_total']);

        $revenueCents = 0; $taxCents = 0; $refundedByOrder = [];
        foreach ($rows as $row) {
            $before = $refundedByOrder[$row->order_id] ?? 0;
            $amount = Money::cents($row->amount);
            $refundTax = RefundTaxAllocation::taxCents(Money::cents($row->order_total), Money::cents($row->tax_total), $before, $amount);
            $refundedByOrder[$row->order_id] = $before + $amount;
            if ($row->refunded_at >= $start) {
                $revenueCents += $amount - $refundTax;
                $taxCents += $refundTax;
            }
        }

        return [$revenueCents, $taxCents];
    }

    /** @return array{grossCents:int,discountsCents:int,taxCents:int,netCents:int,cogsCents:int} Posted Manual Sales Invoices, dated by invoice_date. */
    private function manualInvoiceComponents(int $tenantId, array $branchIds, string $dateFrom, string $dateTo): array
    {
        $header = DB::table('sales_invoices')->where('tenant_id', $tenantId)->whereIn('branch_id', $branchIds)->where('status', 'posted')
            ->whereBetween('invoice_date', [$dateFrom, $dateTo])
            ->selectRaw('COALESCE(SUM(subtotal),0) subtotal, COALESCE(SUM(discount_total),0) discounts, COALESCE(SUM(tax_total),0) tax')->first();
        $cogs = DB::table('sales_invoice_lines as l')->join('sales_invoices as i', 'i.id', '=', 'l.sales_invoice_id')
            ->where('i.tenant_id', $tenantId)->whereIn('i.branch_id', $branchIds)->where('i.status', 'posted')
            ->whereBetween('i.invoice_date', [$dateFrom, $dateTo])
            ->selectRaw('COALESCE(SUM(l.cogs_total),0) cogs')->value('cogs');

        $netCents = Money::cents($header->subtotal ?: '0');
        $discountsCents = Money::cents($header->discounts ?: '0');

        return ['grossCents' => $netCents + $discountsCents, 'discountsCents' => $discountsCents, 'taxCents' => Money::cents($header->tax ?: '0'), 'netCents' => $netCents, 'cogsCents' => Money::cents($cogs ?: '0')];
    }

    /** @return array{netCents:int,taxCents:int,cogsCents:int} Posted Sales Credit Notes, dated by credit_date — reduces manual-invoice revenue exactly once (never a second reduction from the resulting Customer Refund). */
    private function creditNoteComponents(int $tenantId, array $branchIds, string $dateFrom, string $dateTo): array
    {
        $header = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->whereIn('branch_id', $branchIds)->where('status', 'posted')
            ->whereBetween('credit_date', [$dateFrom, $dateTo])
            ->selectRaw('COALESCE(SUM(subtotal),0) subtotal, COALESCE(SUM(tax_total),0) tax')->first();
        $cogs = DB::table('sales_credit_note_lines as l')->join('sales_credit_notes as n', 'n.id', '=', 'l.sales_credit_note_id')
            ->where('n.tenant_id', $tenantId)->whereIn('n.branch_id', $branchIds)->where('n.status', 'posted')
            ->whereBetween('n.credit_date', [$dateFrom, $dateTo])
            ->selectRaw('COALESCE(SUM(l.cogs_total),0) cogs')->value('cogs');

        return ['netCents' => Money::cents($header->subtotal ?: '0'), 'taxCents' => Money::cents($header->tax ?: '0'), 'cogsCents' => Money::cents($cogs ?: '0')];
    }
}
