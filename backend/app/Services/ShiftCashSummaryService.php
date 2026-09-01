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
 * Only opening cash, cash sales, and cash refunds are included: card/bank
 * payments and unrelated Phase 2 cash transfers between financial locations
 * are deliberately excluded, since neither is a movement of this shift's
 * physical drawer.
 */
class ShiftCashSummaryService
{
    /**
     * @return array{openingCash:string,cashSales:string,cashRefunds:string,expectedCash:string}
     */
    public function summarize(int $tenantId, object $shift): array
    {
        $openingCents = Money::cents($shift->opening_cash);
        $cashSalesCents = Money::cents($this->cashPaymentsQuery($tenantId, $shift->id)->sum('p.amount') ?? '0');
        $cashRefundsCents = Money::cents($this->cashRefundsQuery($tenantId, $shift->id)->sum('r.amount') ?? '0');
        $expectedCents = $openingCents + $cashSalesCents - $cashRefundsCents;

        return [
            'openingCash' => Money::decimal($openingCents),
            'cashSales' => Money::decimal($cashSalesCents),
            'cashRefunds' => Money::decimal($cashRefundsCents),
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
