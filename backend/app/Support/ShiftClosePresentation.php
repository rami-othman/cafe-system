<?php

namespace App\Support;

/**
 * How a shift's close must be presented by every report/history/API surface.
 *
 * - manual:           physically counted; closing_cash, expected and
 *                     difference are real figures.
 * - automatic:        unattended expected close; no physical count exists
 *                     (closing_cash NULL). Expected cash is real, but there is
 *                     no counted difference to report.
 * - legacy_reconcile: administrative close of historical overlapping shifts
 *                     on one drawer. No per-shift count, expected figure,
 *                     difference or close transfer exists and none is shown.
 *
 * Only a counted (manual) close can ever be a "cash difference".
 */
final class ShiftClosePresentation
{
    public const MODES = ['manual', 'automatic', 'legacy_reconcile'];

    /** @return array{closeMode: ?string, cashCounted: bool, administrativeClose: bool, expectedCash: ?string, cashDifference: ?string, hasCountedDifference: bool} */
    public static function for(object $shift): array
    {
        $type = $shift->close_type ?? null;
        $closed = ($shift->status ?? null) === 'closed';
        // Pre-A2 closed rows have no close_type; they were counted manual closes.
        $mode = $closed ? ($type ?: 'manual') : null;
        $counted = $mode === 'manual' && $shift->closing_cash !== null;
        $expected = $mode === 'legacy_reconcile' ? null : self::decimal($shift->expected_cash ?? null);
        $difference = ($mode === null || $counted) ? self::decimal($shift->cash_difference ?? null) : null;

        return [
            'closeMode' => $mode,
            'cashCounted' => $counted,
            'administrativeClose' => $mode === 'legacy_reconcile',
            'expectedCash' => $expected,
            'cashDifference' => $difference,
            'hasCountedDifference' => $counted && $difference !== null && Money::cents($difference) !== 0,
        ];
    }

    private static function decimal(mixed $value): ?string
    {
        return $value === null ? null : Money::decimal(Money::cents((string) $value));
    }
}
