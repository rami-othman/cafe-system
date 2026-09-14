<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;

/**
 * The single authoritative source for a customer's unapplied credit balance
 * (docs/sales Phase 4 §10). It is never a stored column — always derived as
 * SUM(customer_credit_ledger.amount) for that customer: a posted Credit
 * Note's excess-over-outstanding grants credit (positive row); a posted
 * Customer Refund consumes it (negative row). This mirrors how AR itself is
 * derived rather than cached (CustomerReceivableQueryService).
 */
final class CustomerCreditQueryService
{
    /** Pass $lock inside a refund-posting transaction to serialize concurrent settlement against the same balance. */
    public function balanceCents(int $tenantId, int $customerId, bool $lock = false): int
    {
        $query = DB::table('customer_credit_ledger')->where('tenant_id', $tenantId)->where('customer_id', $customerId);
        if ($lock) {
            // PostgreSQL rejects FOR UPDATE on SUM(...); lock the ledger rows
            // themselves before summing (mirrors CustomerReceivableQueryService).
            return $query->lockForUpdate()->pluck('amount')->reduce(
                fn (int $total, mixed $amount): int => $total + Money::cents($amount),
                0,
            );
        }

        return Money::cents($query->sum('amount') ?: '0');
    }

    public function balance(int $tenantId, int $customerId): string
    {
        return Money::decimal($this->balanceCents($tenantId, $customerId));
    }

    /**
     * Credit balance as of a past business date, for aging/statement
     * snapshots — joins each ledger row to its originating document's own
     * business date (credit_date for a grant, refund_date for a
     * consumption) rather than `created_at`, since posting and the
     * document's business date can differ.
     */
    public function balanceCentsAsOf(int $tenantId, int $customerId, string $asOfDate): int
    {
        $grants = DB::table('customer_credit_ledger as l')->join('sales_credit_notes as n', 'n.id', '=', 'l.sales_credit_note_id')
            ->where('l.tenant_id', $tenantId)->where('l.customer_id', $customerId)->whereDate('n.credit_date', '<=', $asOfDate)
            ->sum('l.amount') ?: '0';
        $consumptions = DB::table('customer_credit_ledger as l')->join('customer_refunds as r', 'r.id', '=', 'l.customer_refund_id')
            ->where('l.tenant_id', $tenantId)->where('l.customer_id', $customerId)->whereDate('r.refund_date', '<=', $asOfDate)
            ->sum('l.amount') ?: '0';

        return Money::cents($grants) + Money::cents($consumptions);
    }

    /** Tenant-wide unapplied customer credit as of a cutoff date, for the Finance Dashboard tile. */
    public function totalBalanceCentsAsOf(int $tenantId, string $asOfDate): int
    {
        $grants = DB::table('customer_credit_ledger as l')->join('sales_credit_notes as n', 'n.id', '=', 'l.sales_credit_note_id')
            ->where('l.tenant_id', $tenantId)->whereDate('n.credit_date', '<=', $asOfDate)->sum('l.amount') ?: '0';
        $consumptions = DB::table('customer_credit_ledger as l')->join('customer_refunds as r', 'r.id', '=', 'l.customer_refund_id')
            ->where('l.tenant_id', $tenantId)->whereDate('r.refund_date', '<=', $asOfDate)->sum('l.amount') ?: '0';

        return Money::cents($grants) + Money::cents($consumptions);
    }
}
