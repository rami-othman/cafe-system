<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\OrderLifecycleException;
use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\AccountingPostingService;
use App\Services\DiscountEligibilityService;
use App\Services\OperationalAuditService;
use App\Services\OrderLifecyclePolicy;
use App\Services\PosPricingService;
use App\Services\SaleConsumptionService;
use App\Support\TenantContext;
use App\Support\Money;
use App\Support\SalePaymentMethodResolver;
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
        private readonly AccountingPostingService $posting,
        private readonly OperationalAuditService $audit,
        private readonly SaleConsumptionService $consumption,
    ) {}

    public function summary(Request $request, int $order): JsonResponse
    {
        $data = $request->validate(['amountReceived' => ['nullable', 'numeric', 'min:0']]);
        $tenantId = TenantContext::id($request);
        $row = $this->findOrder($request, $tenantId, $order);
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
            'paymentMethodId' => ['nullable', 'integer'],
            'amount' => ['required', 'numeric', 'min:0'],
            'reference' => ['nullable', 'string'], 'note' => ['nullable', 'string'],
            'idempotencyKey' => ['required', 'string', 'max:120'],
        ]);
        $tenantId = TenantContext::id($request);
        $hash = $this->payloadHash($data);

        $actorId = (int) $request->attributes->get('auth_user')->id;
        $result = DB::transaction(function () use ($request, $tenantId, $order, $data, $hash, $actorId): array {
            $row = $this->lockedOrder($request, $tenantId, $order);
            $existing = DB::table('payments')->where('tenant_id', $tenantId)
                ->where('idempotency_key', $data['idempotencyKey'])->first();
            if ($existing) {
                if ((int) $existing->order_id !== (int) $row->id || ! hash_equals((string) $existing->idempotency_hash, $hash)) {
                    throw new OrderLifecycleException('PAYMENT_IDEMPOTENCY_CONFLICT', 'This payment key was already used for a different request.');
                }

                return ['payment' => $existing, 'total' => (float) $row->total, 'received' => (float) $data['amount']];
            }

            $this->lifecycle->assertPayable($row);
            $this->assertActorHasOpenShift($tenantId, $row, $actorId);
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

            $resolvedMethod = array_key_exists('paymentMethodId', $data) && $data['paymentMethodId'] !== null
                ? SalePaymentMethodResolver::resolveExplicit($tenantId, (int) $data['paymentMethodId'])
                : SalePaymentMethodResolver::resolveByLegacyMethod($tenantId, $data['method']);

            $currency = (string) (DB::table('branches')->where('tenant_id', $tenantId)->where('id', $row->branch_id)->whereNull('deleted_at')->value('currency') ?? 'SYP');
            $now = now();
            $paymentId = DB::table('payments')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $row->branch_id, 'order_id' => $row->id,
                'shift_id' => $row->shift_id, 'cashier_id' => $actorId, 'method' => $data['method'],
                'amount' => $row->total, 'currency' => $currency, 'status' => 'completed',
                'payment_method_id' => $resolvedMethod?->paymentMethodId,
                'idempotency_key' => $data['idempotencyKey'], 'idempotency_hash' => $hash,
                'reference_number' => $data['reference'] ?? null, 'notes' => $data['note'] ?? null,
                'paid_at' => $now, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $this->discounts->consumeUsage($tenantId, $row, $paymentId);
            DB::table('orders')->where('tenant_id', $tenantId)->where('id', $row->id)->update([
                'status' => 'paid', 'payment_status' => 'paid', 'closed_at' => $now, 'updated_at' => $now,
            ]);

            $consumption = $this->consumption->consumeForOrder($request, $tenantId, $row, $paymentId, $actorId);
            if ($resolvedMethod !== null) {
                $this->postSale($request, $tenantId, $row, $resolvedMethod, $consumption['cogsTotalCents'], $actorId);
            } else {
                $this->audit->record($request, $tenantId, 'pos_order.finance_posting_skipped', 'order', $row->id, [], ['reason' => 'No active Finance mapping for payment method.'], $row->branch_id, $actorId);
            }

            return ['payment' => DB::table('payments')->where('id', $paymentId)->first(), 'total' => (float) $row->total, 'received' => (float) $data['amount']];
        }, 3);

        return response()->json(['data' => $this->serializePayment($order, $result['payment'], $result['total'], $result['received'])]);
    }

    private function lockedOrder(Request $request, int $tenantId, int $order): object
    {
        $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->lockForUpdate()->first();
        abort_if(! $row, 404, 'Order not found.');
        app(BranchAccessService::class)->authorizeRequestBranch($request, (int) $row->branch_id);

        return $row;
    }

    private function findOrder(Request $request, int $tenantId, int $order): object
    {
        $row = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->first();
        abort_if(! $row, 404, 'Order not found.');
        app(BranchAccessService::class)->authorizeRequestBranch($request, (int) $row->branch_id);

        return $row;
    }

    private function serializePayment(int $orderId, object $payment, float $total, float $received): array
    {
        return ['orderId' => $orderId, 'changeDue' => round(max(0, $received - $total), 2), 'payment' => [
            'id' => $payment->id, 'method' => $payment->method, 'amount' => (float) $payment->amount,
            'status' => $payment->status, 'paidAt' => $payment->paid_at,
        ]];
    }

    private function assertActorHasOpenShift(int $tenantId, object $order, int $actorId): void
    {
        $hasOpenShift = $order->shift_id !== null && DB::table('shifts')
            ->where('tenant_id', $tenantId)
            ->where('id', $order->shift_id)
            ->where('branch_id', $order->branch_id)
            ->where('user_id', $actorId)
            ->where('status', 'open')
            ->whereNull('deleted_at')
            ->exists();

        if (! $hasOpenShift) {
            throw ValidationException::withMessages([
                'shiftId' => 'No open shift found. Open a shift before paying.',
            ]);
        }
    }

    private function payloadHash(array $data): string
    {
        return hash('sha256', json_encode([
            'method' => $data['method'], 'amount' => (string) $data['amount'],
            'paymentMethodId' => $data['paymentMethodId'] ?? null,
            'reference' => $data['reference'] ?? null, 'note' => $data['note'] ?? null,
        ], JSON_THROW_ON_ERROR));
    }

    private function postSale(Request $request, int $tenantId, object $order, object $method, int $cogsCents, int $actorId): void
    {
        $subtotal = Money::cents($order->subtotal);
        $discount = Money::cents($order->discount_total);
        $tax = Money::cents($order->tax_total);
        $total = Money::cents($order->total);
        $lines = [['accountCode' => $method->accountCode, 'debit' => Money::decimal($total)]];
        if ($discount > 0) {
            $lines[] = ['accountCode' => '4010', 'debit' => Money::decimal($discount)];
        }
        $lines[] = ['accountCode' => '4000', 'credit' => Money::decimal($subtotal)];
        if ($tax > 0) {
            $lines[] = ['accountCode' => '2010', 'credit' => Money::decimal($tax)];
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

    private function quickAmounts(float $total): array
    {
        $rounded = (float) (ceil($total / 5) * 5);

        return array_values(array_unique([$rounded, $rounded + 5, $rounded + 15, $total]));
    }
}
