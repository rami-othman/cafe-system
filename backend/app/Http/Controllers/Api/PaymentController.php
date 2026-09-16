<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\OrderLifecycleException;
use App\Http\Controllers\Controller;
use App\Services\AccountingPostingService;
use App\Services\BranchAccessService;
use App\Services\DiscountEligibilityService;
use App\Services\OperationalAuditService;
use App\Services\OrderLifecyclePolicy;
use App\Services\PosPricingService;
use App\Services\SaleConsumptionService;
use App\Support\Money;
use App\Support\PaymentPerformanceProbe;
use App\Support\SalePaymentMethodResolver;
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
        private readonly AccountingPostingService $posting,
        private readonly OperationalAuditService $audit,
        private readonly SaleConsumptionService $consumption,
        private readonly PaymentPerformanceProbe $performance,
    ) {}

    public function summary(Request $request, int $order): JsonResponse
    {
        $data = $request->validate(['amountReceived' => ['nullable', 'numeric', 'min:0']]);
        $tenantId = TenantContext::id($request);
        $row = $this->findOrder($request, $tenantId, $order);
        $itemCount = (float) DB::table('order_items')->where('tenant_id', $tenantId)->where('order_id', $order)->whereNull('deleted_at')->sum('quantity');
        $total = (float) $row->total;
        $paymentStatus = (string) $row->payment_status;
        $orderStatus = (string) $row->status;
        $completedPaymentExists = DB::table('payments')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $order)
            ->where('status', 'completed')
            ->whereNull('deleted_at')
            ->exists();
        $outstandingAmount = $completedPaymentExists
            ? 0.0
            : max(0, round($total, 2));
        $received = array_key_exists('amountReceived', $data) ? (float) $data['amountReceived'] : $total;
        $actorId = (int) $request->attributes->get('auth_user')->id;
        $hasOpenShift = $row->shift_id !== null && DB::table('shifts')
            ->where('tenant_id', $tenantId)
            ->where('id', $row->shift_id)
            ->where('branch_id', $row->branch_id)
            ->where('user_id', $actorId)
            ->where('status', 'open')
            ->whereNull('deleted_at')
            ->exists();
        $lifecycleCanPay = $this->lifecycle->canPay($row);
        $warehouseBlocker = $lifecycleCanPay
            ? $this->consumption->preflightWarehouseConfiguration($tenantId, $row)
            : null;
        $methods = DB::table('payment_methods as pm')
            ->join('financial_accounts as accounts', 'accounts.id', '=', 'pm.financial_account_id')
            ->where('pm.tenant_id', $tenantId)->where('pm.is_active', true)
            ->where('accounts.tenant_id', $tenantId)->where('accounts.is_active', true)->whereNull('accounts.deleted_at')
            ->whereIn('pm.type', ['cash', 'card'])
            ->orderBy('pm.sort_order')->orderBy('pm.id')->pluck('pm.type')
            ->unique()->values();
        $canPay = $lifecycleCanPay &&
            ! $completedPaymentExists &&
            $outstandingAmount > 0 &&
            $hasOpenShift &&
            $methods->isNotEmpty() &&
            $warehouseBlocker === null;
        $blockedReason = $canPay
            ? null
            : ($completedPaymentExists || $paymentStatus === 'paid'
                ? 'A completed payment already exists for this order.'
                : ($warehouseBlocker['reason'] ?? (! $hasOpenShift
                    ? 'No open shift found. Open a shift before paying.'
                    : ($methods->isEmpty()
                        ? 'No supported payment method is available for this order.'
                        : 'This order cannot be paid in its current state.'))));
        $blockerCode = $canPay ? null : ($warehouseBlocker['code'] ?? null);

        return response()->json(['data' => [
            'orderId' => $row->id, 'orderNumber' => $row->order_number, 'totalDue' => $total,
            'outstandingAmount' => $outstandingAmount, 'itemCount' => $itemCount,
            'orderStatus' => $orderStatus, 'paymentStatus' => $paymentStatus,
            'canPay' => $canPay, 'blockedReason' => $blockedReason,
            'blockerCode' => $blockerCode,
            'completedPaymentExists' => $completedPaymentExists,
            'amountReceived' => $received,
            'changeDue' => round(max(0, $received - $total), 2),
            'methods' => $methods, 'quickAmounts' => $this->quickAmounts($total),
        ]]);
    }

    public function pay(Request $request, int $order): JsonResponse
    {
        $this->performance->controllerStarted();
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
        $transactionStarted = microtime(true);
        $closureEndedAt = null;
        $result = DB::transaction(function () use ($request, $tenantId, $order, $data, $hash, $actorId, &$closureEndedAt): array {
            $row = $this->performance->measure('order locking', fn () => $this->lockedOrder($request, $tenantId, $order));
            $existing = DB::table('payments')->where('tenant_id', $tenantId)
                ->where('idempotency_key', $data['idempotencyKey'])->first();
            if ($existing) {
                if ((int) $existing->order_id !== (int) $row->id || ! hash_equals((string) $existing->idempotency_hash, $hash)) {
                    throw new OrderLifecycleException('PAYMENT_IDEMPOTENCY_CONFLICT', 'This payment key was already used for a different request.');
                }

                return ['payment' => $existing, 'total' => (float) $row->total, 'received' => (float) $data['amount']];
            }

            // A configured payment method is authoritative for both Discount
            // eligibility and Finance posting. The legacy method remains a
            // compatibility selector only when no paymentMethodId is supplied.
            $resolvedMethod = array_key_exists('paymentMethodId', $data) && $data['paymentMethodId'] !== null
                ? SalePaymentMethodResolver::resolveExplicit($tenantId, (int) $data['paymentMethodId'])
                : SalePaymentMethodResolver::resolveByLegacyMethod($tenantId, $data['method']);
            if ($resolvedMethod === null) {
                throw new OrderLifecycleException('PAYMENT_METHOD_INVALID', 'The selected payment method is not active or has no valid Finance account mapping.');
            }
            if ($resolvedMethod->type !== $data['method']) {
                throw ValidationException::withMessages(['paymentMethodId' => 'The selected payment method does not match method.']);
            }

            $this->lifecycle->assertPayable($row);
            $this->performance->measure('shift validation', fn () => $this->assertActorHasOpenShift($tenantId, $row, $actorId));
            if (DB::table('payments')->where('tenant_id', $tenantId)->where('order_id', $row->id)->where('status', 'completed')->whereNull('deleted_at')->exists()) {
                throw new OrderLifecycleException('PAYMENT_ALREADY_COMPLETED', 'A completed payment already exists for this order.');
            }
            $row = $this->consumption->bindLegacyOrderWarehouse($tenantId, $row);
            // Apply-time deliberately defers tender validation. Payment is the
            // authoritative second stage, including revalidation after a
            // manager changes a policy or its schedule expires.
            if (DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $row->id)->whereNotNull('discount_id')->exists()) {
                $row = $this->pricing->recalculateOrder($tenantId, $row->id, true, $resolvedMethod->paymentMethodId, $resolvedMethod->type);
            }
            if ((float) $data['amount'] < (float) $row->total) {
                throw ValidationException::withMessages(['amount' => 'Payment amount is less than order total.']);
            }

            $currency = (string) (DB::table('branches')->where('tenant_id', $tenantId)->where('id', $row->branch_id)->whereNull('deleted_at')->value('currency') ?? 'SYP');
            $now = now();
            $persistenceStarted = $this->performance->start('payment persistence');
            $paymentId = DB::table('payments')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $row->branch_id, 'order_id' => $row->id,
                'shift_id' => $row->shift_id, 'cashier_id' => $actorId, 'method' => $resolvedMethod->type,
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
            $this->performance->stop('payment persistence', $persistenceStarted);

            $consumption = $this->consumption->consumeForOrder($request, $tenantId, $row, $paymentId, $actorId);
            $this->performance->measure('accounting posting', fn () => $this->postSale($request, $tenantId, $row, $resolvedMethod, $consumption['cogsTotalCents'], $actorId));

            $answer = ['payment' => DB::table('payments')->where('id', $paymentId)->first(), 'total' => (float) $row->total, 'received' => (float) $data['amount']];
            $closureEndedAt = microtime(true);

            return $answer;
        }, 3);
        $this->performance->stop('transaction commit', $closureEndedAt ?? $transactionStarted);

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
            'status' => $payment->status, 'reference' => $payment->reference_number,
            'idempotencyKey' => $payment->idempotency_key, 'paidAt' => $payment->paid_at,
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
