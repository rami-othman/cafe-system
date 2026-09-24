<?php

namespace App\Http\Controllers\Api\CafeConfiguration;

use App\Http\Controllers\Controller;
use App\Http\Requests\CafeConfiguration\UpdateReceiptTemplateRequest;
use App\Http\Resources\CafeConfiguration\ReceiptTemplateResource;
use App\Models\Branch;
use App\Models\ReceiptTemplate;
use App\Support\ReceiptTemplateResolver;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class ReceiptTemplateController extends Controller
{
    public function show(Request $request, int $branch): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->branch($tenantId, $branch);

        return response()->json([
            'data' => ReceiptTemplateResource::fromResolved(ReceiptTemplateResolver::resolve($tenantId, $branch)),
        ]);
    }

    public function update(UpdateReceiptTemplateRequest $request, int $branch): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->branch($tenantId, $branch);
        $data = $request->validated();

        ReceiptTemplate::query()->updateOrCreate(
            ['tenant_id' => $tenantId, 'branch_id' => $branch, 'type' => 'receipt'],
            [
                'header' => $data['header'],
                'order_info' => $data['orderInfo'],
                // Locked regardless of client input: a receipt without item
                // names or a total is not a valid receipt.
                'items' => [...$data['items'], 'showProductName' => true],
                'totals' => [...$data['totals'], 'showTotal' => true],
                'payment' => $data['payment'],
                'footer' => $data['footer'],
                'section_order' => array_map(static fn (string $section): string => Str::snake($section), $data['sectionOrder']),
            ],
        );

        return response()->json([
            'data' => ReceiptTemplateResource::fromResolved(ReceiptTemplateResolver::resolve($tenantId, $branch)),
        ]);
    }

    private function branch(int $tenantId, int $branchId): Branch
    {
        return Branch::query()
            ->where('tenant_id', $tenantId)
            ->whereNull('deleted_at')
            ->findOrFail($branchId);
    }
}
