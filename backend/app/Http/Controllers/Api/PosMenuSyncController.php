<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\UnsupportedMenuSnapshotSchemaException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Pos\PosMenuSyncRequest;
use App\Services\Menu\PosMenuSyncService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;

class PosMenuSyncController extends Controller
{
    public function __construct(private readonly PosMenuSyncService $sync) {}

    public function show(PosMenuSyncRequest $request): JsonResponse
    {
        try {
            return response()->json(['data' => $this->sync->sync(TenantContext::id($request), $request->validated('branchId'), $request->validated('knownVersionId'))]);
        } catch (UnsupportedMenuSnapshotSchemaException $exception) {
            return response()->json(['message' => $exception->getMessage(), 'code' => 'UNSUPPORTED_MENU_SNAPSHOT_SCHEMA'], 409);
        }
    }
}
