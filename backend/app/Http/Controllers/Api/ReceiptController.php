<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CafeConfiguration\ReceiptTemplateResource;
use App\Services\BranchAccessService;
use App\Support\ReceiptTemplateResolver;
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
        $tenant = DB::table('tenants')->where('id', $tenantId)->first();
        $payment = DB::table('payments')->where('tenant_id', $tenantId)->where('order_id', $order)->whereNull('deleted_at')->latest('paid_at')->first();
        $cashierName = $orderRow->cashier_id ? DB::table('users')->where('tenant_id', $tenantId)->where('id', $orderRow->cashier_id)->value('name') : null;
        $customerName = $orderRow->customer_id ? DB::table('customers')->where('tenant_id', $tenantId)->where('id', $orderRow->customer_id)->value('name') : null;
        $template = ReceiptTemplateResolver::resolve($tenantId, (int) $orderRow->branch_id);

        return response()->json([
            'data' => [
                'orderId' => $orderRow->id,
                'orderNumber' => $orderRow->order_number,
                'orderType' => $orderRow->type,
                'cafeName' => $tenant?->name,
                'logoUrl' => $tenant?->logo_url,
                'branchName' => $branch?->name,
                'address' => $branch?->address,
                'phone' => $branch?->phone,
                'cashierName' => $cashierName,
                'customerName' => $customerName,
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
                'footerText' => $template['footer']['text'] ?? null,
                'template' => ReceiptTemplateResource::fromResolved($template),
            ],
        ]);
    }

    public function print(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:receipt,pre_bill,kitchen_ticket'],
            'printerId' => ['nullable', 'string', 'max:160'],
            'deviceName' => ['nullable', 'string', 'max:80'],
            'channel' => ['nullable', 'in:local,whatsapp,email'],
        ]);

        $tenantId = TenantContext::id($request);
        $orderRow = $this->findOrder($tenantId, $order);
        $now = now();

        $jobId = DB::table('print_jobs')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $orderRow->branch_id,
            'order_id' => $orderRow->id,
            'type' => $data['type'],
            'printer_id' => $data['printerId'] ?? null,
            'device_name' => $data['deviceName'] ?? null,
            'channel' => $data['channel'] ?? 'local',
            'status' => 'queued',
            'queued_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return response()->json([
            'data' => [
                'id' => $jobId,
                'orderId' => $orderRow->id,
                'type' => $data['type'],
                'printerId' => $data['printerId'] ?? null,
                'deviceName' => $data['deviceName'] ?? null,
                'channel' => $data['channel'] ?? 'local',
                'status' => 'queued',
                'queuedAt' => $now->toIso8601String(),
            ],
        ], 202);
    }

    public function updatePrintJob(Request $request, int $printJob): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'in:printing,completed,failed'],
            'failureCode' => ['required_if:status,failed', 'nullable', 'in:printer_not_configured,invalid_configuration,configuration_unavailable,receipt_unavailable,rendering_failed,printer_unreachable,printer_timeout,printer_unsupported,printer_failed'],
        ]);

        $tenantId = TenantContext::id($request);
        $job = DB::table('print_jobs')
            ->where('tenant_id', $tenantId)
            ->where('id', $printJob)
            ->first();
        abort_if(! $job, 404, 'Print job not found.');
        app(BranchAccessService::class)->authorizeRequestBranch($request, (int) $job->branch_id);

        $status = $data['status'];
        if (in_array($job->status, ['completed', 'failed'], true)) {
            abort_if($job->status !== $status, 409, 'Print job is already finished.');

            return response()->json(['data' => $this->printJobData($job)]);
        }

        $now = now();
        $changes = [
            'status' => $status,
            'updated_at' => $now,
        ];
        if ($status === 'printing' || $status === 'completed') {
            $changes['started_at'] = $job->started_at ?? $now;
        }
        if (in_array($status, ['completed', 'failed'], true)) {
            $changes['completed_at'] = $now;
        }
        if ($status === 'failed') {
            $code = $data['failureCode'];
            $changes['failure_code'] = $code;
            $changes['failure_message'] = $this->safePrintFailureMessage($code);
        }

        DB::table('print_jobs')
            ->where('tenant_id', $tenantId)
            ->where('id', $printJob)
            ->update($changes);

        return response()->json([
            'data' => $this->printJobData((object) array_merge((array) $job, $changes)),
        ]);
    }

    private function printJobData(object $job): array
    {
        return [
            'id' => (int) $job->id,
            'orderId' => (int) $job->order_id,
            'type' => $job->type,
            'printerId' => $job->printer_id,
            'deviceName' => $job->device_name,
            'status' => $job->status,
            'failureCode' => $job->failure_code,
            'failureMessage' => $job->failure_message,
            'queuedAt' => $job->queued_at,
            'startedAt' => $job->started_at,
            'completedAt' => $job->completed_at,
        ];
    }

    private function safePrintFailureMessage(string $code): string
    {
        return match ($code) {
            'printer_not_configured' => 'Receipt printer is not configured.',
            'invalid_configuration' => 'Receipt printer settings are invalid.',
            'configuration_unavailable' => 'Printer settings could not be loaded.',
            'receipt_unavailable' => 'The order receipt could not be loaded.',
            'rendering_failed' => 'The receipt could not be rendered.',
            'printer_timeout' => 'The printer timed out.',
            'printer_unsupported' => 'Receipt printing is unavailable on this device.',
            'printer_unreachable' => 'Could not connect to the receipt printer.',
            default => 'Printing failed.',
        };
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
