<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\DiscountEngineProtocol;
use App\Services\DiscountResolutionService;
use App\Services\OrderLifecyclePolicy;
use App\Services\SaleConsumptionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class DiscountEngineController extends Controller
{
    public function __construct(private readonly DiscountEngineProtocol $protocol) {}

    public function capabilities(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->protocol->capabilities(TenantContext::id($request), $request)]);
    }

    public function state(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        return response()->json(['data' => DB::transaction(fn () => $this->protocol->state($tenantId, $this->order($request, $tenantId, $order)))]);
    }

    public function operation(Request $request, int $order, string $identity): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $result = DB::transaction(function () use ($request, $tenantId, $order, $identity): array {
            // Wait for any in-flight mutation on this order before reporting
            // whether its durable completion exists.
            $this->order($request, $tenantId, $order);
            $row = DB::table('discount_operations')->where('tenant_id', $tenantId)->where('order_id', $order)->where('identity', $identity)->first();

            return ['operationId' => $identity, 'completed' => $row !== null, 'result' => $row === null ? null : json_decode($row->result, true)];
        });

        return response()->json(['data' => $result]);
    }

    public function preview(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->protocol->compatible($request, $tenantId, $order, true);
        $data = $request->validate([
            'action' => ['required', 'in:apply,remove,suppress,undo'],
            'intent' => ['required_if:action,apply', 'array:source,discountId,code,type,value,reason'],
            'intent.source' => ['required_if:action,apply', 'in:configured_manual,code,ad_hoc'],
            'intent.discountId' => ['nullable', 'integer'], 'intent.code' => ['nullable', 'string', 'max:100'],
            'intent.type' => ['nullable', 'in:fixed,percentage'], 'intent.value' => ['nullable', 'numeric', 'min:0', 'max:9999999999.99'],
            'intent.reason' => ['nullable', 'string', 'max:255'],
            'discountId' => ['required_if:action,suppress,undo', 'integer'],
            'reason' => ['required_if:action,suppress', 'nullable', 'string', 'max:500'],
            'paymentMethodId' => ['nullable', 'integer'],
        ]);
        $result = DB::transaction(function () use ($request, $tenantId, $order, $data) {
            $row = $this->order($request, $tenantId, $order);
            app(OrderLifecyclePolicy::class)->assertDiscountable($row);

            return $this->protocol->preview($request, $tenantId, $row, $data);
        });

        return response()->json(['data' => $result]);
    }

    public function apply(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->protocol->compatible($request, $tenantId, $order, true);
        $data = $request->validate(['operationId' => ['required', 'string', 'max:120'], 'reviewId' => ['required', 'uuid']]);
        $result = DB::transaction(fn () => $this->protocol->apply($request, $tenantId, $this->order($request, $tenantId, $order), $data));

        return response()->json(['data' => $result]);
    }

    public function quote(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->protocol->compatible($request, $tenantId, $order, true);
        $data = $request->validate(['paymentMethodId' => ['nullable', 'integer']]);
        $result = DB::transaction(function () use ($request, $tenantId, $order, $data) {
            $row = $this->order($request, $tenantId, $order);
            app(OrderLifecyclePolicy::class)->assertPayable($row);
            // Binding takes warehouse FK KEY SHARE. Acquire the engine gate
            // first, consistently with payments that later lock stock rows.
            app(DiscountResolutionService::class)->lock($tenantId);
            $row = app(SaleConsumptionService::class)->bindLegacyOrderWarehouse($tenantId, $row);
            $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $row->id)->first();

            return $this->protocol->quote($request, $tenantId, $row, $data);
        });

        return response()->json(['data' => $result]);
    }

    private function order(Request $request, int $tenantId, int $id, bool $lock = true): object
    {
        $query = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at');
        $row = ($lock ? $query->lockForUpdate() : $query)->first();
        abort_if(! $row, 404, 'Order not found.');
        app(BranchAccessService::class)->authorizeRequestBranch($request, (int) $row->branch_id);

        return $row;
    }
}
