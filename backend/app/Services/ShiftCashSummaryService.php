<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;

/**
 * The single authoritative cash-drawer summary for a shift. Daily Closing and
 * any other future consumer must reuse this rather than recomputing its own
 * formula (see docs/finance/FINANCE_IMPLEMENTATION_PLAN.md Phase 9).
 *
 * A payment/refund counts as "cash" through its resolved Payment Method
 * (Phase 2) when one is set, falling back to the legacy `method` string only
 * when no payment_method_id is present — never both, so a payment explicitly
 * mapped to a non-cash method (e.g. a card method that happens to still carry
 * the legacy string "cash") is never miscounted as drawer cash.
 *
 * Card/bank payments and unrelated Phase 2 cash transfers between financial
 * locations are deliberately excluded, since neither is a movement of this
 * shift's physical drawer. Dedicated shift cash movements are included: a
 * deposit adds to the drawer while withdrawals and expenses reduce it.
 */
class ShiftCashSummaryService
{
    /**
     * @return array{openingCash:string,cashSales:string,cashRefunds:string,withdrawals:string,deposits:string,expenses:string,expectedCash:string}
     */
    public function summarize(int $tenantId, object $shift): array
    {
        $openingCents = Money::cents($shift->opening_cash);
        $cashSalesCents = Money::cents($this->cashPaymentsQuery($tenantId, $shift->id)->sum('p.amount') ?? '0');
        $cashRefundsCents = Money::cents($this->cashRefundsQuery($tenantId, $shift->id)->sum('r.amount') ?? '0');
        $customerPaymentsCents = Money::cents(DB::table('customer_payments')->where('tenant_id', $tenantId)
            ->where('shift_id', $shift->id)->where('financial_location_id', $shift->financial_location_id)
            ->where('status', 'posted')->sum('amount') ?? '0');
        $customerRefundsCents = Money::cents(DB::table('customer_refunds')->where('tenant_id', $tenantId)
            ->where('shift_id', $shift->id)->where('financial_location_id', $shift->financial_location_id)
            ->where('status', 'posted')->sum('amount') ?? '0');
        $operationalExpensesCents = Money::cents(DB::table('expenses')->where('tenant_id', $tenantId)
            ->where('shift_id', $shift->id)->where('paid_from_financial_location_id', $shift->financial_location_id)
            ->where('status', 'paid')->whereNull('deleted_at')->sum('total_amount') ?? '0');
        $movements = DB::table('shift_cash_movements')
            ->where('tenant_id', $tenantId)->where('shift_id', $shift->id)
            ->selectRaw("COALESCE(SUM(CASE WHEN kind = 'withdrawal' THEN amount ELSE 0 END), 0) as withdrawals")
            ->selectRaw("COALESCE(SUM(CASE WHEN kind = 'deposit' THEN amount ELSE 0 END), 0) as deposits")
            ->selectRaw("COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount ELSE 0 END), 0) as expenses")
            ->first();
        $withdrawalsCents = Money::cents($movements?->withdrawals ?? '0');
        $depositsCents = Money::cents($movements?->deposits ?? '0');
        $expensesCents = Money::cents($movements?->expenses ?? '0');
        $expectedCents = $openingCents + $cashSalesCents + $customerPaymentsCents + $depositsCents
            - $cashRefundsCents - $customerRefundsCents - $withdrawalsCents - $expensesCents - $operationalExpensesCents;

        return [
            'openingCash' => Money::decimal($openingCents),
            'cashSales' => Money::decimal($cashSalesCents),
            'cashRefunds' => Money::decimal($cashRefundsCents),
            'customerPayments' => Money::decimal($customerPaymentsCents),
            'customerRefunds' => Money::decimal($customerRefundsCents),
            'withdrawals' => Money::decimal($withdrawalsCents),
            'deposits' => Money::decimal($depositsCents),
            'expenses' => Money::decimal($expensesCents + $operationalExpensesCents),
            'expectedCash' => Money::decimal($expectedCents),
        ];
    }

    private function cashPaymentsQuery(int $tenantId, int $shiftId)
    {
        return DB::table('payments as p')
            ->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('p.tenant_id', $tenantId)
            ->where('p.shift_id', $shiftId)
            ->where('p.status', 'completed')
            ->whereNull('p.deleted_at')
            ->where(fn ($q) => $q->where('pm.type', 'cash')->orWhere(fn ($q2) => $q2->whereNull('p.payment_method_id')->where('p.method', 'cash')));
    }

    private function cashRefundsQuery(int $tenantId, int $shiftId)
    {
        return DB::table('payment_refunds as r')
            ->join('payments as p', 'p.id', '=', 'r.payment_id')
            ->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('r.tenant_id', $tenantId)
            ->where('r.shift_id', $shiftId)
            ->where('r.status', 'completed')
            ->where(fn ($q) => $q->where('pm.type', 'cash')->orWhere(fn ($q2) => $q2->whereNull('p.payment_method_id')->where('p.method', 'cash')));
    }
}
