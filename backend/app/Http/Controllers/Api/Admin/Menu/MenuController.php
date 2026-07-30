<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\ListMenusRequest;
use App\Http\Requests\Admin\Menu\ReorderMenusRequest;
use App\Http\Requests\Admin\Menu\StoreMenuRequest;
use App\Http\Requests\Admin\Menu\UpdateMenuRequest;
use App\Http\Resources\Menu\MenuDetailResource;
use App\Http\Resources\Menu\MenuSummaryResource;
use App\Services\Menu\MenuCompositionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuController extends Controller
{
    public function __construct(private readonly MenuCompositionService $menus) {}

    public function index(ListMenusRequest $request): JsonResponse
    {
        $page = $this->menus->list(TenantContext::id($request), $request->validated());

        return response()->json(['data' => collect($page->items())->map(fn ($menu) => (new MenuSummaryResource($menu))->resolve($request)), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }

    public function show(Request $request, int $menu): JsonResponse
    {
        return response()->json(['data' => (new MenuDetailResource($this->menus->menu(TenantContext::id($request), $menu, $request->boolean('includeArchived'))))->resolve($request)]);
    }

    public function store(StoreMenuRequest $request): JsonResponse
    {
        return response()->json(['data' => (new MenuDetailResource($this->menus->createMenu(TenantContext::id($request), $request->validated())))->resolve($request)], 201);
    }

    public function update(UpdateMenuRequest $request, int $menu): JsonResponse
    {
        $model = $this->menus->menu(TenantContext::id($request), $menu);

        return response()->json(['data' => (new MenuDetailResource($this->menus->updateMenu($model, $request->validated())))->resolve($request)]);
    }

    public function archive(Request $request, int $menu): JsonResponse
    {
        $model = $this->menus->archiveMenu($this->menus->menu(TenantContext::id($request), $menu));

        return response()->json(['message' => 'Menu archived successfully.', 'data' => (new MenuDetailResource($model))->resolve($request)]);
    }

    public function restore(Request $request, int $menu): JsonResponse
    {
        $model = $this->menus->restoreMenu($this->menus->menu(TenantContext::id($request), $menu, true));

        return response()->json(['message' => 'Menu restored successfully.', 'data' => (new MenuDetailResource($model))->resolve($request)]);
    }

    public function reorder(ReorderMenusRequest $request): JsonResponse
    {
        $this->menus->reorderMenus(TenantContext::id($request), $request->validated('items'));

        return response()->json(['message' => 'Menus reordered successfully.']);
    }
}
