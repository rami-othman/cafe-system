<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\CurrentPublishedMenuVersionRequest;
use App\Http\Requests\Admin\Menu\PublishMenuRequest;
use App\Http\Resources\Menu\PublishedMenuVersionResource;
use App\Services\Menu\MenuPublishingService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;

class MenuPublishingController extends Controller
{
    public function __construct(private readonly MenuPublishingService $publishing) {}

    public function publish(PublishMenuRequest $request): JsonResponse
    {
        return response()->json(['data' => $this->publishing->publish(TenantContext::id($request), $request->validated())]);
    }

    public function current(CurrentPublishedMenuVersionRequest $request): JsonResponse
    {
        return response()->json(['data' => (new PublishedMenuVersionResource($this->publishing->current(TenantContext::id($request), $request->validated())))->resolve($request)]);
    }
}
