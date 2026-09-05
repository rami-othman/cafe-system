<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\InventoryItemUnitConversionRequest;
use App\Services\InventoryItemUnitConversionService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InventoryItemUnitConversionController extends Controller
{
    public function __construct(private readonly InventoryItemUnitConversionService $conversions) {}

    public function index(Request $request, int $item): JsonResponse
    {
        return response()->json([
            'data' => $this->conversions->index(TenantContext::id($request), $item),
        ]);
    }

    public function store(InventoryItemUnitConversionRequest $request, int $item): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        return response()->json([
            'data' => $this->conversions->save($request, $tenantId, $item, $request->validated(), FinancialActor::id($request, $tenantId)),
        ], 201);
    }

    public function update(InventoryItemUnitConversionRequest $request, int $item, int $conversion): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        return response()->json([
            'data' => $this->conversions->save($request, $tenantId, $item, $request->validated(), FinancialActor::id($request, $tenantId), $conversion),
        ]);
    }
}
