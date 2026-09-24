<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Support\Money;
use App\Support\IdempotencyFingerprint;
use Illuminate\Validation\ValidationException;

/**
 * "ترحيل وتسجيل دفعة" (§31) — UX orchestration only. It never merges the
 * two accounting events: SalesInvoicePostingService still posts Dr AR / Cr
 * revenue+tax(+Dr COGS/Cr inventory) and CustomerPaymentService still posts
 * its own, separate Dr cash/bank / Cr AR settlement journal. Wrapping both
 * calls in one outer transaction only means either both business effects
 * land or neither does — a stock/mapping failure during invoice posting
 * must not leave an orphaned customer payment, and a bad settlement account
 * on the payment must not leave the invoice half-collected. Laravel nests
 * this transaction as a savepoint around each service's own DB::transaction,
 * so a failure anywhere rolls back invoice posting, the payment, both
 * journals and both sets of allocations/movements together.
 */
final class SalesInvoicePostAndCollectService
{
    public function __construct(
        private readonly SalesInvoicePostingService $posting,
        private readonly CustomerPaymentService $payments,
    ) {}

    /** @return array{invoice:object,payment:object} */
    public function postAndCollect(Request $request, int $tenantId, int $invoiceId, int $actorId, array $postData, array $paymentData): array
    {
        return DB::transaction(function () use ($request, $tenantId, $invoiceId, $actorId, $postData, $paymentData): array {
            $locked = DB::table('sales_invoices')->where('tenant_id', $tenantId)
                ->where('id', $invoiceId)->lockForUpdate()->first();
            abort_unless($locked, 404, 'Sales invoice not found.');
            $customer = DB::table('customers')->where('tenant_id', $tenantId)
                ->where('id', $locked->customer_id)->whereNull('deleted_at')->first();
            abort_unless($customer, 422, 'العميل غير متاح.');
            if ($customer->is_walk_in) {
                $existing = DB::table('customer_payments')->where('tenant_id', $tenantId)
                    ->where('direct_sales_invoice_id', $invoiceId)->first();
                if ($existing) {
                    $posting = DB::table('sales_invoice_postings')->where('tenant_id', $tenantId)
                        ->where('sales_invoice_id', $invoiceId)->first();
                    if ($existing->idempotency_key !== $paymentData['idempotencyKey']
                        || $posting?->idempotency_key !== $postData['idempotencyKey']
                        || ! hash_equals((string) $existing->idempotency_fingerprint, IdempotencyFingerprint::from($paymentData))
                        || ! hash_equals((string) $posting->request_fingerprint, IdempotencyFingerprint::from($postData))) {
                        throw ValidationException::withMessages(['idempotencyKey' => 'هذه الفاتورة النقدية رُحّلت بدفعة أخرى.']);
                    }
                    return ['invoice' => $locked, 'payment' => $existing];
                }
                if ($locked->status !== 'draft') {
                    throw ValidationException::withMessages(['status' => 'الفاتورة النقدية المرحّلة لا تقبل دفعة ثانية.']);
                }
                if (Money::cents($paymentData['amount']) !== Money::cents($locked->total)
                    || Money::cents($locked->total) <= 0) {
                    throw ValidationException::withMessages(['amount' => 'يجب دفع كامل إجمالي الفاتورة النقدية دون زيادة أو نقص.']);
                }
                if ($paymentData['paymentDate'] !== $locked->invoice_date) {
                    throw ValidationException::withMessages(['paymentDate' => 'تاريخ الدفع النقدي المباشر يجب أن يساوي تاريخ الفاتورة؛ احفظها كمسودة إذا كان التحصيل لاحقاً.']);
                }
                [$method, $location, $shift] = $this->payments->directSaleSource(
                    $tenantId, $actorId, (int) $locked->branch_id, $paymentData,
                );
                $invoice = $this->posting->post($request, $tenantId, $invoiceId, $actorId, $postData,
                    ['accountCode' => $location->account_code, 'locationId' => (int) $location->id]);
                $payment = $this->payments->recordDirectSale($tenantId, $invoice, $actorId,
                    $paymentData, $method, $location, $shift);
            } else {
                $invoice = $this->posting->post($request, $tenantId, $invoiceId, $actorId, $postData);
                $payment = $this->payments->pay($request, $tenantId, $paymentData, $actorId);
            }

            return ['invoice' => $invoice, 'payment' => $payment];
        });
    }
}
