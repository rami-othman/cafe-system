<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TableController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        $query = DB::table('cafe_tables')
            ->where('tenant_id', $tenantId)
            ->whereIn('branch_id', app(BranchAccessService::class)->accessibleBranchIds($request->attributes->get('auth_user')))
            ->whereNull('deleted_at');

        if ($request->filled('branchId')) {
            $query->where('branch_id', (int) $request->query('branchId'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }

        $tables = $query->orderBy('sort_order')->orderBy('name')->get()
            ->map(fn ($table) => [
                'id' => $table->id,
                'branchId' => $table->branch_id,
                'name' => $table->name,
                'code' => $table->code,
                'seats' => $table->seats,
                'status' => $table->status,
                'sortOrder' => $table->sort_order,
            ]);

        return response()->json(['data' => $tables]);
    }
}
