<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinancialSetupService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FinancialSetupStatusController extends Controller
{
    public function __construct(private readonly FinancialSetupService $setup) {}

    public function show(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $requiredCodes = collect($this->setup->defaultAccounts())->pluck('code');
        $accountsReady = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')->whereIn('code', $requiredCodes)->count() === $requiredCodes->count();
        $centralReady = DB::table('warehouses')->where('tenant_id', $tenantId)->where('type', 'central')->where('is_active', true)->whereNull('deleted_at')->exists();
        $branches = DB::table('branches')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->orderBy('id')->get();
        $missingBranchWarehouses = $branches->filter(fn (object $branch) => ! DB::table('warehouses')->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('type', 'branch_main')->where('is_active', true)->whereNull('deleted_at')->exists())->map(fn (object $branch) => ['id' => (int) $branch->id, 'name' => $branch->name])->values();
        $branchCoverageReady = $missingBranchWarehouses->isEmpty();

        return response()->json(['data' => [
            'systemAccountsReady' => $accountsReady,
            'centralWarehouseReady' => $centralReady,
            'branchWarehouseCoverageReady' => $branchCoverageReady,
            'financialSetupReady' => $accountsReady && $centralReady && $branchCoverageReady,
            'requiredAccountCount' => $requiredCodes->count(),
            'configuredAccountCount' => DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')->count(),
            'activeBranchCount' => $branches->count(),
            'missingBranchWarehouses' => $missingBranchWarehouses,
        ]]);
    }
}
