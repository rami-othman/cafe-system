<?php

namespace App\Support;

/** Allocates an amount-based refund across an order's persisted tax snapshot. */
final class RefundTaxAllocation
{
    public static function taxCents(int $orderTotalCents, int $orderTaxCents, int $refundedBeforeCents, int $refundCents): int
    {
        if ($orderTotalCents <= 0 || $orderTaxCents <= 0 || $refundCents <= 0) {
            return 0;
        }

        return self::cumulativeTaxCents($orderTotalCents, $orderTaxCents, $refundedBeforeCents + $refundCents)
            - self::cumulativeTaxCents($orderTotalCents, $orderTaxCents, $refundedBeforeCents);
    }

    private static function cumulativeTaxCents(int $orderTotalCents, int $orderTaxCents, int $refundedCents): int
    {
        $refundedCents = min(max(0, $refundedCents), $orderTotalCents);

        return intdiv(($orderTaxCents * $refundedCents) + intdiv($orderTotalCents, 2), $orderTotalCents);
    }
}
