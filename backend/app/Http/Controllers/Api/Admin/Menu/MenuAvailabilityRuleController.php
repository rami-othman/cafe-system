<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\SyncMenuAvailabilityRulesRequest;
use App\Http\Resources\Menu\MenuAvailabilityRuleResource;
use App\Services\Menu\MenuCompositionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuAvailabilityRuleController extends Controller
{
    public function __construct(private readonly MenuCompositionService $menus) {}

    public function index(Request $request, int $menu): JsonResponse
    {
        return response()->json(['data' => MenuAvailabilityRuleResource::collection($this->menus->availabilityRules($this->menus->menu(TenantContext::id($request), $menu)))->resolve($request)]);
    }

    public function sync(SyncMenuAvailabilityRulesRequest $request, int $menu): JsonResponse
    {
        $items = $this->menus->syncAvailabilityRules($this->menus->menu(TenantContext::id($request), $menu), $request->validated('rules'));

        return response()->json(['data' => MenuAvailabilityRuleResource::collection($items)->resolve($request)]);
    }
}
