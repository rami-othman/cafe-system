<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\ValidateMenuCollectionRequest;
use App\Http\Requests\Admin\Menu\ValidateMenuRequest;
use App\Http\Resources\Menu\MenuValidationResource;
use App\Services\Menu\MenuValidationService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;

class MenuValidationController extends Controller
{
    public function __construct(private readonly MenuValidationService $validation) {}

    public function validateMenu(ValidateMenuRequest $request, int $menu): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validated();
        $branch = $this->validation->branch($tenantId, $data['branchId']);
        $result = $this->validation->validateOne($tenantId, $this->validation->menu($tenantId, $menu), $branch, $data['channel'], $data['at'] ?? null);

        return response()->json(['data' => (new MenuValidationResource($result->toArray()))->resolve($request)]);
    }

    public function validateCollection(ValidateMenuCollectionRequest $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validated();
        $branch = $this->validation->branch($tenantId, $data['branchId']);
        $result = $this->validation->validateCollection($tenantId, $branch, $data['channel'], $data['menuIds'] ?? null, $data['at'] ?? null);

        return response()->json(['data' => (new MenuValidationResource($result->toArray()))->resolve($request)]);
    }
}
