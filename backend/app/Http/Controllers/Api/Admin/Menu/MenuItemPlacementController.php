<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\MoveMenuPlacementRequest;
use App\Http\Requests\Admin\Menu\ReorderMenuPlacementsRequest;
use App\Http\Requests\Admin\Menu\StoreMenuPlacementRequest;
use App\Http\Requests\Admin\Menu\SyncMenuPlacementsRequest;
use App\Http\Requests\Admin\Menu\UpdateMenuPlacementRequest;
use App\Http\Resources\Menu\MenuItemPlacementResource;
use App\Services\Menu\MenuCompositionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class MenuItemPlacementController extends Controller
{
    public function __construct(private readonly MenuCompositionService $menus) {}

    public function index(Request $request, int $section): JsonResponse
    {
        $request->validate(['includeArchived' => ['nullable', Rule::in(['true', 'false', '1', '0', true, false, 1, 0])]]);

        return response()->json(['data' => MenuItemPlacementResource::collection($this->menus->placements($this->menus->section(TenantContext::id($request), $section, true), $request->boolean('includeArchived')))->resolve($request)]);
    }

    public function store(StoreMenuPlacementRequest $request, int $section): JsonResponse
    {
        $placement = $this->menus->createPlacement($this->menus->section(TenantContext::id($request), $section, true), $request->validated());

        return response()->json(['data' => (new MenuItemPlacementResource($placement))->resolve($request)], 201);
    }

    public function update(UpdateMenuPlacementRequest $request, int $placement): JsonResponse
    {
        $model = $this->menus->updatePlacement($this->menus->placement(TenantContext::id($request), $placement), $request->validated());

        return response()->json(['data' => (new MenuItemPlacementResource($model))->resolve($request)]);
    }

    public function archive(Request $request, int $placement): JsonResponse
    {
        $model = $this->menus->archivePlacement($this->menus->placement(TenantContext::id($request), $placement));

        return response()->json(['message' => 'Menu placement archived successfully.', 'data' => (new MenuItemPlacementResource($model))->resolve($request)]);
    }

    public function restore(Request $request, int $placement): JsonResponse
    {
        $model = $this->menus->restorePlacement($this->menus->placement(TenantContext::id($request), $placement, true));

        return response()->json(['message' => 'Menu placement restored successfully.', 'data' => (new MenuItemPlacementResource($model))->resolve($request)]);
    }

    public function reorder(ReorderMenuPlacementsRequest $request, int $section): JsonResponse
    {
        $this->menus->reorderPlacements($this->menus->section(TenantContext::id($request), $section, true), $request->validated('items'));

        return response()->json(['message' => 'Menu placements reordered successfully.']);
    }

    public function move(MoveMenuPlacementRequest $request, int $placement): JsonResponse
    {
        $data = $request->validated();
        $model = $this->menus->movePlacement($this->menus->placement(TenantContext::id($request), $placement), $data['targetSectionId'], $data['sortOrder'] ?? null);

        return response()->json(['data' => (new MenuItemPlacementResource($model))->resolve($request)]);
    }

    public function sync(SyncMenuPlacementsRequest $request, int $section): JsonResponse
    {
        $items = $this->menus->syncPlacements($this->menus->section(TenantContext::id($request), $section, true), $request->validated('placements'));

        return response()->json(['data' => MenuItemPlacementResource::collection($items)->resolve($request)]);
    }
}
