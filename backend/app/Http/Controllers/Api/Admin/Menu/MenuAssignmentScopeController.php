<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Domain\Menu\Enums\SalesChannel;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\SyncMenuAssignmentScopeRequest;
use App\Http\Resources\Menu\MenuAssignmentResource;
use App\Services\Menu\MenuCompositionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class MenuAssignmentScopeController extends Controller
{
    public function __construct(private readonly MenuCompositionService $menus) {}

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'branchId' => ['required', 'integer'],
            'channel' => ['required', Rule::enum(SalesChannel::class)],
        ]);

        return response()->json(['data' => MenuAssignmentResource::collection($this->menus->assignmentsForScope(TenantContext::id($request), $data['branchId'], $data['channel']))->resolve($request)]);
    }

    public function sync(SyncMenuAssignmentScopeRequest $request): JsonResponse
    {
        $items = $this->menus->syncAssignmentsForScope(TenantContext::id($request), $request->validated('branchId'), $request->validated('channel'), $request->validated('assignments'));

        return response()->json(['data' => MenuAssignmentResource::collection($items)->resolve($request)]);
    }
}
