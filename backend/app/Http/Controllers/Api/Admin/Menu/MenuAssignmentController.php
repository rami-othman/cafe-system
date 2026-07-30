<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\SyncMenuAssignmentsRequest;
use App\Http\Resources\Menu\MenuAssignmentResource;
use App\Services\Menu\MenuCompositionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuAssignmentController extends Controller
{
    public function __construct(private readonly MenuCompositionService $menus) {}

    public function index(Request $request, int $menu): JsonResponse
    {
        return response()->json(['data' => MenuAssignmentResource::collection($this->menus->assignments($this->menus->menu(TenantContext::id($request), $menu)))->resolve($request)]);
    }

    public function sync(SyncMenuAssignmentsRequest $request, int $menu): JsonResponse
    {
        $items = $this->menus->syncAssignments($this->menus->menu(TenantContext::id($request), $menu), $request->validated('assignments'));

        return response()->json(['data' => MenuAssignmentResource::collection($items)->resolve($request)]);
    }
}
