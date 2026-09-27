<?php

namespace App\Http\Controllers\Api\Manufacturing;

use App\Domain\Manufacturing\ManufacturingDomainException;
use App\Domain\Manufacturing\ManufacturingProductionService;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Manufacturing\ProductionCompleteRequest;
use App\Http\Requests\Api\V1\Manufacturing\ProductionDraftRequest;
use App\Http\Requests\Api\V1\Manufacturing\ReverseProductionRequest;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ManufacturingProductionController extends Controller
{
    public function __construct(private readonly ManufacturingProductionService $production) {}

    public function preview(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validate(['recipeId' => ['required', 'integer'], 'qty' => ['required'], 'warehouseId' => ['nullable', 'integer'], 'branchId' => ['nullable', 'integer']]);
        if (! empty($data['warehouseId'])) {
            $branchId = \Illuminate\Support\Facades\DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $data['warehouseId'])->value('branch_id');
            FinancialActor::assertBranchAccess(FinancialActor::id($request, $tenantId), $tenantId, $branchId ? (int) $branchId : null);
        }

        return response()->json(['data' => $this->production->preview($tenantId, $data)]);
    }

    public function storeDraft(ProductionDraftRequest $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $draft = $this->production->createDraft($request, $tenantId, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $draft], 201);
    }

    public function showDraft(Request $request, int $draft): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        \App\Support\ManufacturingRecordScope::find($request, $tenantId, 'manufacturing_orders', $draft);
        $data = $this->production->getDraft($tenantId, $draft);
        if (! $data) {
            throw ManufacturingDomainException::draftNotFound();
        }

        return response()->json(['data' => $data]);
    }

    public function complete(ProductionCompleteRequest $request, int $draft): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        \App\Support\ManufacturingRecordScope::find($request, $tenantId, 'manufacturing_orders', $draft);
        $record = $this->production->complete($request, $tenantId, $draft, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $record]);
    }

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        if ($request->filled('branchId')) {
            FinancialActor::assertBranchAccess(FinancialActor::id($request, $tenantId), $tenantId, (int) $request->input('branchId'));
        }
        return response()->json(['data' => $this->production->list($tenantId, $request->only(['search', 'warehouseId', 'branchId', 'status', 'type']) + ['accessibleBranchIds' => FinancialActor::operationalBranchIds(FinancialActor::id($request, $tenantId), $tenantId)])]);
    }

    public function show(Request $request, string $production): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        \App\Support\ManufacturingRecordScope::find($request, $tenantId, 'manufacturing_orders', $production);
        $data = $this->production->get($tenantId, is_numeric($production) ? (int) $production : $production);
        if (! $data) {
            throw ManufacturingDomainException::draftNotFound();
        }

        return response()->json(['data' => $data]);
    }

    public function reverse(ReverseProductionRequest $request, string $production): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        \App\Support\ManufacturingRecordScope::find($request, $tenantId, 'manufacturing_orders', $production);
        $recordId = $this->resolveOrderId($tenantId, $production);
        $record = $this->production->reverse($request, $tenantId, $recordId, $request->validated()['reason'], FinancialActor::id($request, $tenantId), $request->validated()['idempotencyKey'] ?? null);

        return response()->json(['data' => $record]);
    }

    private function resolveOrderId(int $tenantId, string $production): int
    {
        if (is_numeric($production)) {
            return (int) $production;
        }
        $data = $this->production->get($tenantId, $production);
        if (! $data) {
            throw ManufacturingDomainException::draftNotFound();
        }

        return (int) $data['recordId'];
    }
}
