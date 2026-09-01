<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\TenantRole;
use App\Services\DefaultTenantRoleService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TenantRoleController extends Controller
{
    public function index(Request $request, DefaultTenantRoleService $roles): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $roles->ensureForTenant($tenantId);

        return response()->json(['data' => TenantRole::query()->forTenant($tenantId)->orderBy('id')->get()->map(fn (TenantRole $role) => [
            'id' => $role->id,
            'code' => $role->code,
            'name' => $role->name,
            'isSystem' => $role->is_system,
            'isActive' => $role->is_active,
            'assignable' => $roles->isAssignable($role),
        ])->values()]);
    }
}
