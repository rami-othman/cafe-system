<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AccountingPostingService;
use App\Services\OperationalAuditService;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use App\Support\SalePaymentMethodResolver;
use App\Support\TenantContext;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class RefundController extends Controller
{
    public function __construct(
        private readonly AccountingPostingService $posting,
        private readonly OperationalAuditService $audit,
    ) {}

    public function store(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:full,partial'],
            'amount' => ['nullable', 'numeric', 'min:0.01'],
            'reason' => ['required', 'string', 'max:120'],
            'managerNotes' => ['nullable', 'string'],
            'idempotencyKey' => ['nullable', 'string', 'max:120'],
        ]);

        $tenantId = TenantContext::id($request);
        $orderRow = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->whereNull('deleted_at')->first();
        abort_if(! $orderRow, 404, 'Order not found.');
        abort_if($orderRow->payment_status === 'unpaid', 422, 'Only paid orders can be refunded.');

        $key = $data['idempotencyKey'] ?? null;
        $fingerprint = $key === null ? null : IdempotencyFingerprint::from([...$data, 'orderId' => $order]);
        if ($key !== null) {
            $existing = $this->refundByIdempotencyKey($tenantId, $key);
            if ($existing !== null) {
                $this->assertMatchingIdempotencyRequest($existing, $fingerprint);

                return $this->refundResponse($existing);
            }
        }

        $actorId = $this->actorId($request);

        try {
            $refund = DB::transaction(function () use ($request, $tenantId, $orderRow, $data, $key, $fingerprint, $actorId) {
                if ($key !== null) {
                    $existing = $this->refundByIdempotencyKey($tenantId, $key, true);
                    if ($existing !== null) {
                        $this->assertMatchingIdempotencyRequest($existing, $fingerprint);

                        return $existing;
                    }
                }

                // Lock the payment row first: every concurrent refund attempt
                // against this order serializes on this lock, so the
                // already-refunded sum read immediately below is always
                // read fresh relative to any refund committed just before it.
                // (An aggregate SUM(...) query cannot itself carry FOR UPDATE
                // on this project's database, so the parent row is the lock
                // point, matching the pattern InventoryPostingService uses
                // for stock_balances.)
                $payment = DB::table('payments')
                    ->where('tenant_id', $tenantId)
                    ->where('order_id', $orderRow->id)
                    ->where('status', 'completed')
                    ->whereNull('deleted_at')
                    ->latest('paid_at')
                    ->lockForUpdate()
                    ->first();
                abort_if(! $payment, 422, 'No completed payment exists for this order.');

                $alreadyRefundedCents = Money::cents(DB::table('payment_refunds')
                    ->where('tenant_id', $tenantId)
                    ->where('payment_id', $payment->id)
                    ->where('status', 'completed')
                    ->sum('amount'));
                $remainingCents = Money::cents($payment->amount) - $alreadyRefundedCents;
                $amountCents = $data['type'] === 'full' ? $remainingCents : Money::cents($data['amount'] ?? '0');

                if ($amountCents <= 0 || $amountCents > $remainingCents) {
                    throw ValidationException::withMessages(['amount' => 'Refund amount exceeds the refundable balance.']);
                }

                $now = now();
                $refundId = DB::table('payment_refunds')->insertGetId([
                    'tenant_id' => $tenantId,
                    'branch_id' => $orderRow->branch_id,
                    'order_id' => $orderRow->id,
                    'payment_id' => $payment->id,
                    'shift_id' => $payment->shift_id,
                    'refund_number' => $this->nextRefundNumber($tenantId),
                    'type' => $data['type'],
                    'amount' => Money::decimal($amountCents),
                    'reason' => $data['reason'],
                    'manager_notes' => $data['managerNotes'] ?? null,
                    'status' => 'completed',
                    'idempotency_key' => $key,
                    'idempotency_fingerprint' => $fingerprint,
                    'refunded_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $paymentStatus = $amountCents >= $remainingCents ? 'refunded' : 'partially_refunded';
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
                    'description' => 'Refunded $'.Money::decimal($amountCents)." for {$data['reason']}.",
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                // Preserve the real destination the original payment used —
                // never assume Cash. This is a real refund transaction with
                // its own source-linked journal, not a JournalEntryService
                // reversal (that stays reserved for correcting erroneous
                // entries, see docs/finance §19). No inventory is returned
                // here: `payment_refunds` carries no restock/item metadata,
                // so fabricating a stock-in would be inventing data the
                // business flow never actually captured (see docs/finance §18).
                $resolvedMethod = $payment->payment_method_id
                    ? SalePaymentMethodResolver::resolveById($tenantId, (int) $payment->payment_method_id)
                    : SalePaymentMethodResolver::resolveByLegacyMethod($tenantId, $payment->method);

                if ($resolvedMethod !== null) {
                    $this->posting->postRefund($request, $tenantId, [
                        'branchId' => $orderRow->branch_id,
                        'sourceId' => $refundId,
                        'sourceEvent' => 'PAYMENT_REFUNDED',
                        'entryDate' => now()->toDateString(),
                        'description' => "Refund — {$data['reason']}",
                        'lines' => [
                            ['accountCode' => '4020', 'debit' => Money::decimal($amountCents)],
                            ['accountCode' => $resolvedMethod->accountCode, 'credit' => Money::decimal($amountCents)],
                        ],
                    ], $actorId);
                } else {
                    $this->audit->record($request, $tenantId, 'payment_refund.finance_posting_skipped', 'order', $orderRow->id, [], ['reason' => 'No active Finance mapping for the original payment\'s method "'.$payment->method.'".'], $orderRow->branch_id, $actorId);
                }

                return DB::table('payment_refunds')->where('tenant_id', $tenantId)->where('id', $refundId)->first();
            });
        } catch (QueryException $exception) {
            if ($key !== null && ($existing = $this->refundByIdempotencyKey($tenantId, $key)) !== null) {
                $this->assertMatchingIdempotencyRequest($existing, $fingerprint);

                return $this->refundResponse($existing);
            }
            throw $exception;
        }

        return $this->refundResponse($refund, 201);
    }

    private function refundByIdempotencyKey(int $tenantId, string $key, bool $lock = false): ?object
    {
        $query = DB::table('payment_refunds')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    private function assertMatchingIdempotencyRequest(object $existing, ?string $fingerprint): void
    {
        abort_if($fingerprint === null || empty($existing->idempotency_fingerprint) || ! hash_equals((string) $existing->idempotency_fingerprint, $fingerprint), 409, 'This idempotency key was already used for a different request.');
    }

    private function refundResponse(object $refund, int $status = 200): JsonResponse
    {
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
        ], $status);
    }

    private function nextRefundNumber(int $tenantId): string
    {
        $count = DB::table('payment_refunds')->where('tenant_id', $tenantId)->count() + 1;

        return 'RF-'.now()->format('Ymd').'-'.str_pad((string) $count, 4, '0', STR_PAD_LEFT);
    }

    private function actorId(Request $request): ?int
    {
        $auth = $request->attributes->get('auth_user');
        $id = is_array($auth) ? (int) ($auth['id'] ?? 0) : 0;

        return $id > 0 ? $id : null;
    }
}
