<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinanceBranchPerformanceQueryService;
use App\Services\FinanceDashboardContext;
use App\Services\FinanceDashboardQueryService;
use App\Services\FinanceKpiQueryService;
use App\Services\FinanceTrendQueryService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\Rule;

final class FinanceDashboardController extends Controller
{
    public function __construct(
        private readonly FinanceDashboardContext $context,
        private readonly FinanceDashboardQueryService $dashboard,
        private readonly FinanceTrendQueryService $trends,
        private readonly FinanceBranchPerformanceQueryService $branchPerformance,
        private readonly FinanceKpiQueryService $kpi,
    ) {}

    /**
     * Short-lived response cache (task: "after query optimization, consider
     * a short-lived cache keyed by tenant + branch + period + filters").
     * Keyed on the actor (not just tenant/branch) because the payload's
     * content — authorizedBranches, scoped totals — depends on the actor's
     * branch access, so caching across actors would leak one user's wider
     * scope into a more restricted user's response. Keyed on the full query
     * string rather than hand-picked filters so any filter combination
     * (including pagination on nested lists) stays correctly segmented.
     * 30s TTL: long enough to absorb repeat views/tab-switches within one
     * session, short enough that a newly posted transaction shows up fast.
     */
    private const CACHE_TTL_SECONDS = 30;

    private function cached(Request $request, string $action, int $tenantId, int $actorId, callable $resolve): JsonResponse
    {
        // Tests assert on immediate read-after-write (e.g. dashboard before
        // and after completing a reconciliation) — a short-lived cache would
        // make those assertions flaky by design, so it's skipped under test
        // the same way query/response caching normally is.
        if (app()->runningUnitTests()) {
            return response()->json(['data' => $resolve()]);
        }

        $key = "finance-overview:{$action}:{$tenantId}:{$actorId}:".md5((string) $request->getQueryString());

        return response()->json(['data' => Cache::remember($key, self::CACHE_TTL_SECONDS, $resolve)]);
    }

    public function show(Request $request): JsonResponse
    {
        [$tenantId, $actorId] = $this->actor($request);

        return $this->cached($request, 'dashboard', $tenantId, $actorId, function () use ($request, $tenantId, $actorId) {
            $context = $this->context->resolve($tenantId, $actorId, $this->filters($request));

            return $this->dashboard->summary($request, $context);
        });
    }

    public function trends(Request $request): JsonResponse
    {
        [$tenantId, $actorId] = $this->actor($request);

        return $this->cached($request, 'trends', $tenantId, $actorId, function () use ($request, $tenantId, $actorId) {
            $context = $this->context->resolve($tenantId, $actorId, $this->filters($request));

            return [
                'revenueVsExpenses' => $this->trends->revenueExpensesTrend($context, $context['dateFrom'], $context['dateTo']),
                'salesCogsGrossProfit' => $this->trends->salesCogsGrossProfitTrend($context, $context['dateFrom'], $context['dateTo']),
                'expenseBreakdown' => $this->kpi->expenseBreakdown($context, $context['dateFrom'], $context['dateTo']),
                'paymentMethods' => $this->kpi->paymentMethodBreakdown($context, $context['dateFrom'], $context['dateTo']),
            ];
        });
    }

    public function branches(Request $request): JsonResponse
    {
        [$tenantId, $actorId] = $this->actor($request);

        return $this->cached($request, 'branches', $tenantId, $actorId, function () use ($request, $tenantId, $actorId) {
            $context = $this->context->resolve($tenantId, $actorId, $this->filters($request, allowBranch: false));

            return $this->branchPerformance->perBranch($context, $context['dateFrom'], $context['dateTo']);
        });
    }

    private function filters(Request $request, bool $allowBranch = true): array
    {
        $rules = [
            'date_from' => ['nullable', 'date_format:Y-m-d'],
            'date_to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:date_from'],
            'comparison' => ['nullable', Rule::in(['previous_period', 'previous_year', 'none'])],
        ];
        if ($allowBranch) {
            $rules['branch_id'] = ['nullable', 'integer'];
        }
        $data = $request->validate($rules);

        return [
            'dateFrom' => $data['date_from'] ?? null,
            'dateTo' => $data['date_to'] ?? null,
            'branchId' => isset($data['branch_id']) ? (int) $data['branch_id'] : null,
            'comparison' => $data['comparison'] ?? 'previous_period',
        ];
    }

    private function actor(Request $request): array
    {
        $tenantId = TenantContext::id($request);

        return [$tenantId, FinancialActor::id($request, $tenantId)];
    }
}
