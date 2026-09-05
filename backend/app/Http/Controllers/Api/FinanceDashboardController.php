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

    public function show(Request $request): JsonResponse
    {
        [$tenantId, $actorId] = $this->actor($request);
        $context = $this->context->resolve($tenantId, $actorId, $this->filters($request));

        return response()->json(['data' => $this->dashboard->summary($request, $context)]);
    }

    public function trends(Request $request): JsonResponse
    {
        [$tenantId, $actorId] = $this->actor($request);
        $context = $this->context->resolve($tenantId, $actorId, $this->filters($request));

        return response()->json(['data' => [
            'revenueVsExpenses' => $this->trends->revenueExpensesTrend($context, $context['dateFrom'], $context['dateTo']),
            'salesCogsGrossProfit' => $this->trends->salesCogsGrossProfitTrend($context, $context['dateFrom'], $context['dateTo']),
            'expenseBreakdown' => $this->kpi->expenseBreakdown($context, $context['dateFrom'], $context['dateTo']),
            'paymentMethods' => $this->kpi->paymentMethodBreakdown($context, $context['dateFrom'], $context['dateTo']),
        ]]);
    }

    public function branches(Request $request): JsonResponse
    {
        [$tenantId, $actorId] = $this->actor($request);
        $context = $this->context->resolve($tenantId, $actorId, $this->filters($request, allowBranch: false));

        return response()->json(['data' => $this->branchPerformance->perBranch($context, $context['dateFrom'], $context['dateTo'])]);
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
