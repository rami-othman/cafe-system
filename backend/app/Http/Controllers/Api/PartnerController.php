<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Partners\PartnerService;
use App\Services\Partners\OverheadAllocationService;
use App\Services\Partners\ProfitDistributionService;
use App\Support\FinanceAccess;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Partners / investors, branch ownership, partner money movements and profit distribution (finance/partners/*). */
class PartnerController extends Controller
{
    public function __construct(private readonly PartnerService $partners, private readonly ProfitDistributionService $distributions, private readonly OverheadAllocationService $overhead) {}

    public function index(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->partners->list(TenantContext::id($request))]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['name' => ['required', 'string', 'max:255'], 'kind' => ['nullable', 'in:company,investor'], 'phone' => ['nullable', 'string', 'max:60'],
            'notes' => ['nullable', 'string', 'max:2000'], 'capitalAccountId' => ['nullable', 'integer'], 'currentAccountId' => ['nullable', 'integer'], 'drawingsAccountId' => ['nullable', 'integer'], 'userId' => ['nullable', 'integer']]);
        $this->partners->save($request, $tenant, $data, null, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->partners->list($tenant)], 201);
    }

    public function update(Request $request, int $partner): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['name' => ['required', 'string', 'max:255'], 'phone' => ['nullable', 'string', 'max:60'], 'notes' => ['nullable', 'string', 'max:2000'], 'isActive' => ['nullable', 'boolean'], 'userId' => ['nullable', 'integer']]);
        $this->partners->save($request, $tenant, $data, $partner, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->partners->list($tenant)]);
    }

    public function linkableUsers(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->partners->linkableUsers(TenantContext::id($request))]);
    }

    /** Investor portal: only the partner(s) linked to the signed-in user. */
    public function portal(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $filters = $request->validate(['dateFrom' => ['nullable', 'date_format:Y-m-d'], 'dateTo' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:dateFrom']]);
        $user = FinanceAccess::actor($request);

        return response()->json(['data' => $this->partners->portal($tenant, (int) $user->id, $filters['dateFrom'] ?? now()->startOfYear()->toDateString(), $filters['dateTo'] ?? now()->toDateString())]);
    }

    public function ownership(Request $request, int $branch): JsonResponse
    {
        return response()->json(['data' => $this->partners->ownership(TenantContext::id($request), $branch)]);
    }

    public function setOwnership(Request $request, int $branch): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate([
            'effectiveFrom' => ['required', 'date_format:Y-m-d'], 'shares' => ['required', 'array', 'min:1'],
            'shares.*.partnerId' => ['required', 'integer'], 'shares.*.sharePercent' => ['required', 'numeric', 'gt:0', 'max:100'],
            'settings' => ['nullable', 'array'], 'settings.managementFeeType' => ['nullable', 'in:none,revenue_percent,profit_percent'],
            'settings.managementFeePercent' => ['nullable', 'numeric', 'min:0', 'max:100'], 'settings.managementFeePartnerId' => ['nullable', 'integer'],
            'settings.carryForwardLosses' => ['nullable', 'boolean'],
        ]);
        $this->partners->setOwnership($request, $tenant, $branch, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->partners->ownership($tenant, $branch)]);
    }

    public function saveSettings(Request $request, int $branch): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['managementFeeType' => ['required', 'in:none,revenue_percent,profit_percent'], 'managementFeePercent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'managementFeePartnerId' => ['nullable', 'integer'], 'carryForwardLosses' => ['nullable', 'boolean']]);
        $this->partners->ownership($tenant, $branch);
        $this->partners->saveSettings($tenant, $branch, $data);

        return response()->json(['data' => $this->partners->ownership($tenant, $branch)]);
    }

    public function transactions(Request $request): JsonResponse
    {
        $data = $request->validate(['partnerId' => ['nullable', 'integer']]);

        return response()->json(['data' => $this->partners->transactions(TenantContext::id($request), isset($data['partnerId']) ? (int) $data['partnerId'] : null)]);
    }

    public function storeTransaction(Request $request, int $partner): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['type' => ['required', 'in:capital_in,capital_out,withdrawal,payout,deposit'], 'date' => ['required', 'date_format:Y-m-d'],
            'amount' => ['required', 'numeric', 'gt:0'], 'counterAccountId' => ['required', 'integer'], 'branchId' => ['nullable', 'integer'], 'description' => ['nullable', 'string', 'max:500']]);
        $this->partners->transaction($request, $tenant, $partner, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->partners->transactions($tenant, $partner)], 201);
    }

    public function reverseTransaction(Request $request, int $transaction): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->partners->reverseTransaction($request, $tenant, $transaction, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->partners->transactions($tenant)]);
    }

    public function statement(Request $request, int $partner): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $filters = $request->validate(['dateFrom' => ['required', 'date_format:Y-m-d'], 'dateTo' => ['required', 'date_format:Y-m-d', 'after_or_equal:dateFrom'], 'branchId' => ['nullable', 'string']]);

        return response()->json(['data' => $this->partners->statement($tenant, $partner, $filters)]);
    }

    public function overview(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $filters = $request->validate(['dateFrom' => ['required', 'date_format:Y-m-d'], 'dateTo' => ['required', 'date_format:Y-m-d', 'after_or_equal:dateFrom']]);

        return response()->json(['data' => $this->distributions->branchesOverview($tenant, (int) FinancialActor::id($request, $tenant), $filters['dateFrom'], $filters['dateTo'])]);
    }

    public function distributions(Request $request): JsonResponse
    {
        $data = $request->validate(['branchId' => ['nullable', 'integer']]);

        return response()->json(['data' => $this->distributions->list(TenantContext::id($request), isset($data['branchId']) ? (int) $data['branchId'] : null)]);
    }

    public function showDistribution(Request $request, int $distribution): JsonResponse
    {
        return response()->json(['data' => $this->distributions->show(TenantContext::id($request), $distribution)]);
    }

    public function previewDistribution(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->distributionData($request);
        $preview = $this->distributions->preview($tenant, (int) FinancialActor::id($request, $tenant), (int) $data['branchId'], $data['periodFrom'], $data['periodTo']);
        unset($preview['linesCents']);

        return response()->json(['data' => $preview]);
    }

    public function storeDistribution(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->distributionData($request);
        $id = $this->distributions->post($request, $tenant, (int) FinancialActor::id($request, $tenant), (int) $data['branchId'], $data);

        return response()->json(['data' => $this->distributions->show($tenant, $id)], 201);
    }

    public function reverseDistribution(Request $request, int $distribution): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->distributions->reverse($request, $tenant, $distribution, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->distributions->show($tenant, $distribution)]);
    }

    private function distributionData(Request $request): array
    {
        return $request->validate(['branchId' => ['required', 'integer'], 'periodFrom' => ['required', 'date_format:Y-m-d'], 'periodTo' => ['required', 'date_format:Y-m-d', 'after_or_equal:periodFrom'], 'notes' => ['nullable', 'string', 'max:2000']]);
    }

    public function overheadList(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->overhead->list(TenantContext::id($request))]);
    }

    public function overheadShow(Request $request, int $allocation): JsonResponse
    {
        return response()->json(['data' => $this->overhead->show(TenantContext::id($request), $allocation)]);
    }

    public function overheadPreview(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->overheadData($request);
        $preview = $this->overhead->preview($tenant, (int) FinancialActor::id($request, $tenant), $data['periodFrom'], $data['periodTo'], $data);
        unset($preview['matrix'], $preview['totalCents']);

        return response()->json(['data' => $preview]);
    }

    public function overheadStore(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->overheadData($request);
        $id = $this->overhead->post($request, $tenant, (int) FinancialActor::id($request, $tenant), $data);

        return response()->json(['data' => $this->overhead->show($tenant, $id)], 201);
    }

    public function overheadReverse(Request $request, int $allocation): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->overhead->reverse($request, $tenant, $allocation, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->overhead->show($tenant, $allocation)]);
    }

    private function overheadData(Request $request): array
    {
        return $request->validate([
            'periodFrom' => ['required', 'date_format:Y-m-d'], 'periodTo' => ['required', 'date_format:Y-m-d', 'after_or_equal:periodFrom'],
            'basis' => ['nullable', 'in:revenue,equal,manual'], 'branchIds' => ['nullable', 'array'], 'branchIds.*' => ['integer'],
            'percents' => ['nullable', 'array'], 'percents.*' => ['numeric', 'min:0', 'max:100'],
            'accountIds' => ['nullable', 'array'], 'accountIds.*' => ['integer'], 'notes' => ['nullable', 'string', 'max:2000'],
        ]);
    }
}
