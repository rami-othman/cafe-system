<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReceiptController extends Controller
{
    public function show(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $orderRow = $this->findOrder($tenantId, $order);
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $orderRow->branch_id)->first();
        $payment = DB::table('payments')->where('tenant_id', $tenantId)->where('order_id', $order)->whereNull('deleted_at')->latest('paid_at')->first();

        return response()->json([
            'data' => [
                'orderId' => $orderRow->id,
                'orderNumber' => $orderRow->order_number,
                'title' => 'Cafe System 618',
                'branchName' => $branch?->name,
                'addressLines' => ['123 Espresso Lane, Cityville', 'Tel: (555) 123-4567'],
                'cashierName' => 'POS Register',
                'date' => $orderRow->created_at,
                'items' => $this->items($tenantId, $orderRow->id),
                'subtotal' => (float) $orderRow->subtotal,
                'discountTotal' => (float) $orderRow->discount_total,
                'taxTotal' => (float) $orderRow->tax_total,
                'taxRate' => (float) $orderRow->tax_rate,
                'total' => (float) $orderRow->total,
                'payment' => $payment ? [
                    'method' => $payment->method,
                    'amount' => (float) $payment->amount,
                    'reference' => $payment->reference_number,
                    'paidAt' => $payment->paid_at,
                ] : null,
                'footerLines' => ['Thank you for visiting!', 'cafesystem618.com/feedback'],
            ],
        ]);
    }

    public function print(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:receipt,kitchen_ticket'],
            'printerId' => ['nullable', 'string'],
            'channel' => ['nullable', 'in:local,whatsapp,email'],
        ]);

        $tenantId = TenantContext::id($request);
        $orderRow = $this->findOrder($tenantId, $order);

        $jobId = DB::table('print_jobs')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $orderRow->branch_id,
            'order_id' => $orderRow->id,
            'type' => $data['type'],
            'printer_id' => $data['printerId'] ?? null,
            'channel' => $data['channel'] ?? 'local',
            'status' => 'queued',
            'queued_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json([
            'data' => [
                'id' => $jobId,
                'orderId' => $orderRow->id,
                'type' => $data['type'],
                'printerId' => $data['printerId'] ?? null,
                'channel' => $data['channel'] ?? 'local',
                'status' => 'queued',
            ],
        ], 202);
    }

    private function findOrder(int $tenantId, int $orderId): object
    {
        $order = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderId)->whereNull('deleted_at')->first();
        abort_if(! $order, 404, 'Order not found.');
        app(BranchAccessService::class)->authorizeRequestBranch(request(), (int) $order->branch_id);

        return $order;
    }

    private function items(int $tenantId, int $orderId): array
    {
        return DB::table('order_items')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $orderId)
            ->whereNull('deleted_at')
            ->orderBy('id')
            ->get()
            ->map(function ($item) use ($tenantId) {
                $modifiers = DB::table('order_item_modifiers')
                    ->where('tenant_id', $tenantId)
                    ->where('order_item_id', $item->id)
                    ->get()
                    ->map(fn ($modifier) => [
                        'name' => $modifier->option_name,
                        'priceDelta' => (float) $modifier->price_delta,
                    ])
                    ->all();

                return [
                    'quantity' => (float) $item->quantity,
                    'name' => $item->product_name,
                    'unitPrice' => (float) $item->unit_price,
                    'lineTotal' => (float) $item->total,
                    'modifiers' => $modifiers,
                    'note' => $item->notes,
                ];
            })
            ->all();
    }
}
