<?php

namespace App\Http\Controllers\Api\CafeConfiguration;

use App\Http\Controllers\Controller;
use App\Http\Requests\CafeConfiguration\StoreBranchRequest;
use App\Http\Requests\CafeConfiguration\UpdateBranchRequest;
use App\Http\Resources\CafeConfiguration\BranchResource;
use App\Models\Branch;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BranchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return BranchResource::collection(
            Branch::query()
                ->where('tenant_id', TenantContext::id($request))
                ->whereNull('deleted_at')
                ->orderBy('id')
                ->get(),
        )->response();
    }

    public function store(StoreBranchRequest $request): JsonResponse
    {
        $branch = Branch::query()->create([
            ...$request->validated(),
            'tenant_id' => TenantContext::id($request),
            'currency' => 'SYP',
            'is_active' => true,
        ]);

        return (new BranchResource($branch))->response()->setStatusCode(201);
    }

    public function show(Request $request, int $branch): BranchResource
    {
        return new BranchResource($this->branch($request, $branch));
    }

    public function update(UpdateBranchRequest $request, int $branch): BranchResource
    {
        $branch = $this->branch($request, $branch);
        $branch->update($request->validated());

        return new BranchResource($branch->fresh());
    }

    private function branch(Request $request, int $branchId): Branch
    {
        return Branch::query()
            ->where('tenant_id', TenantContext::id($request))
            ->whereNull('deleted_at')
            ->findOrFail($branchId);
    }
}
