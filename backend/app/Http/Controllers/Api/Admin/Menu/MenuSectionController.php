<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\ReorderMenuSectionsRequest;
use App\Http\Requests\Admin\Menu\StoreMenuSectionRequest;
use App\Http\Requests\Admin\Menu\UpdateMenuSectionRequest;
use App\Http\Resources\Menu\MenuSectionResource;
use App\Services\Menu\MenuCompositionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuSectionController extends Controller
{
    public function __construct(private readonly MenuCompositionService $menus) {}

    public function index(Request $request, int $menu): JsonResponse
    {
        return response()->json(['data' => MenuSectionResource::collection($this->menus->sections($this->menus->menu(TenantContext::id($request), $menu)))->resolve($request)]);
    }

    public function store(StoreMenuSectionRequest $request, int $menu): JsonResponse
    {
        $section = $this->menus->createSection($this->menus->menu(TenantContext::id($request), $menu), $request->validated());

        return response()->json(['data' => (new MenuSectionResource($section))->resolve($request)], 201);
    }

    public function update(UpdateMenuSectionRequest $request, int $section): JsonResponse
    {
        $model = $this->menus->updateSection($this->menus->section(TenantContext::id($request), $section), $request->validated());

        return response()->json(['data' => (new MenuSectionResource($model))->resolve($request)]);
    }

    public function archive(Request $request, int $section): JsonResponse
    {
        $model = $this->menus->archiveSection($this->menus->section(TenantContext::id($request), $section));

        return response()->json(['message' => 'Menu section archived successfully.', 'data' => (new MenuSectionResource($model))->resolve($request)]);
    }

    public function restore(Request $request, int $section): JsonResponse
    {
        $model = $this->menus->restoreSection($this->menus->section(TenantContext::id($request), $section, true));

        return response()->json(['message' => 'Menu section restored successfully.', 'data' => (new MenuSectionResource($model))->resolve($request)]);
    }

    public function reorder(ReorderMenuSectionsRequest $request, int $menu): JsonResponse
    {
        $this->menus->reorderSections($this->menus->menu(TenantContext::id($request), $menu), $request->validated('items'));

        return response()->json(['message' => 'Menu sections reordered successfully.']);
    }
}
