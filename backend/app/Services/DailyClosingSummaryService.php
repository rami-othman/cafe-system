<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;

final class DailyClosingSummaryService
{
    public function __construct(private readonly BusinessDayRangeResolver $days) {}

    /** Per-request memo of cash financial_location ids, keyed by "tenant:branch" — date-independent, but summarize() runs once per date. */
    private static array $cashLocationIdsCache = [];

    /**
     * $includeBreakdown controls the 2 extra payment-breakdown queries.
     * FinancialReconciliationQueryService::summaryForFinanceContext() calls
     * summarize() once per (branch, day) in a dashboard date range purely to
     * feed DailyClosingReconciliationPolicy::evaluate(), which only reads
     * cash.openingCash/cash.cashSales — paymentBreakdown is never read
     * there, so skipping it removes 2 wasted round trips per iteration.
     */
    public function summarize(int $tenant, int $branch, string $date, bool $includeBreakdown = true): array
    {
        $range = $this->days->resolve($tenant, $branch, $date); $start = $range['start']; $end = $range['end']; $day = $range['date'];
        $cacheKey = $tenant.':'.$branch;
        $cashLocationIds = self::$cashLocationIdsCache[$cacheKey] ??= DB::table('financial_locations')->where('tenant_id',$tenant)->where('kind','cash')->where('is_active',true)->where(fn ($q) => $q->where('branch_id',$branch)->orWhereNull('branch_id'))->pluck('id');
        $row = $this->aggregates($tenant, $branch, $start, $end, $day, $cashLocationIds);
        $m = fn ($v) => Money::cents($v ?? '0'); $gross=$m($row->orders_gross); $discounts=$m($row->orders_discounts); $refunds=$m($row->refund_total); $cashSales=$m($row->payment_cash); $cardSales=$m($row->payment_card); $other=$m($row->payment_total)-$cashSales-$cardSales; $opening=$m($row->shifts_opening);
        // Customer Payment cash collections (Dr cash/bank, Cr AR — never a
        // second "sale") are added here exactly once, on the receipt's own
        // business date, mirroring how supplier_cash_paid is subtracted:
        // both are non-POS Finance cash-account movements, independent of
        // POS shift status (see docs/sales SALES_ARCHITECTURE_DECISIONS.md
        // §17-18 / ADR-08). The originating credit invoice never adds cash.
        $customerPaymentsCash = $m($row->customer_payment_cash_received);
        // A Customer Refund (Phase 4) settles unapplied customer credit, not
        // a sale reversal — it decreases expected cash only when cash
        // actually leaves the drawer, exactly mirroring supplier_cash_paid.
        // The originating Credit Note itself never moves cash (§30).
        $customerRefundsCash = $m($row->customer_refund_cash_paid);
        $expected=$opening+$cashSales-$m($row->refund_cash)-$m($row->expense_cash_paid)-$m($row->supplier_cash_paid)+$customerPaymentsCash-$customerRefundsCash+$m($row->transfers_incoming)-$m($row->transfers_outgoing);
        return ['businessDate'=>$day,'timezone'=>$range['timezone'],'branch'=>['id'=>$branch,'name'=>$range['branch']->name],'sales'=>['grossSales'=>Money::decimal($gross),'discounts'=>Money::decimal($discounts),'refunds'=>Money::decimal($refunds),'netSales'=>Money::decimal($gross-$discounts-$refunds),'cashSales'=>Money::decimal($cashSales),'cardSales'=>Money::decimal($cardSales),'otherSales'=>Money::decimal($other)],'refunds'=>['total'=>Money::decimal($refunds),'cash'=>Money::decimal($m($row->refund_cash)),'card'=>Money::decimal($m($row->refund_card)),'other'=>Money::decimal($refunds-$m($row->refund_cash)-$m($row->refund_card))],'cash'=>['openingCash'=>Money::decimal($opening),'cashSales'=>Money::decimal($cashSales),'cashRefunds'=>Money::decimal($m($row->refund_cash)),'expensesCash'=>Money::decimal($m($row->expense_cash_paid)),'supplierPaymentsCash'=>Money::decimal($m($row->supplier_cash_paid)),'customerPaymentsCash'=>Money::decimal($customerPaymentsCash),'customerRefundsCash'=>Money::decimal($customerRefundsCash),'transfersIn'=>Money::decimal($m($row->transfers_incoming)),'transfersOut'=>Money::decimal($m($row->transfers_outgoing)),'expectedCash'=>Money::decimal($expected)],'operations'=>['expensesTotal'=>Money::decimal($m($row->expense_paid)),'pendingExpensesCount'=>(int)$row->expense_pending_count,'supplierPaymentsTotal'=>Money::decimal($m($row->supplier_total)),'customerPaymentsTotal'=>Money::decimal($m($row->customer_payment_total)),'customerRefundsTotal'=>Money::decimal($m($row->customer_refund_total)),'wasteValue'=>Money::decimal($m($row->inv_waste)),'stockShortageValue'=>Money::decimal($m($row->inv_shortage)),'stockSurplusValue'=>Money::decimal($m($row->inv_surplus))],'shifts'=>['total'=>(int)$row->shifts_total,'open'=>(int)$row->shifts_open,'closed'=>(int)$row->shifts_closed],'paymentBreakdown'=>$includeBreakdown ? $this->paymentBreakdown($tenant,$branch,$start,$end) : []];
    }

    /**
     * The 8 aggregates below are each independent single-row SUM/COUNT
     * queries (no GROUP BY, always exactly one row) over different tables.
     * Originally each ran as its own round trip (11 queries/day — the
     * dominant cost of the Finance Overview N+1, since this runs once per
     * open/closed daily-closing row). They're combined here into one
     * statement via an implicit cross join of single-row derived tables —
     * every WHERE/CASE expression is unchanged from the original per-table
     * queries, only the round-trip count changes.
     */
    private function aggregates(int $tenant, int $branch, $start, $end, string $day, $cashLocationIds): object
    {
        $ids = $cashLocationIds->isEmpty() ? '0' : $cashLocationIds->implode(',');

        $builders = [
            'payment' => DB::table('payments as p')->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')->where('p.tenant_id',$tenant)->where('p.branch_id',$branch)->where('p.status','completed')->whereNull('p.deleted_at')->whereBetween('p.paid_at',[$start,$end])->selectRaw("COALESCE(SUM(p.amount),0) payment_total, COALESCE(SUM(CASE WHEN pm.type = 'cash' OR (p.payment_method_id IS NULL AND p.method = 'cash') THEN p.amount ELSE 0 END),0) payment_cash, COALESCE(SUM(CASE WHEN pm.type IN ('card','wallet') OR (p.payment_method_id IS NULL AND p.method = 'card') THEN p.amount ELSE 0 END),0) payment_card"),
            'refund' => DB::table('payment_refunds as r')->join('payments as p','p.id','=','r.payment_id')->leftJoin('payment_methods as pm','pm.id','=','p.payment_method_id')->where('r.tenant_id',$tenant)->where('r.branch_id',$branch)->where('r.status','completed')->whereBetween('r.refunded_at',[$start,$end])->selectRaw("COALESCE(SUM(r.amount),0) refund_total, COALESCE(SUM(CASE WHEN pm.type = 'cash' OR (p.payment_method_id IS NULL AND p.method = 'cash') THEN r.amount ELSE 0 END),0) refund_cash, COALESCE(SUM(CASE WHEN pm.type IN ('card','wallet') OR (p.payment_method_id IS NULL AND p.method = 'card') THEN r.amount ELSE 0 END),0) refund_card"),
            'orders' => DB::table('orders')->where('tenant_id',$tenant)->where('branch_id',$branch)->where('payment_status','!=','unpaid')->whereNull('deleted_at')->whereBetween('closed_at',[$start,$end])->selectRaw('COALESCE(SUM(subtotal + tax_total + service_total),0) orders_gross, COALESCE(SUM(discount_total),0) orders_discounts'),
            'expense' => DB::table('expenses as e')->leftJoin('financial_locations as l','l.id','=','e.paid_from_financial_location_id')->where('e.tenant_id',$tenant)->where('e.branch_id',$branch)->whereDate('e.expense_date',$day)->whereNull('e.deleted_at')->selectRaw('COALESCE(SUM(CASE WHEN e.status = \'paid\' THEN e.total_amount ELSE 0 END),0) expense_paid, COALESCE(SUM(CASE WHEN e.status = \'paid\' AND l.kind = \'cash\' THEN e.total_amount ELSE 0 END),0) expense_cash_paid, COALESCE(SUM(CASE WHEN e.status = \'pending_approval\' THEN 1 ELSE 0 END),0) expense_pending_count'),
            'supplier' => DB::table('supplier_payments as p')->join('financial_locations as l','l.id','=','p.financial_location_id')->where('p.tenant_id',$tenant)->where('p.branch_id',$branch)->where('p.status','posted')->whereDate('p.payment_date',$day)->selectRaw("COALESCE(SUM(p.amount),0) supplier_total, COALESCE(SUM(CASE WHEN l.kind = 'cash' THEN p.amount ELSE 0 END),0) supplier_cash_paid"),
            'customer_payment' => DB::table('customer_payments as p')->join('financial_locations as l','l.id','=','p.financial_location_id')->where('p.tenant_id',$tenant)->where('p.branch_id',$branch)->where('p.status','posted')->whereDate('p.payment_date',$day)->selectRaw("COALESCE(SUM(p.amount),0) customer_payment_total, COALESCE(SUM(CASE WHEN l.kind = 'cash' THEN p.amount ELSE 0 END),0) customer_payment_cash_received"),
            'customer_refund' => DB::table('customer_refunds as r')->join('financial_locations as l','l.id','=','r.financial_location_id')->where('r.tenant_id',$tenant)->where('r.branch_id',$branch)->where('r.status','posted')->whereDate('r.refund_date',$day)->selectRaw("COALESCE(SUM(r.amount),0) customer_refund_total, COALESCE(SUM(CASE WHEN l.kind = 'cash' THEN r.amount ELSE 0 END),0) customer_refund_cash_paid"),
            'transfers' => DB::table('cash_transfers')->where('tenant_id',$tenant)->where('status','posted')->whereDate('transfer_date',$day)->selectRaw("COALESCE(SUM(CASE WHEN to_financial_location_id IN ({$ids}) THEN amount ELSE 0 END),0) transfers_incoming, COALESCE(SUM(CASE WHEN from_financial_location_id IN ({$ids}) THEN amount ELSE 0 END),0) transfers_outgoing"),
            'shifts' => DB::table('shifts')->where('tenant_id',$tenant)->where('branch_id',$branch)->whereNull('deleted_at')->whereBetween('opened_at',[$start,$end])->selectRaw("COUNT(*) shifts_total, SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END) shifts_open, SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) shifts_closed, COALESCE(SUM(opening_cash),0) shifts_opening"),
            'inventory' => DB::table('stock_movements')->where('tenant_id',$tenant)->where('branch_id',$branch)->whereDate('occurred_at',$day)->selectRaw("COALESCE(SUM(CASE WHEN type = 'waste' THEN total_cost ELSE 0 END),0) inv_waste, COALESCE(SUM(CASE WHEN type = 'stock_count_variance' AND quantity_out > 0 THEN total_cost ELSE 0 END),0) inv_shortage, COALESCE(SUM(CASE WHEN type = 'stock_count_variance' AND quantity_in > 0 THEN total_cost ELSE 0 END),0) inv_surplus"),
        ];

        $from = [];
        $bindings = [];
        foreach ($builders as $alias => $builder) {
            $from[] = '('.$builder->toSql().') as '.$alias;
            $bindings = array_merge($bindings, $builder->getBindings());
        }

        return DB::selectOne('select * from '.implode(', ', $from), $bindings);
    }

    /** Real per-payment-method gross/refunded/net for the business day, grouped by the actual `payment_methods` row (falling back to the legacy `payments.method` string when unmapped) — the same rows `summarize()` aggregates into cash/card/other, just not collapsed. */
    private function paymentBreakdown(int $tenant, int $branch, string $start, string $end): array
    {
        $gross = DB::table('payments as p')->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('p.tenant_id', $tenant)->where('p.branch_id', $branch)->where('p.status', 'completed')->whereNull('p.deleted_at')
            ->whereBetween('p.paid_at', [$start, $end])
            ->selectRaw("COALESCE(p.payment_method_id,0) as method_key, COALESCE(pm.name, CASE WHEN p.method = 'cash' THEN 'نقدي' WHEN p.method = 'card' THEN 'بطاقة' ELSE p.method END) as method_name, COALESCE(SUM(p.amount),0) as gross")
            ->groupBy('method_key', 'method_name')->orderByDesc('gross')->get();

        $refunded = DB::table('payment_refunds as r')->join('payments as p', 'p.id', '=', 'r.payment_id')
            ->where('r.tenant_id', $tenant)->where('r.branch_id', $branch)->where('r.status', 'completed')
            ->whereBetween('r.refunded_at', [$start, $end])
            ->selectRaw('COALESCE(p.payment_method_id,0) as method_key, COALESCE(SUM(r.amount),0) as refunded')
            ->groupBy('method_key')->get()->keyBy('method_key');

        return $gross->map(function (object $row) use ($refunded): array {
            $g = Money::cents($row->gross);
            $r = Money::cents(optional($refunded->get($row->method_key))->refunded ?? '0');

            return ['method' => $row->method_name, 'gross' => Money::decimal($g), 'refunded' => Money::decimal($r), 'net' => Money::decimal($g - $r)];
        })->values()->all();
    }
}
