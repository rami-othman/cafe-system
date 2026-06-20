<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BranchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        $branches = DB::table('branches')
            ->where('tenant_id', $tenantId)
            ->whereNull('deleted_at')
            ->orderBy('id')
            ->get()
            ->map(fn ($branch) => [
                'id' => $branch->id,
                'name' => $branch->name,
                'currency' => $branch->currency,
                'timezone' => $branch->timezone,
                'isActive' => (bool) $branch->is_active,
            ]);

        return response()->json(['data' => $branches]);
    }
}
