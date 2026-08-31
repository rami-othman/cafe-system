<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\OrderLifecycleException;
use App\Http\Controllers\Controller;
use App\Services\DiscountEligibilityService;
use App\Services\OrderLifecyclePolicy;
use App\Services\PosPricingService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PaymentController extends Controller
{
    public function __construct(
        private readonly OrderLifecyclePolicy $lifecycle,
        private readonly DiscountEligibilityService $discounts,
        private readonly PosPricingService $pricing,
    ) {}

    public function summary(Request $request, int $order): JsonResponse
    {
        $data = $request->validate(['amountReceived' => ['nullable', 'numeric', 'min:0']]);
        $tenantId = TenantContext::id($request);
        $row = $this->findOrder($tenantId, $order);
        $itemCount = (float) DB::table('order_items')->where('tenant_id', $tenantId)->where('order_id', $order)->whereNull('deleted_at')->sum('quantity');
        $total = (float) $row->total;
        $received = array_key_exists('amountReceived', $data) ? (float) $data['amountReceived'] : $total;

        return response()->json(['data' => [
            'orderId' => $row->id, 'orderNumber' => $row->order_number, 'totalDue' => $total,
            'itemCount' => $itemCount, 'amountReceived' => $received,
            'changeDue' => round(max(0, $received - $total), 2),
            'methods' => ['cash', 'card', 'wallet', 'split'], 'quickAmounts' => $this->quickAmounts($total),
        ]]);
    }

    public function pay(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'method' => ['required', 'in:cash,card,wallet,split'],
            'amount' => ['required', 'numeric', 'min:0'],
            'reference' => ['nullable', 'string'], 'note' => ['nullable', 'string'],
            'idempotencyKey' => ['required', 'string', 'max:120'],
        ]);
        $tenantId = TenantContext::id($request);
        $hash = $this->payloadHash($data);

        $result = DB::transaction(function () use ($tenantId, $order, $data, $hash): array {
            $row = $this->lockedOrder($tenantId, $order);
            $existing = DB::table('payments')->where('tenant_id', $tenantId)->where('order_id', $row->id)
                ->where('idempotency_key', $data['idempotencyKey'])->first();
            if ($existing) {
                if (! hash_equals((string) $existing->idempotency_hash, $hash)) {
                    throw new OrderLifecycleException('PAYMENT_IDEMPOTENCY_CONFLICT', 'This payment key was already used for a different request.');
                }

                return ['payment' => $existing, 'total' => (float) $row->total, 'received' => (float) $data['amount']];
            }

            $this->lifecycle->assertPayable($row);
            if (DB::table('payments')->where('tenant_id', $tenantId)->where('order_id', $row->id)->where('status', 'completed')->whereNull('deleted_at')->exists()) {
                throw new OrderLifecycleException('PAYMENT_ALREADY_COMPLETED', 'A completed payment already exists for this order.');
            }
            // Apply-time deliberately defers tender validation. Payment is the
            // authoritative second stage, including revalidation after a
            // manager changes a policy or its schedule expires.
            if (DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $row->id)->whereNotNull('discount_id')->exists()) {
                $row = $this->pricing->recalculateOrder($tenantId, $row->id, true, $data['method']);
            }
            if ((float) $data['amount'] < (float) $row->total) {
                throw ValidationException::withMessages(['amount' => 'Payment amount is less than order total.']);
            }

            $currency = (string) (DB::table('branches')->where('tenant_id', $tenantId)->where('id', $row->branch_id)->whereNull('deleted_at')->value('currency') ?? 'SYP');
            $now = now();
            $paymentId = DB::table('payments')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $row->branch_id, 'order_id' => $row->id,
                'shift_id' => $row->shift_id, 'cashier_id' => $row->cashier_id, 'method' => $data['method'],
                'amount' => $row->total, 'currency' => $currency, 'status' => 'completed',
                'idempotency_key' => $data['idempotencyKey'], 'idempotency_hash' => $hash,
                'reference_number' => $data['reference'] ?? null, 'notes' => $data['note'] ?? null,
                'paid_at' => $now, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $this->discounts->consumeUsage($tenantId, $row, $paymentId);
            DB::table('orders')->where('tenant_id', $tenantId)->where('id', $row->id)->update([
                'status' => 'paid', 'payment_status' => 'paid', 'closed_at' => $now, 'updated_at' => $now,
            ]);

            return ['payment' => DB::table('payments')->where('id', $paymentId)->first(), 'total' => (float) $row->total, 'received' => (float) $data['amount']];
        }, 3);

        return response()->json(['data' => $this->serializePayment($order, $result['payment'], $result['total'], $result['received'])]);
    }

    private function lockedOrder(int $tenantId, int $order): object
    {
        $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->lockForUpdate()->first();
        abort_if(! $row, 404, 'Order not found.');

        return $row;
    }

    private function findOrder(int $tenantId, int $order): object
    {
        $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->first();
        abort_if(! $row, 404, 'Order not found.');

        return $row;
    }

    private function serializePayment(int $orderId, object $payment, float $total, float $received): array
    {
        return ['orderId' => $orderId, 'changeDue' => round(max(0, $received - $total), 2), 'payment' => [
            'id' => $payment->id, 'method' => $payment->method, 'amount' => (float) $payment->amount,
            'status' => $payment->status, 'paidAt' => $payment->paid_at,
        ]];
    }

    private function payloadHash(array $data): string
    {
        return hash('sha256', json_encode([
            'method' => $data['method'], 'amount' => (string) $data['amount'],
            'reference' => $data['reference'] ?? null, 'note' => $data['note'] ?? null,
        ], JSON_THROW_ON_ERROR));
    }

    private function quickAmounts(float $total): array
    {
        $rounded = (float) (ceil($total / 5) * 5);

        return array_values(array_unique([$rounded, $rounded + 5, $rounded + 15, $total]));
    }
}
