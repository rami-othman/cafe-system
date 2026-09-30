<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\ApplyMenuPriceAdjustmentRequest;
use App\Http\Requests\Admin\Menu\MenuPricingOverviewRequest;
use App\Http\Requests\Admin\Menu\PreviewMenuPriceAdjustmentRequest;
use App\Http\Requests\Admin\Menu\ShowMenuPriceAdjustmentRequest;
use App\Services\Menu\MenuPriceAdjustmentService;
use App\Services\Menu\MenuPricingQueryService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;

class MenuPricingController extends Controller
{
    public function __construct(private readonly MenuPricingQueryService $query, private readonly MenuPriceAdjustmentService $adjustments) {}

    public function overview(MenuPricingOverviewRequest $request, int $menu): JsonResponse { return response()->json(['data' => $this->query->overview(TenantContext::id($request), $menu, $request->validated())]); }
    public function preview(PreviewMenuPriceAdjustmentRequest $request, int $menu): JsonResponse { $actor = $request->attributes->get('auth_user'); return response()->json(['data' => $this->adjustments->preview(TenantContext::id($request), (int) $actor->id, $menu, $request->validated())], 201); }
    public function show(ShowMenuPriceAdjustmentRequest $request, int $menu, int $adjustment): JsonResponse { $actor = $request->attributes->get('auth_user'); return response()->json(['data' => $this->adjustments->show(TenantContext::id($request), (int) $actor->id, $menu, $adjustment)]); }
    public function apply(ApplyMenuPriceAdjustmentRequest $request, int $menu, int $adjustment): JsonResponse { $actor = $request->attributes->get('auth_user'); return response()->json(['data' => $this->adjustments->apply(TenantContext::id($request), (int) $actor->id, $menu, $adjustment, $request->validated())]); }
}
