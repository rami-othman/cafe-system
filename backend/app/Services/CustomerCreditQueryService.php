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
}
