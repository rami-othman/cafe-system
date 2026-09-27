<?php

namespace App\Http\Controllers\Api\Manufacturing;

use App\Domain\Manufacturing\ManufacturingReportService;
use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ManufacturingReportController extends Controller
{
    public function __construct(private readonly ManufacturingReportService $reports) {}

    public function overview(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $warehouseId = $this->warehouse($request, $tenantId);

        return response()->json(['data' => $this->reports->overview($tenantId, $warehouseId, $this->branches($request, $tenantId))]);
    }

    public function reports(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $warehouseId = $this->warehouse($request, $tenantId);

        return response()->json(['data' => $this->reports->reports($tenantId, $warehouseId, $request->query('type'), $request->query('dateFrom'), $request->query('dateTo'), $this->branches($request, $tenantId))]);
    }
    private function branches(Request $request, int $tenant): array
    {
        $ids = \App\Support\FinancialActor::operationalBranchIds(\App\Support\FinancialActor::id($request, $tenant), $tenant);
        return \Illuminate\Support\Facades\DB::table('branches')->where('tenant_id', $tenant)->whereIn('id', $ids)->where('branch_type', 'factory')->when($request->filled('branchId'), fn ($q) => $q->where('id', $request->input('branchId')))->pluck('id')->all();
    }
    private function warehouse(Request $request, int $tenant): ?int
    {
        $branch = (int) $request->input('branchId', 0);
        if (! $branch && ! $request->filled('warehouseId')) return null;
        if (! $branch) $branch = (int) \Illuminate\Support\Facades\DB::table('warehouses')->where('tenant_id', $tenant)->where('id', $request->input('warehouseId'))->value('branch_id');
        \App\Support\FactoryWarehouseScope::assertFactoryBranch($tenant, $branch);
        \App\Support\FinancialActor::assertBranchAccess(\App\Support\FinancialActor::id($request, $tenant), $tenant, $branch);
        $id = $request->filled('warehouseId') ? (int) $request->input('warehouseId') : (int) app(\App\Services\FactoryInventoryWarehouseResolver::class)->forBranch($tenant, $branch)->id;
        \App\Support\FactoryWarehouseScope::assertWarehouseForBranch($tenant, $branch, $id);
        return $id;
    }
}
