<?php

namespace App\Support;

/**
 * Single source of truth for the three sales definitions (client decision
 * 2026-09-28, T5), applied identically across the shift, daily closing,
 * finance overview, sales reports, cashier dashboard, and shift history:
 *
 *   salesSum   = every completed sale in the period, before any deduction
 *   salesTotal = salesSum − refunds − discounts               ("الإجمالي")
 *   salesNet   = salesTotal − purchasesPaid − expensesPaid    ("صافي المبيعات")
 *
 * Gross profit and gross margin are always computed from salesTotal, never
 * salesNet — otherwise purchases would be deducted twice (once here, once
 * as cost of goods sold).
 */
final class SalesTotals
{
    /** All arguments and return values are in cents. */
    public static function make(int $salesSumCents, int $refundsCents, int $discountsCents, int $purchasesPaidCents, int $expensesPaidCents): array
    {
        $total = $salesSumCents - $refundsCents - $discountsCents;
        $net = $total - $purchasesPaidCents - $expensesPaidCents;

        return [
            'salesSum' => Money::decimal($salesSumCents),
            'refunds' => Money::decimal($refundsCents),
            'discounts' => Money::decimal($discountsCents),
            'salesTotal' => Money::decimal($total),
            'purchasesPaid' => Money::decimal($purchasesPaidCents),
            'expensesPaid' => Money::decimal($expensesPaidCents),
            'salesNet' => Money::decimal($net),
        ];
    }
}
