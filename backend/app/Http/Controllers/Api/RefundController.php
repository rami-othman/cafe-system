<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\OrderLifecycleException;
use App\Http\Controllers\Controller;
use App\Services\OrderLifecyclePolicy;
use App\Services\PosNumberGenerator;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RefundController extends Controller
{
    public function __construct(
        private readonly OrderLifecyclePolicy $lifecycle,
        private readonly PosNumberGenerator $numbers,
    ) {}

    public function store(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:full,partial'], 'amount' => ['nullable', 'numeric', 'min:0.01'],
            'reason' => ['required', 'string', 'max:120'], 'managerNotes' => ['nullable', 'string'],
            'idempotencyKey' => ['required', 'string', 'max:120'],
        ]);
        $tenantId = TenantContext::id($request);
        $hash = $this->payloadHash($data);

        $refund = DB::transaction(function () use ($tenantId, $order, $data, $hash) {
            $orderRow = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->lockForUpdate()->first();
            abort_if(! $orderRow, 404, 'Order not found.');

            $existing = DB::table('payment_refunds')->where('tenant_id', $tenantId)->where('order_id', $orderRow->id)
                ->where('idempotency_key', $data['idempotencyKey'])->first();
            if ($existing) {
                if (! hash_equals((string) $existing->idempotency_hash, $hash)) {
                    throw new OrderLifecycleException('REFUND_IDEMPOTENCY_CONFLICT', 'This refund key was already used for a different request.');
                }

                return $existing;
            }

            $this->lifecycle->assertRefundable($orderRow);
            // Lock the completed settlement after the order to keep payment/refund
            // lock order deterministic across financial operations.
            $payment = DB::table('payments')->where('tenant_id', $tenantId)->where('order_id', $orderRow->id)
                ->where('status', 'completed')->whereNull('deleted_at')->orderBy('id')->lockForUpdate()->first();
            if (! $payment || (int) $payment->branch_id !== (int) $orderRow->branch_id) {
                throw new OrderLifecycleException('REFUND_NOT_ALLOWED', 'No completed payment exists for this order.');
            }

            $alreadyRefunded = (float) DB::table('payment_refunds')->where('tenant_id', $tenantId)
                ->where('order_id', $orderRow->id)->where('payment_id', $payment->id)->where('status', 'completed')->sum('amount');
            $remaining = round((float) $payment->amount - $alreadyRefunded, 2);
            $amount = $data['type'] === 'full' ? $remaining : round((float) ($data['amount'] ?? 0), 2);
            if ($amount <= 0 || $amount > $remaining) {
                throw new OrderLifecycleException('REFUND_EXCEEDS_REMAINING', 'Refund amount exceeds the refundable balance.');
            }

            $now = now();
            $refundId = DB::table('payment_refunds')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $orderRow->branch_id, 'order_id' => $orderRow->id,
                'payment_id' => $payment->id, 'refund_number' => $this->numbers->nextRefundNumber($tenantId),
                'type' => $data['type'], 'amount' => $amount, 'reason' => $data['reason'],
                'manager_notes' => $data['managerNotes'] ?? null, 'status' => 'completed',
                'idempotency_key' => $data['idempotencyKey'], 'idempotency_hash' => $hash,
                'refunded_at' => $now, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $fullyRefunded = abs(round($amount - $remaining, 2)) < 0.005;
            DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderRow->id)->update([
                'payment_status' => $fullyRefunded ? 'refunded' : 'partially_refunded',
                'status' => $fullyRefunded ? 'refunded' : 'paid', 'updated_at' => $now,
            ]);
            DB::table('activity_logs')->insert([
                'tenant_id' => $tenantId, 'branch_id' => $orderRow->branch_id, 'action' => 'order.refunded',
                'entity_type' => 'order', 'entity_id' => $orderRow->id,
                'description' => "Refunded \${$amount} for {$data['reason']}.", 'created_at' => $now, 'updated_at' => $now,
            ]);

            return DB::table('payment_refunds')->where('tenant_id', $tenantId)->where('id', $refundId)->first();
        }, 3);

        return response()->json(['data' => $this->serialize($refund)], 201);
    }

    private function payloadHash(array $data): string
    {
        return hash('sha256', json_encode([
            'type' => $data['type'], 'amount' => array_key_exists('amount', $data) ? (string) $data['amount'] : null,
            'reason' => $data['reason'], 'managerNotes' => $data['managerNotes'] ?? null,
        ], JSON_THROW_ON_ERROR));
    }

    private function serialize(object $refund): array
    {
        return [
            'id' => $refund->id, 'orderId' => $refund->order_id, 'paymentId' => $refund->payment_id,
            'refundNumber' => $refund->refund_number, 'type' => $refund->type, 'amount' => (float) $refund->amount,
            'reason' => $refund->reason, 'status' => $refund->status, 'refundedAt' => $refund->refunded_at,
        ];
    }
}
