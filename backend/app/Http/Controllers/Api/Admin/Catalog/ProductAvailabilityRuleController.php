<?php

namespace App\Http\Controllers\Api\Admin\Catalog;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Catalog\PreviewProductAvailabilityRequest;
use App\Http\Requests\Admin\Catalog\SyncProductAvailabilityRulesRequest;
use App\Http\Resources\Catalog\ProductAvailabilityPreviewResource;
use App\Http\Resources\Catalog\ProductAvailabilityRuleResource;
use App\Services\Catalog\ProductAvailabilityResolver;
use App\Services\Catalog\ProductAvailabilityRuleService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductAvailabilityRuleController extends Controller
{
    public function __construct(private readonly ProductAvailabilityRuleService $rules, private readonly ProductAvailabilityResolver $resolver) {}

    public function index(Request $request, int $product): JsonResponse
    {
        $model = $this->rules->product(TenantContext::id($request), $product);

        return response()->json(['data' => [
            'productId' => $model->id,
            'rules' => ProductAvailabilityRuleResource::collection($this->rules->rules($model))->resolve($request),
        ]]);
    }

    public function sync(SyncProductAvailabilityRulesRequest $request, int $product): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $model = $this->rules->product($tenantId, $product);
        $rules = $this->rules->sync($tenantId, $model->id, $request->validated('rules'));

        return response()->json(['data' => [
            'productId' => $model->id,
            'rules' => ProductAvailabilityRuleResource::collection($rules)->resolve($request),
        ]]);
    }

    public function preview(PreviewProductAvailabilityRequest $request, int $product): JsonResponse
    {
        $data = $request->validated();

        return response()->json(['data' => (new ProductAvailabilityPreviewResource($this->resolver->resolve(
            TenantContext::id($request),
            $product,
            $data['productVariantId'] ?? null,
            $data['branchId'] ?? null,
            $data['channel'] ?? null,
            $data['dateTime'],
            $data['timezone'] ?? config('app.timezone'),
        )))->resolve($request)]);
    }
}
