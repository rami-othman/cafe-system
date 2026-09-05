<?php

namespace App\Support;

/** Division helpers that never produce Infinity/NaN — used by every Finance ratio/comparison. */
final class SafeMath
{
    /** Percentage change from $previousCents to $currentCents, rounded to 2dp. Null when previous is zero (undefined, not Infinity). */
    public static function percentageChange(int $currentCents, int $previousCents): ?float
    {
        if ($previousCents === 0) {
            return null;
        }

        return round((($currentCents - $previousCents) / $previousCents) * 100, 2);
    }

    /** 'new' when previous was zero and current is not, 'unchanged' when both are zero, 'increase'/'decrease' otherwise. */
    public static function changeState(int $currentCents, int $previousCents): string
    {
        if ($previousCents === 0) {
            return $currentCents === 0 ? 'unchanged' : 'new';
        }

        if ($currentCents === $previousCents) {
            return 'unchanged';
        }

        return $currentCents > $previousCents ? 'increase' : 'decrease';
    }

    /** $numeratorCents / $denominatorCents as a percentage, rounded to 2dp. Null when the denominator is zero. */
    public static function ratioPercentage(int $numeratorCents, int $denominatorCents): ?float
    {
        if ($denominatorCents === 0) {
            return null;
        }

        return round(($numeratorCents / $denominatorCents) * 100, 2);
    }
}
