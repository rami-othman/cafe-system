<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class RefundController extends Controller
{
    public function store(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:full,partial'],
            'amount' => ['nullable', 'numeric', 'min:0.01'],
            'reason' => ['required', 'string', 'max:120'],
            'managerNotes' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $orderRow = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->first();
        abort_if(! $orderRow, 404, 'Order not found.');
        abort_if($orderRow->payment_status === 'unpaid', 422, 'Only paid orders can be refunded.');

        $payment = DB::table('payments')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $order)
            ->where('status', 'completed')
            ->whereNull('deleted_at')
            ->latest('paid_at')
            ->first();
        abort_if(! $payment, 422, 'No completed payment exists for this order.');

        $alreadyRefunded = (float) DB::table('payment_refunds')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $order)
            ->where('status', 'completed')
            ->sum('amount');
        $remaining = round((float) $payment->amount - $alreadyRefunded, 2);
        $amount = $data['type'] === 'full' ? $remaining : round((float) ($data['amount'] ?? 0), 2);

        if ($amount <= 0 || $amount > $remaining) {
            throw ValidationException::withMessages(['amount' => 'Refund amount exceeds the refundable balance.']);
        }

        $refund = DB::transaction(function () use ($tenantId, $orderRow, $payment, $data, $amount, $remaining) {
            $now = now();
            $refundId = DB::table('payment_refunds')->insertGetId([
                'tenant_id' => $tenantId,
                'branch_id' => $orderRow->branch_id,
                'order_id' => $orderRow->id,
                'payment_id' => $payment->id,
                'refund_number' => $this->nextRefundNumber($tenantId),
                'type' => $data['type'],
                'amount' => $amount,
                'reason' => $data['reason'],
                'manager_notes' => $data['managerNotes'] ?? null,
                'status' => 'completed',
                'refunded_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $paymentStatus = $amount >= $remaining ? 'refunded' : 'partially_refunded';
            DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderRow->id)->update([
                'payment_status' => $paymentStatus,
                'status' => $paymentStatus === 'refunded' ? 'refunded' : $orderRow->status,
                'updated_at' => $now,
            ]);

            DB::table('activity_logs')->insert([
                'tenant_id' => $tenantId,
                'branch_id' => $orderRow->branch_id,
                'action' => 'order.refunded',
                'entity_type' => 'order',
                'entity_id' => $orderRow->id,
                'description' => "Refunded \${$amount} for {$data['reason']}.",
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            return DB::table('payment_refunds')->where('tenant_id', $tenantId)->where('id', $refundId)->first();
        });

        return response()->json([
            'data' => [
                'id' => $refund->id,
                'orderId' => $refund->order_id,
                'paymentId' => $refund->payment_id,
                'refundNumber' => $refund->refund_number,
                'type' => $refund->type,
                'amount' => (float) $refund->amount,
                'reason' => $refund->reason,
                'status' => $refund->status,
                'refundedAt' => $refund->refunded_at,
            ],
        ], 201);
    }

    private function nextRefundNumber(int $tenantId): string
    {
        $count = DB::table('payment_refunds')->where('tenant_id', $tenantId)->count() + 1;

        return 'RF-'.now()->format('Ymd').'-'.str_pad((string) $count, 4, '0', STR_PAD_LEFT);
    }
}
