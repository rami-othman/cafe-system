<?php

namespace App\Services\FixedAssets;

use App\Support\Money;
use Carbon\CarbonImmutable;

/**
 * Straight-line or declining-balance, daily pro-rata.
 *
 * Declining balance (double-declining: annual rate = 2 / life in years, at most 90%) is applied to the
 * current book value in its closed form, book × (1 − (1 − r)^(days/365)), so the total does not depend on how
 * the periods are sliced into runs. It never goes below salvage, and whatever is left above salvage is taken in
 * the last period of the (possibly extended) life. Straight-line, daily pro-rata: The depreciable amount still open (cost − salvage − accumulated)
 * is spread evenly over the days left until the end of the (possibly extended) useful life, so an
 * addition or a change of estimate is absorbed prospectively without restating the past.
 */
final class DepreciationCalculator
{
    public const METHODS = ['straight_line', 'declining_balance', 'none'];

    /** Methods that produce depreciation entries. */
    public const DEPRECIATING = ['straight_line', 'declining_balance'];

    public static function depreciates(?string $method): bool
    {
        return in_array($method ?? 'straight_line', self::DEPRECIATING, true);
    }

    /**
     * @param  array{cost:int, accumulated:int, lifeChange:int}  $book
     * @return array{from:string, to:string, days:int, amount:int, remainingBefore:int, fullyDepreciated:bool}|null
     */
    public function forPeriod(object $asset, array $book, string $to): ?array
    {
        if (! self::depreciates($asset->method ?? 'straight_line')) {
            return null;
        }
        $life = (int) $asset->useful_life_months + (int) $book['lifeChange'];
        if ($life <= 0) {
            return null;
        }
        $start = CarbonImmutable::parse($asset->depreciation_start_date)->startOfDay();
        $from = $asset->depreciated_until ? CarbonImmutable::parse($asset->depreciated_until)->addDay()->startOfDay() : $start;
        if ($from->lt($start)) {
            $from = $start;
        }
        $until = CarbonImmutable::parse($to)->startOfDay();
        if ($from->gt($until)) {
            return null;
        }
        $remaining = $book['cost'] - Money::cents((string) $asset->salvage_value) - $book['accumulated'];
        if ($remaining <= 0) {
            return null;
        }
        $end = $start->addMonthsNoOverflow($life)->subDay();

        if ($until->gte($end) || $from->gt($end)) {
            $amount = $remaining;
            $days = $from->gt($end) ? $from->diffInDays($until) + 1 : $from->diffInDays($end) + 1;
        } elseif (($asset->method ?? 'straight_line') === 'declining_balance') {
            $days = (int) $from->diffInDays($until) + 1;
            $rate = min(0.9, 24 / $life);
            $bookValue = $book['cost'] - $book['accumulated'];
            $amount = min($remaining, (int) round($bookValue * (1 - (1 - $rate) ** ($days / 365))));
        } else {
            $days = (int) $from->diffInDays($until) + 1;
            $daysLeft = (int) $from->diffInDays($end) + 1;
            $amount = (int) round($remaining * $days / $daysLeft);
        }
        if ($amount <= 0) {
            return null;
        }

        return [
            'from' => $from->toDateString(),
            'to' => $until->toDateString(),
            'days' => (int) $days,
            'amount' => $amount,
            'remainingBefore' => $remaining,
            'fullyDepreciated' => $amount >= $remaining,
        ];
    }

    /**
     * Month-by-month projection from the asset's current position until fully depreciated.
     *
     * @return array<int, array{periodEnd:string, amount:int, accumulated:int, bookValue:int}>
     */
    public function schedule(object $asset, array $book, int $maxMonths = 600): array
    {
        $rows = [];
        if (! self::depreciates($asset->method ?? 'straight_line') || (int) $asset->useful_life_months + (int) $book['lifeChange'] <= 0) {
            return $rows;
        }
        $state = clone $asset;
        $accumulated = $book['accumulated'];
        $cursor = CarbonImmutable::parse($state->depreciated_until ?? CarbonImmutable::parse($state->depreciation_start_date)->subDay()->toDateString())->addDay();
        for ($i = 0; $i < $maxMonths; $i++) {
            $periodEnd = $cursor->endOfMonth()->toDateString();
            $result = $this->forPeriod($state, ['cost' => $book['cost'], 'accumulated' => $accumulated, 'lifeChange' => $book['lifeChange']], $periodEnd);
            if ($result === null) {
                if ($accumulated >= $book['cost'] - Money::cents((string) $asset->salvage_value)) {
                    break;
                }
                $state->depreciated_until = $periodEnd;
                $cursor = CarbonImmutable::parse($periodEnd)->addDay();

                continue;
            }
            $accumulated += $result['amount'];
            $rows[] = ['periodEnd' => $periodEnd, 'amount' => $result['amount'], 'accumulated' => $accumulated, 'bookValue' => $book['cost'] - $accumulated];
            $state->depreciated_until = $periodEnd;
            $cursor = CarbonImmutable::parse($periodEnd)->addDay();
            if ($result['fullyDepreciated']) {
                break;
            }
        }

        return $rows;
    }
}
