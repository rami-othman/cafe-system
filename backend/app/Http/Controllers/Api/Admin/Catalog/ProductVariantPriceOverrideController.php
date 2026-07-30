<?php

namespace App\Http\Controllers\Api\Admin\Catalog;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Catalog\ResolveEffectiveVariantPriceRequest;
use App\Http\Requests\Admin\Catalog\SyncProductVariantPriceOverridesRequest;
use App\Http\Resources\Catalog\EffectiveProductVariantPriceResource;
use App\Http\Resources\Catalog\ProductVariantPriceOverrideResource;
use App\Services\Catalog\ProductVariantPriceOverrideService;
use App\Services\Catalog\ProductVariantPriceResolver;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductVariantPriceOverrideController extends Controller
{
    public function __construct(private readonly ProductVariantPriceOverrideService $overrides, private readonly ProductVariantPriceResolver $resolver) {}

    public function index(Request $request, int $variant): JsonResponse
    {
        $model = $this->overrides->variant(TenantContext::id($request), $variant);

        return response()->json(['data' => [
            'variantId' => $model->id,
            'basePrice' => (float) $model->base_price,
            'overrides' => ProductVariantPriceOverrideResource::collection($this->overrides->overrides($model))->resolve($request),
        ]]);
    }

    public function sync(SyncProductVariantPriceOverridesRequest $request, int $variant): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $model = $this->overrides->variant($tenantId, $variant);
        $items = $this->overrides->sync($tenantId, $model->id, $request->validated('overrides'));

        return response()->json(['data' => [
            'variantId' => $model->id,
            'basePrice' => (float) $model->base_price,
            'overrides' => ProductVariantPriceOverrideResource::collection($items)->resolve($request),
        ]]);
    }

    public function effectivePrice(ResolveEffectiveVariantPriceRequest $request, int $variant): JsonResponse
    {
        $data = $request->validated();

        return response()->json(['data' => (new EffectiveProductVariantPriceResource($this->resolver->resolve(
            TenantContext::id($request),
            $variant,
            $data['branchId'] ?? null,
            $data['channel'] ?? null,
        )))->resolve($request)]);
    }
}
