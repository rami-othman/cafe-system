<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AccountingPostingService;
use App\Services\OperationalAuditService;
use App\Services\SaleConsumptionService;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use App\Support\SalePaymentMethodResolver;
use App\Support\TenantContext;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PaymentController extends Controller
{
    public function __construct(
        private readonly SaleConsumptionService $consumption,
        private readonly AccountingPostingService $posting,
        private readonly OperationalAuditService $audit,
    ) {}

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
            'paymentMethodId' => ['nullable', 'integer'],
            'amount' => ['required', 'numeric', 'min:0'],
            'reference' => ['nullable', 'string'],
            'note' => ['nullable', 'string'],
            'idempotencyKey' => ['nullable', 'string', 'max:120'],
        ]);

        $tenantId = TenantContext::id($request);
        $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->first();
        abort_if(! $row, 404, 'Order not found.');

        $key = $data['idempotencyKey'] ?? null;
        $fingerprint = $key === null ? null : IdempotencyFingerprint::from([...$data, 'orderId' => $order]);
        if ($key !== null) {
            $existing = $this->paymentByIdempotencyKey($tenantId, $key);
            if ($existing !== null) {
                $this->assertMatchingIdempotencyRequest($existing, $fingerprint);

                return $this->paymentResponse($row, $existing);
            }
        }

        $amountCents = Money::cents($data['amount']);
        $actorId = $this->actorId($request);

        try {
            $payment = DB::transaction(function () use ($request, $tenantId, $order, $data, $key, $fingerprint, $amountCents, $actorId) {
                if ($key !== null) {
                    $existing = $this->paymentByIdempotencyKey($tenantId, $key, true);
                    if ($existing !== null) {
                        $this->assertMatchingIdempotencyRequest($existing, $fingerprint);

                        return $existing;
                    }
                }

                $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->lockForUpdate()->first();
                abort_if(! $row, 404, 'Order not found.');
                abort_if($row->payment_status !== 'unpaid', 422, 'This order already has a payment on record.');
                abort_if($amountCents < Money::cents($row->total), 422, 'Payment amount is less than order total.');

                // An explicitly selected payment method must resolve to a real
                // Finance mapping or the sale is rejected outright (section 25).
                // The legacy `method` string is only ever a graceful fallback.
                $resolvedMethod = isset($data['paymentMethodId'])
                    ? SalePaymentMethodResolver::resolveExplicit($tenantId, (int) $data['paymentMethodId'])
                    : SalePaymentMethodResolver::resolveByLegacyMethod($tenantId, $data['method']);

                $now = now();
                $paymentId = DB::table('payments')->insertGetId([
                    'tenant_id' => $tenantId,
                    'branch_id' => $row->branch_id,
                    'order_id' => $row->id,
                    'shift_id' => $row->shift_id,
                    'cashier_id' => $row->cashier_id,
                    'method' => $data['method'],
                    'payment_method_id' => $resolvedMethod?->paymentMethodId,
                    'amount' => Money::decimal($amountCents),
                    'currency' => 'SYP',
                    'status' => 'completed',
                    'reference_number' => $data['reference'] ?? null,
                    'notes' => $data['note'] ?? null,
                    'idempotency_key' => $key,
                    'idempotency_fingerprint' => $fingerprint,
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
                $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $row->id)->first();

                // Inventory remains authoritative for consumption/cost. This
                // always runs for a completed sale, regardless of whether the
                // payment method is Finance-mapped yet — goods left the
                // building either way. A missing recipe/warehouse
                // configuration throws and rolls back this entire payment.
                $consumption = $this->consumption->consumeForOrder($request, $tenantId, $row, $paymentId, $actorId);

                if ($resolvedMethod !== null) {
                    $this->postSale($request, $tenantId, $row, $resolvedMethod, $consumption['cogsTotalCents'], $actorId);
                } else {
                    $this->audit->record($request, $tenantId, 'pos_order.finance_posting_skipped', 'order', $row->id, [], ['reason' => 'No active Finance mapping for payment method "'.$data['method'].'".'], $row->branch_id, $actorId);
                }

                return DB::table('payments')->where('id', $paymentId)->first();
            });
        } catch (QueryException $exception) {
            if ($key !== null && ($existing = $this->paymentByIdempotencyKey($tenantId, $key)) !== null) {
                $this->assertMatchingIdempotencyRequest($existing, $fingerprint);

                return $this->paymentResponse($row, $existing);
            }
            throw $exception;
        }

        return $this->paymentResponse($row, $payment);
    }

    private function paymentByIdempotencyKey(int $tenantId, string $key, bool $lock = false): ?object
    {
        $query = DB::table('payments')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    private function assertMatchingIdempotencyRequest(object $existing, ?string $fingerprint): void
    {
        abort_if($fingerprint === null || empty($existing->idempotency_fingerprint) || ! hash_equals((string) $existing->idempotency_fingerprint, $fingerprint), 409, 'This idempotency key was already used for a different request.');
    }

    /**
     * Payment Destination DR (order.total) [+ Discounts Given DR] = Sales
     * Revenue CR (subtotal) [+ Sales Tax Payable CR] — then, only when
     * Inventory produced authoritative COGS, COGS DR = Inventory Asset CR.
     * Never derives COGS from price/cost_price; `$cogsCents` is exactly what
     * SaleConsumptionService summed from Inventory's own movement costs.
     */
    private function postSale(Request $request, int $tenantId, object $order, object $method, int $cogsCents, ?int $actorId): void
    {
        $subtotalCents = Money::cents($order->subtotal);
        $discountCents = Money::cents($order->discount_total);
        $taxCents = Money::cents($order->tax_total);
        $totalCents = Money::cents($order->total);

        $lines = [
            ['accountCode' => $method->accountCode, 'debit' => Money::decimal($totalCents)],
        ];
        if ($discountCents > 0) {
            $lines[] = ['accountCode' => '4010', 'debit' => Money::decimal($discountCents)];
        }
        $lines[] = ['accountCode' => '4000', 'credit' => Money::decimal($subtotalCents)];
        if ($taxCents > 0) {
            $lines[] = ['accountCode' => '2010', 'credit' => Money::decimal($taxCents)];
        }
        if ($cogsCents > 0) {
            $lines[] = ['accountCode' => '5000', 'debit' => Money::decimal($cogsCents)];
            $lines[] = ['accountCode' => '1100', 'credit' => Money::decimal($cogsCents)];
        }

        $this->posting->postSale($request, $tenantId, [
            'branchId' => $order->branch_id,
            'sourceId' => $order->id,
            'sourceEvent' => 'POS_ORDER_PAID',
            'entryDate' => now()->toDateString(),
            'description' => "POS Sale — Order #{$order->order_number}",
            'lines' => $lines,
        ], $actorId);
    }

    private function actorId(Request $request): ?int
    {
        $auth = $request->attributes->get('auth_user');
        $id = is_array($auth) ? (int) ($auth['id'] ?? 0) : 0;

        return $id > 0 ? $id : null;
    }

    private function paymentResponse(object $row, object $payment): JsonResponse
    {
        return response()->json([
            'data' => [
                'orderId' => $row->id,
                'changeDue' => (float) Money::decimal(max(0, Money::cents($payment->amount) - Money::cents($row->total))),
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
