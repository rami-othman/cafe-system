<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;

final class DailyClosingSummaryService
{
    public function __construct(private readonly BusinessDayRangeResolver $days) {}
    public function summarize(int $tenant, int $branch, string $date): array
    {
        $range = $this->days->resolve($tenant, $branch, $date); $start = $range['start']; $end = $range['end']; $day = $range['date'];
        $payment = DB::table('payments as p')->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')->where('p.tenant_id',$tenant)->where('p.branch_id',$branch)->where('p.status','completed')->whereNull('p.deleted_at')->whereBetween('p.paid_at',[$start,$end])->selectRaw("COALESCE(SUM(p.amount),0) total, COALESCE(SUM(CASE WHEN pm.type = 'cash' OR (p.payment_method_id IS NULL AND p.method = 'cash') THEN p.amount ELSE 0 END),0) cash, COALESCE(SUM(CASE WHEN pm.type IN ('card','wallet') OR (p.payment_method_id IS NULL AND p.method = 'card') THEN p.amount ELSE 0 END),0) card")->first();
        $refund = DB::table('payment_refunds as r')->join('payments as p','p.id','=','r.payment_id')->leftJoin('payment_methods as pm','pm.id','=','p.payment_method_id')->where('r.tenant_id',$tenant)->where('r.branch_id',$branch)->where('r.status','completed')->whereBetween('r.refunded_at',[$start,$end])->selectRaw("COALESCE(SUM(r.amount),0) total, COALESCE(SUM(CASE WHEN pm.type = 'cash' OR (p.payment_method_id IS NULL AND p.method = 'cash') THEN r.amount ELSE 0 END),0) cash, COALESCE(SUM(CASE WHEN pm.type IN ('card','wallet') OR (p.payment_method_id IS NULL AND p.method = 'card') THEN r.amount ELSE 0 END),0) card")->first();
        $orders = DB::table('orders')->where('tenant_id',$tenant)->where('branch_id',$branch)->where('payment_status','!=','unpaid')->whereNull('deleted_at')->whereBetween('closed_at',[$start,$end])->selectRaw('COALESCE(SUM(subtotal + tax_total + service_total),0) gross, COALESCE(SUM(discount_total),0) discounts')->first();
        $cashLocationIds = DB::table('financial_locations')->where('tenant_id',$tenant)->where('kind','cash')->where('is_active',true)->where(fn ($q) => $q->where('branch_id',$branch)->orWhereNull('branch_id'))->pluck('id');
        $expense = DB::table('expenses as e')->leftJoin('financial_locations as l','l.id','=','e.paid_from_financial_location_id')->where('e.tenant_id',$tenant)->where('e.branch_id',$branch)->whereDate('e.expense_date',$day)->whereNull('e.deleted_at')->selectRaw('COALESCE(SUM(CASE WHEN e.status = \'paid\' THEN e.total_amount ELSE 0 END),0) paid, COALESCE(SUM(CASE WHEN e.status = \'paid\' AND l.kind = \'cash\' THEN e.total_amount ELSE 0 END),0) cash_paid, COALESCE(SUM(CASE WHEN e.status = \'pending_approval\' THEN 1 ELSE 0 END),0) pending_count')->first();
        $supplier = DB::table('supplier_payments as p')->join('financial_locations as l','l.id','=','p.financial_location_id')->where('p.tenant_id',$tenant)->where('p.branch_id',$branch)->where('p.status','posted')->whereDate('p.payment_date',$day)->selectRaw("COALESCE(SUM(p.amount),0) total, COALESCE(SUM(CASE WHEN l.kind = 'cash' THEN p.amount ELSE 0 END),0) cash_paid")->first();
        $transfers = DB::table('cash_transfers')->where('tenant_id',$tenant)->where('status','posted')->whereDate('transfer_date',$day)->selectRaw('COALESCE(SUM(CASE WHEN to_financial_location_id IN ('.($cashLocationIds->isEmpty() ? '0' : $cashLocationIds->implode(',')).') THEN amount ELSE 0 END),0) incoming, COALESCE(SUM(CASE WHEN from_financial_location_id IN ('.($cashLocationIds->isEmpty() ? '0' : $cashLocationIds->implode(',')).') THEN amount ELSE 0 END),0) outgoing')->first();
        $shifts = DB::table('shifts')->where('tenant_id',$tenant)->where('branch_id',$branch)->whereNull('deleted_at')->whereBetween('opened_at',[$start,$end])->selectRaw("COUNT(*) total, SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END) open, SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) closed, COALESCE(SUM(opening_cash),0) opening")->first();
        $inventory = DB::table('stock_movements')->where('tenant_id',$tenant)->where('branch_id',$branch)->whereDate('occurred_at',$day)->selectRaw("COALESCE(SUM(CASE WHEN type = 'waste' THEN total_cost ELSE 0 END),0) waste, COALESCE(SUM(CASE WHEN type = 'stock_count_variance' AND quantity_out > 0 THEN total_cost ELSE 0 END),0) shortage, COALESCE(SUM(CASE WHEN type = 'stock_count_variance' AND quantity_in > 0 THEN total_cost ELSE 0 END),0) surplus")->first();
        $m = fn ($v) => Money::cents($v ?? '0'); $gross=$m($orders->gross); $discounts=$m($orders->discounts); $refunds=$m($refund->total); $cashSales=$m($payment->cash); $cardSales=$m($payment->card); $other=$m($payment->total)-$cashSales-$cardSales; $opening=$m($shifts->opening); $expected=$opening+$cashSales-$m($refund->cash)-$m($expense->cash_paid)-$m($supplier->cash_paid)+$m($transfers->incoming)-$m($transfers->outgoing);
        return ['businessDate'=>$day,'timezone'=>$range['timezone'],'branch'=>['id'=>$branch,'name'=>$range['branch']->name],'sales'=>['grossSales'=>Money::decimal($gross),'discounts'=>Money::decimal($discounts),'refunds'=>Money::decimal($refunds),'netSales'=>Money::decimal($gross-$discounts-$refunds),'cashSales'=>Money::decimal($cashSales),'cardSales'=>Money::decimal($cardSales),'otherSales'=>Money::decimal($other)],'refunds'=>['total'=>Money::decimal($refunds),'cash'=>Money::decimal($m($refund->cash)),'card'=>Money::decimal($m($refund->card)),'other'=>Money::decimal($refunds-$m($refund->cash)-$m($refund->card))],'cash'=>['openingCash'=>Money::decimal($opening),'cashSales'=>Money::decimal($cashSales),'cashRefunds'=>Money::decimal($m($refund->cash)),'expensesCash'=>Money::decimal($m($expense->cash_paid)),'supplierPaymentsCash'=>Money::decimal($m($supplier->cash_paid)),'transfersIn'=>Money::decimal($m($transfers->incoming)),'transfersOut'=>Money::decimal($m($transfers->outgoing)),'expectedCash'=>Money::decimal($expected)],'operations'=>['expensesTotal'=>Money::decimal($m($expense->paid)),'pendingExpensesCount'=>(int)$expense->pending_count,'supplierPaymentsTotal'=>Money::decimal($m($supplier->total)),'wasteValue'=>Money::decimal($m($inventory->waste)),'stockShortageValue'=>Money::decimal($m($inventory->shortage)),'stockSurplusValue'=>Money::decimal($m($inventory->surplus))],'shifts'=>['total'=>(int)$shifts->total,'open'=>(int)$shifts->open,'closed'=>(int)$shifts->closed],'paymentBreakdown'=>$this->paymentBreakdown($tenant,$branch,$start,$end)];
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
