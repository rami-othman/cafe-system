<?php

namespace App\Http\Controllers\Api\CafeConfiguration;

use App\Http\Controllers\Controller;
use App\Http\Requests\CafeConfiguration\StoreBranchRequest;
use App\Http\Requests\CafeConfiguration\UpdateBranchRequest;
use App\Http\Resources\CafeConfiguration\BranchResource;
use App\Models\Branch;
use App\Services\FinancialSetupService;
use App\Services\PosInventoryWarehouseResolver;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BranchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return BranchResource::collection(
            Branch::query()
                ->where('tenant_id', TenantContext::id($request))
                ->whereNull('deleted_at')
                ->with(['posInventoryWarehouse', 'warehouses' => fn ($query) => $query->where('is_active', true)->whereNull('deleted_at')->orderBy('name')])
                ->orderBy('id')
                ->get(),
        )->response();
    }

    public function store(StoreBranchRequest $request, FinancialSetupService $financialSetup): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validated();
        $warehouseName = $data['warehouseName'] ?? null;
        unset($data['warehouseName']);
        $branch = DB::transaction(function () use ($data, $tenantId, $financialSetup, $warehouseName, $request): Branch {
            $branch = Branch::query()->create([
                ...$data,
                'tenant_id' => $tenantId,
                'currency' => 'SYP',
                'is_active' => true,
            ]);
            $financialSetup->ensureBranchWarehouse($tenantId, $branch->id, $warehouseName, $request->attributes->get('auth_user')->id);
            $financialSetup->ensureBranchCashDrawer($tenantId, $branch->id, $request->attributes->get('auth_user')->id);

            return $branch;
        });

        return (new BranchResource($this->withPosWarehouses($branch)))->response()->setStatusCode(201);
    }

    public function show(Request $request, int $branch): BranchResource
    {
        return new BranchResource($this->withPosWarehouses($this->branch($request, $branch)));
    }

    public function update(UpdateBranchRequest $request, int $branch, PosInventoryWarehouseResolver $posWarehouses, FinancialSetupService $financialSetup): BranchResource
    {
        $branch = $this->branch($request, $branch);
        $data = $request->validated();
        if (array_key_exists('posInventoryWarehouseId', $data)) {
            $posWarehouses->assertEligible((int) $branch->tenant_id, (int) $branch->id, $data['posInventoryWarehouseId']);
            $data['pos_inventory_warehouse_id'] = $data['posInventoryWarehouseId'];
            unset($data['posInventoryWarehouseId']);
        }
        if (array_key_exists('posCashFinancialLocationId', $data)) {
            $locationId = (int) $data['posCashFinancialLocationId'];
            $valid = DB::table('financial_locations as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
                ->where('l.id', $locationId)->where('l.tenant_id', $branch->tenant_id)
                ->where('l.branch_id', $branch->id)->where('l.kind', 'cash')->where('l.type', 'cash_drawer')
                ->where('l.is_active', true)->where('a.tenant_id', $branch->tenant_id)
                ->where('a.is_active', true)->whereNull('a.deleted_at')->exists();
            if (! $valid) throw ValidationException::withMessages(['posCashFinancialLocationId' => 'Select an active POS cash drawer for this branch.']);
            $data['pos_cash_financial_location_id'] = $locationId;
            unset($data['posCashFinancialLocationId']);
        }
        DB::transaction(function () use ($branch, $data, $financialSetup, $request): void {
            $branch->update($data);
            if ($branch->is_active) {
                $financialSetup->ensureBranchCashDrawer((int) $branch->tenant_id, (int) $branch->id, $request->attributes->get('auth_user')->id);
            }
        });

        return new BranchResource($this->withPosWarehouses($branch->fresh()));
    }

    private function branch(Request $request, int $branchId): Branch
    {
        return Branch::query()
            ->where('tenant_id', TenantContext::id($request))
            ->whereNull('deleted_at')
            ->findOrFail($branchId);
    }

    private function withPosWarehouses(Branch $branch): Branch
    {
        return $branch->load(['posInventoryWarehouse', 'warehouses' => fn ($query) => $query->where('is_active', true)->whereNull('deleted_at')->orderBy('name')]);
    }
}
