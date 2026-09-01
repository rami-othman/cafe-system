<?php

namespace App\Services;

use App\Support\FinancialActor;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Resolves the one shared filter context every Dashboard/Trends/Branches
 * endpoint must agree on: tenant, the actor's authorized branches, the
 * requested branch scope, the business-date range, and the comparison
 * window. Every query service downstream is handed this same context so no
 * component can drift onto a different date range or leak unauthorized
 * branches through an omitted branch filter.
 */
final class FinanceDashboardContext
{
    public function __construct(private readonly FinanceComparisonPeriodResolver $comparison) {}

    /** @param array{dateFrom?: ?string, dateTo?: ?string, branchId?: ?int, comparison?: ?string} $filters */
    public function resolve(int $tenantId, int $actorId, array $filters): array
    {
        $authorized = $this->authorizedBranches($tenantId, $actorId);
        abort_if($authorized->isEmpty(), 404, 'No branches are available for this user.');

        $branchId = $filters['branchId'] ?? null;
        if ($branchId !== null) {
            FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId);
            if (! $authorized->contains('id', $branchId)) {
                throw ValidationException::withMessages(['branchId' => 'The selected branch is not available to this user.']);
            }
        }

        $authorizedBranchIds = $authorized->pluck('id')->map(fn ($id) => (int) $id)->all();
        // If no branch filter is supplied, the scope is every branch the
        // actor is authorized for — never the whole tenant regardless of
        // authorization, and a manager can never widen this by omission.
        $scopeBranchIds = $branchId !== null ? [$branchId] : $authorizedBranchIds;

        $dateTo = $filters['dateTo'] ?? now()->toDateString();
        $dateFrom = $filters['dateFrom'] ?? now()->subDays(29)->toDateString();
        $period = $this->comparison->resolve($dateFrom, $dateTo, $filters['comparison'] ?? 'previous_period');

        $timezoneBranchId = $branchId ?? ($authorizedBranchIds[0] ?? null);
        $timezone = $timezoneBranchId ? DB::table('branches')->where('id', $timezoneBranchId)->value('timezone') : null;
        $timezone = $timezone ?: (DB::table('tenants')->where('id', $tenantId)->value('timezone') ?: 'UTC');

        $selectedBranch = $branchId !== null ? $authorized->firstWhere('id', $branchId) : null;
        $currency = (string) ($selectedBranch->currency ?? $authorized->first()->currency ?? 'SYP');

        return [
            'tenantId' => $tenantId,
            'actorId' => $actorId,
            'branchId' => $branchId,
            'authorizedBranchIds' => $authorizedBranchIds,
            'authorizedBranches' => $authorized->map(fn (object $b) => ['id' => (int) $b->id, 'name' => $b->name])->values()->all(),
            'scopeBranchIds' => $scopeBranchIds,
            'timezone' => $timezone,
            'currency' => $currency,
            'dateFrom' => $period['current']['from'],
            'dateTo' => $period['current']['to'],
            'comparisonMode' => $filters['comparison'] ?? 'previous_period',
            'comparisonFrom' => $period['comparison']['from'] ?? null,
            'comparisonTo' => $period['comparison']['to'] ?? null,
        ];
    }

    private function authorizedBranches(int $tenantId, int $actorId): Collection
    {
        $query = DB::table('branches')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at');
        $role = DB::table('users')->where('tenant_id', $tenantId)->where('id', $actorId)->value('role');
        if ($role !== 'owner') {
            $query->whereIn('id', DB::table('user_branches')->where('tenant_id', $tenantId)->where('user_id', $actorId)->select('branch_id'));
        }

        return $query->orderBy('name')->get(['id', 'name', 'currency', 'timezone']);
    }
}
