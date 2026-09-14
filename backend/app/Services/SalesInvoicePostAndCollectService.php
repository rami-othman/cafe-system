<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

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
            $invoice = $this->posting->post($request, $tenantId, $invoiceId, $actorId, $postData);
            $payment = $this->payments->pay($request, $tenantId, $paymentData, $actorId);

            return ['invoice' => $invoice, 'payment' => $payment];
        });
    }
}
