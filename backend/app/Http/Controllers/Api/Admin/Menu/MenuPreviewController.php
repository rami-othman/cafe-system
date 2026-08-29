<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\PreviewMenuCollectionRequest;
use App\Http\Requests\Admin\Menu\PreviewMenuRequest;
use App\Http\Resources\Menu\MenuPreviewResource;
use App\Services\Menu\MenuPreviewService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;

class MenuPreviewController extends Controller
{
    public function __construct(private readonly MenuPreviewService $preview) {}

    public function previewMenu(PreviewMenuRequest $request, int $menu): JsonResponse
    {
        return response()->json(['data' => (new MenuPreviewResource($this->preview->one(TenantContext::id($request), $menu, $request->validated())))->resolve($request)]);
    }

    public function previewCollection(PreviewMenuCollectionRequest $request): JsonResponse
    {
        return response()->json(['data' => (new MenuPreviewResource($this->preview->collection(TenantContext::id($request), $request->validated())))->resolve($request)]);
    }
}
