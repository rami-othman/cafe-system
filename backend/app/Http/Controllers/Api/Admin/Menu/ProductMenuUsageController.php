<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Resources\Menu\ProductMenuUsageResource;
use App\Models\Product;
use App\Services\Menu\MenuCompositionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductMenuUsageController extends Controller
{
    public function __construct(private readonly MenuCompositionService $menus) {}

    public function show(Request $request, int $product): JsonResponse
    {
        $model = Product::withTrashed()->where('tenant_id', TenantContext::id($request))->findOrFail($product);

        return response()->json(['data' => (new ProductMenuUsageResource($this->menus->usage($model, $request->boolean('includeArchived'))))->resolve($request)]);
    }
}
