<?php

namespace App\Http\Controllers\Api\Admin\Catalog;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Catalog\ClearOperationalAvailabilityRequest;
use App\Http\Requests\Admin\Catalog\ListOperationalAvailabilityRequest;
use App\Http\Requests\Admin\Catalog\PreviewOperationalAvailabilityRequest;
use App\Http\Requests\Admin\Catalog\UpdateProductOperationalAvailabilityRequest;
use App\Http\Requests\Admin\Catalog\UpdateVariantOperationalAvailabilityRequest;
use App\Http\Resources\Catalog\OperationalAvailabilityPreviewResource;
use App\Http\Resources\Catalog\OperationalAvailabilityResource;
use App\Services\Catalog\OperationalAvailabilityResolver;
use App\Services\Catalog\OperationalAvailabilityService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;

class OperationalAvailabilityController extends Controller
{
    public function __construct(private readonly OperationalAvailabilityService $availability, private readonly OperationalAvailabilityResolver $resolver) {}

    public function index(ListOperationalAvailabilityRequest $request): JsonResponse
    {
        $filters = $request->validated();
        $filters['includeArchived'] = $request->boolean('includeArchived');

        return OperationalAvailabilityResource::collection($this->availability->list(TenantContext::id($request), $filters))->response();
    }

    public function updateProduct(UpdateProductOperationalAvailabilityRequest $request, int $product): JsonResponse
    {
        $record = $this->availability->upsertProduct(TenantContext::id($request), $product, $request->validated());

        return response()->json(['data' => (new OperationalAvailabilityResource($record->load(['product', 'branch'])))->resolve($request)]);
    }

    public function clearProduct(ClearOperationalAvailabilityRequest $request, int $product): JsonResponse
    {
        $cleared = $this->availability->clearProduct(TenantContext::id($request), $product, $request->validated());

        return response()->json(['data' => ['cleared' => $cleared]]);
    }

    public function updateVariant(UpdateVariantOperationalAvailabilityRequest $request, int $variant): JsonResponse
    {
        $record = $this->availability->upsertVariant(TenantContext::id($request), $variant, $request->validated());

        return response()->json(['data' => (new OperationalAvailabilityResource($record->load(['productVariant.product', 'branch'])))->resolve($request)]);
    }

    public function clearVariant(ClearOperationalAvailabilityRequest $request, int $variant): JsonResponse
    {
        $cleared = $this->availability->clearVariant(TenantContext::id($request), $variant, $request->validated());

        return response()->json(['data' => ['cleared' => $cleared]]);
    }

    public function preview(PreviewOperationalAvailabilityRequest $request, int $product): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validated();
        $model = $this->availability->product($tenantId, $product);
        if (isset($data['productVariantId'])) {
            $variant = $this->availability->variant($tenantId, $data['productVariantId']);
            if ($variant->product_id !== $model->id) {
                abort(422, 'The selected variant does not belong to the product.');
            }
        }
        $branch = $this->availability->branch($tenantId, $data['branchId']);

        return response()->json(['data' => (new OperationalAvailabilityPreviewResource($this->resolver->resolve($tenantId, $model->id, $data['productVariantId'] ?? null, $branch->id, $data['channel'], $data['at'] ?? null, $branch->timezone ?: config('app.timezone'))))->resolve($request)]);
    }
}
