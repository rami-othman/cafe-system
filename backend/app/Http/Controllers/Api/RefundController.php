<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\OrderLifecycleException;
use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\AccountingPostingService;
use App\Services\OperationalAuditService;
use App\Services\OrderLifecyclePolicy;
use App\Services\PosNumberGenerator;
use App\Services\PosCashLocationResolver;
use App\Support\TenantContext;
use App\Support\BranchLocalDate;
use App\Support\Money;
use App\Support\RefundTaxAllocation;
use App\Support\SalePaymentMethodResolver;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RefundController extends Controller
{
    public function __construct(
        private readonly OrderLifecyclePolicy $lifecycle,
        private readonly PosNumberGenerator $numbers,
        private readonly AccountingPostingService $posting,
        private readonly OperationalAuditService $audit,
        private readonly PosCashLocationResolver $cashLocations,
        private readonly \App\Services\PartyAccountService $partyAccounts,
        private readonly \App\Services\FinanceAccountMap $accountMap,
        private readonly \App\Services\DeliveryCompanyCustomerService $deliveryCustomers,
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

        $actorId = (int) $request->attributes->get('auth_user')->id;
        $refund = DB::transaction(function () use ($request, $tenantId, $order, $data, $hash, $actorId) {
            $orderRow = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->lockForUpdate()->first();
            abort_if(! $orderRow, 404, 'Order not found.');
            app(BranchAccessService::class)->authorizeRequestBranch($request, (int) $orderRow->branch_id);

            $existing = DB::table('payment_refunds')->where('tenant_id', $tenantId)
                ->where('idempotency_key', $data['idempotencyKey'])->first();
            if ($existing) {
                if ((int) $existing->order_id !== (int) $orderRow->id || ! hash_equals((string) $existing->idempotency_hash, $hash)) {
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

            $resolvedMethod = $payment->payment_method_id
                ? SalePaymentMethodResolver::resolveById($tenantId, (int) $payment->payment_method_id)
                : SalePaymentMethodResolver::resolveByLegacyMethod($tenantId, $payment->method);
            if (($resolvedMethod?->type === 'cash' || ($resolvedMethod === null && $payment->method === 'cash'))
                && $payment->shift_id !== null) {
                $saleShift = DB::table('shifts')->where('tenant_id', $tenantId)
                    ->where('id', $payment->shift_id)->lockForUpdate()->first();
                if ($saleShift && $saleShift->status !== 'open') {
                    throw new OrderLifecycleException('CASH_REFUND_SHIFT_CLOSED', 'رد النقد بعد إغلاق وردية البيع يحتاج إجراء صرف معتمداً.');
                }
            }

            // A cashier can refund (reverse) only a sale taken in their own still-open shift; managers and owners are not limited.
            $role = app(\App\Services\DefaultTenantRoleService::class)->canonicalLegacyRole(\App\Support\FinanceAccess::actor($request)->effectiveRoleCode());
            if ($role === 'cashier') {
                $ownOpenShift = $payment->shift_id !== null && DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $payment->shift_id)
                    ->where('user_id', $actorId)->where('status', 'open')->whereNull('deleted_at')->exists();
                if (! $ownOpenShift) {
                    throw new OrderLifecycleException('REFUND_OWN_OPEN_SHIFT_ONLY', 'يمكنك عكس مبيعات ورديتك المفتوحة فقط.');
                }
            }

            $now = now();
            $refundId = DB::table('payment_refunds')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $orderRow->branch_id, 'order_id' => $orderRow->id,
                'payment_id' => $payment->id, 'shift_id' => $payment->shift_id, 'refund_number' => $this->numbers->nextRefundNumber($tenantId),
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
                'user_id' => $actorId, 'entity_type' => 'order', 'entity_id' => $orderRow->id,
                'description' => "مرتجع بقيمة {$amount} بسبب {$data['reason']}.", 'created_at' => $now, 'updated_at' => $now,
            ]);

            // A payment refund contains no item/restock detail, so it must
            // reverse the financial settlement only. Creating stock movements
            // here would invent an inventory event and risk double reversal.
            $amountCents = Money::cents((string) $amount);
            $taxCents = RefundTaxAllocation::taxCents(
                Money::cents($orderRow->total),
                Money::cents($orderRow->tax_total),
                Money::cents((string) $alreadyRefunded),
                $amountCents,
            );
            if ($resolvedMethod !== null) {
                $cashLocationId = $payment->method === 'cash' && $resolvedMethod->type === 'cash'
                    ? $this->cashLocations->forRefund($tenantId, $orderRow, $payment, $resolvedMethod->accountCode)
                    : null;
                $walletParty = $resolvedMethod->type === 'wallet'
                    ? $this->partyAccounts->codeForOrderCustomer($tenantId, $orderRow->customer_id, $actorId)
                    : null;
                // A wallet refund goes back to the customer's own account, not to a shared placeholder.
                $settlementLine = ['accountCode' => $walletParty ?? $resolvedMethod->accountCode, 'credit' => Money::decimal($amountCents)];
                if ($cashLocationId !== null) {
                    $settlementLine['financialLocationId'] = $cashLocationId;
                } elseif ($resolvedMethod->type === 'sham_cash' && ($resolvedMethod->financialLocationId ?? null) !== null) {
                    $settlementLine['financialLocationId'] = $resolvedMethod->financialLocationId;
                }
                $this->posting->postRefund($request, $tenantId, [
                    'branchId' => $orderRow->branch_id,
                    'sourceId' => $refundId,
                    'sourceEvent' => 'PAYMENT_REFUNDED',
                    'entryDate' => BranchLocalDate::today($orderRow->branch_id ? (int) $orderRow->branch_id : null),
                    'description' => "مرتجع — {$data['reason']}",
                    'lines' => array_values(array_filter([
                        $amountCents > $taxCents ? ['accountCode' => $this->accountMap->code($tenantId, 'sales.sales_returns'), 'debit' => Money::decimal($amountCents - $taxCents)] : null,
                        $taxCents > 0 ? ['accountCode' => $this->accountMap->code($tenantId, 'sales.tax_payable'), 'debit' => Money::decimal($taxCents)] : null,
                        $settlementLine,
                        ...($walletParty === null ? $this->partyRefundLines($tenantId, $orderRow, $amountCents, $actorId) : []),
                        ...($resolvedMethod->type !== 'delivery_app' ? $this->deliveryRefundLines($tenantId, $orderRow, $amountCents) : []),
                    ])),
                ], $actorId);
            } else {
                $this->audit->record($request, $tenantId, 'payment_refund.finance_posting_skipped', 'order', $orderRow->id, [], ['reason' => 'No active Finance mapping for the original payment method.'], $orderRow->branch_id, $actorId);
            }

            return DB::table('payment_refunds')->where('tenant_id', $tenantId)->where('id', $refundId)->first();
        }, 3);

        return response()->json(['data' => $this->serialize($refund)], 201);
    }

    /** Mirror of the sale: a cash delivery order's refund also appears on the delivery company's account (net zero). */
    private function deliveryRefundLines(int $tenantId, object $order, int $amountCents): array
    {
        $code = $this->deliveryCustomers->accountCodeForOrder($tenantId, $order);
        if ($code === null) {
            return [];
        }

        return [
            ['accountCode' => $code, 'credit' => Money::decimal($amountCents), 'description' => "مرتجع توصيل — طلب رقم {$order->order_number}"],
            ['accountCode' => $code, 'debit' => Money::decimal($amountCents), 'description' => "رد المبلغ نقداً — طلب رقم {$order->order_number}"],
        ];
    }

    /** Mirror of the sale: the refund also appears on the customer's own account (net zero). */
    private function partyRefundLines(int $tenantId, object $order, int $amountCents, int $actorId): array
    {
        $code = $this->partyAccounts->codeForOrderCustomer($tenantId, $order->customer_id, $actorId);
        if ($code === null) {
            return [];
        }

        return [
            ['accountCode' => $code, 'credit' => Money::decimal($amountCents), 'description' => "مرتجع — طلب رقم {$order->order_number}"],
            ['accountCode' => $code, 'debit' => Money::decimal($amountCents), 'description' => "رد المبلغ — طلب رقم {$order->order_number}"],
        ];
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
