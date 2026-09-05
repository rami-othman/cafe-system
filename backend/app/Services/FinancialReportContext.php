<?php

namespace App\Services;

/** Keeps every formal report on the established Finance branch/date scope. */
final class FinancialReportContext
{
    public function __construct(private readonly FinanceDashboardContext $finance) {}

    public function resolve(int $tenantId, int $actorId, array $filters): array
    {
        return $this->finance->resolve($tenantId, $actorId, [
            'branchId' => $filters['branchId'] ?? null,
            'dateFrom' => $filters['dateFrom'] ?? ($filters['asOfDate'] ?? now()->toDateString()),
            'dateTo' => $filters['dateTo'] ?? ($filters['asOfDate'] ?? now()->toDateString()),
            'comparison' => $filters['comparison'] ?? 'previous_period',
        ]);
    }
}
