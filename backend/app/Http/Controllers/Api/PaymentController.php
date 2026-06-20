<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PaymentController extends Controller
{
    public function summary(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'amountReceived' => ['nullable', 'numeric', 'min:0'],
        ]);

        $tenantId = TenantContext::id($request);
        $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->first();
        abort_if(! $row, 404, 'Order not found.');

        $itemCount = (float) DB::table('order_items')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $order)
            ->whereNull('deleted_at')
            ->sum('quantity');

        $total = (float) $row->total;
        $received = array_key_exists('amountReceived', $data) ? (float) $data['amountReceived'] : $total;

        return response()->json([
            'data' => [
                'orderId' => $row->id,
                'orderNumber' => $row->order_number,
                'totalDue' => $total,
                'itemCount' => $itemCount,
                'amountReceived' => $received,
                'changeDue' => round(max(0, $received - $total), 2),
                'methods' => ['cash', 'card', 'wallet', 'split'],
                'quickAmounts' => $this->quickAmounts($total),
            ],
        ]);
    }

    public function pay(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'method' => ['required', 'in:cash,card,wallet,split'],
            'amount' => ['required', 'numeric', 'min:0'],
            'reference' => ['nullable', 'string'],
            'note' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->first();
        abort_if(! $row, 404, 'Order not found.');
        abort_if((float) $data['amount'] < (float) $row->total, 422, 'Payment amount is less than order total.');

        $payment = DB::transaction(function () use ($tenantId, $row, $data) {
            $now = now();
            $paymentId = DB::table('payments')->insertGetId([
                'tenant_id' => $tenantId,
                'branch_id' => $row->branch_id,
                'order_id' => $row->id,
                'shift_id' => $row->shift_id,
                'cashier_id' => $row->cashier_id,
                'method' => $data['method'],
                'amount' => $data['amount'],
                'currency' => 'SYP',
                'status' => 'completed',
                'reference_number' => $data['reference'] ?? null,
                'notes' => $data['note'] ?? null,
                'paid_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            DB::table('orders')->where('tenant_id', $tenantId)->where('id', $row->id)->update([
                'status' => 'paid',
                'payment_status' => 'paid',
                'closed_at' => $now,
                'updated_at' => $now,
            ]);

            return DB::table('payments')->where('id', $paymentId)->first();
        });

        return response()->json([
            'data' => [
                'orderId' => $row->id,
                'changeDue' => round(max(0, (float) $payment->amount - (float) $row->total), 2),
                'payment' => [
                    'id' => $payment->id,
                    'method' => $payment->method,
                    'amount' => (float) $payment->amount,
                    'status' => $payment->status,
                    'paidAt' => $payment->paid_at,
                ],
            ],
        ]);
    }

    private function quickAmounts(float $total): array
    {
        $rounded = (float) (ceil($total / 5) * 5);

        return array_values(array_unique([
            $rounded,
            $rounded + 5,
            $rounded + 15,
            $total,
        ]));
    }
}
