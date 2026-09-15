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

class BranchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return BranchResource::collection(
            Branch::query()
                ->where('tenant_id', TenantContext::id($request))
                ->whereNull('deleted_at')
                ->with(['posInventoryWarehouse', 'warehouses' => fn ($query) => $query->where('type', 'bar')->where('is_active', true)->whereNull('deleted_at')->orderBy('name')])
                ->orderBy('id')
                ->get(),
        )->response();
    }

    public function store(StoreBranchRequest $request, FinancialSetupService $financialSetup): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $branch = DB::transaction(function () use ($request, $tenantId, $financialSetup): Branch {
            $branch = Branch::query()->create([
                ...$request->validated(),
                'tenant_id' => $tenantId,
                'currency' => 'SYP',
                'is_active' => true,
            ]);
            $financialSetup->ensureBranchMainWarehouse($tenantId, $branch->id, $request->attributes->get('auth_user')->id);
            $financialSetup->ensureBranchPosWarehouse($tenantId, $branch->id, $request->attributes->get('auth_user')->id);

            return $branch;
        });

        return (new BranchResource($this->withPosWarehouses($branch)))->response()->setStatusCode(201);
    }

    public function show(Request $request, int $branch): BranchResource
    {
        return new BranchResource($this->withPosWarehouses($this->branch($request, $branch)));
    }

    public function update(UpdateBranchRequest $request, int $branch, PosInventoryWarehouseResolver $posWarehouses): BranchResource
    {
        $branch = $this->branch($request, $branch);
        $data = $request->validated();
        if (array_key_exists('posInventoryWarehouseId', $data)) {
            $posWarehouses->assertEligible((int) $branch->tenant_id, (int) $branch->id, $data['posInventoryWarehouseId']);
            $data['pos_inventory_warehouse_id'] = $data['posInventoryWarehouseId'];
            unset($data['posInventoryWarehouseId']);
        }
        $branch->update($data);

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
        return $branch->load(['posInventoryWarehouse', 'warehouses' => fn ($query) => $query->where('type', 'bar')->where('is_active', true)->whereNull('deleted_at')->orderBy('name')]);
    }
}
