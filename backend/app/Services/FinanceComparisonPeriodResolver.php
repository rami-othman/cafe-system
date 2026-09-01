<?php

namespace App\Services;

use Carbon\CarbonImmutable;

/**
 * The single place that decides what "compare to" means for a Finance
 * Dashboard period. Every KPI/trend/branch query asks this once and reuses
 * the same comparison window rather than each computing its own offset.
 */
final class FinanceComparisonPeriodResolver
{
    /** @return array{current: array{from: string, to: string}, comparison: array{from: string, to: string}|null} */
    public function resolve(string $dateFrom, string $dateTo, string $mode): array
    {
        $from = CarbonImmutable::parse($dateFrom)->startOfDay();
        $to = CarbonImmutable::parse($dateTo)->startOfDay();
        $current = ['from' => $from->toDateString(), 'to' => $to->toDateString()];

        if ($mode === 'none') {
            return ['current' => $current, 'comparison' => null];
        }

        if ($mode === 'previous_year') {
            return ['current' => $current, 'comparison' => [
                'from' => $from->subYear()->toDateString(),
                'to' => $to->subYear()->toDateString(),
            ]];
        }

        // previous_period: the immediately preceding period of equal length (inclusive day count).
        $days = $from->diffInDays($to);
        $comparisonTo = $from->subDay();
        $comparisonFrom = $comparisonTo->subDays($days);

        return ['current' => $current, 'comparison' => [
            'from' => $comparisonFrom->toDateString(),
            'to' => $comparisonTo->toDateString(),
        ]];
    }
}
