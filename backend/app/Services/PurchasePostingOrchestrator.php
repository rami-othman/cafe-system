<?php

namespace App\Services;

use App\Domain\Purchasing\PurchaseReceivingService;
use App\Support\BranchLocalDate;
use App\Support\FinanceAccess;
use App\Support\InventoryDecimal;
use App\Support\Money;
use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Atomically posts, receives (when applicable), pays, and vouchers a purchase. */
final class PurchasePostingOrchestrator
{
    public function __construct(
        private readonly SupplierInvoiceService $invoices,
        private readonly PurchaseReceivingService $receiving,
        private readonly SupplierPaymentService $payments,
        private readonly FinanceDocumentService $documents,
        private readonly PurchaseCashSourceResolver $cashSources,
        private readonly SupplierPayableQueryService $payable,
        private readonly OperationalAuditService $audit,
    ) {}

    public function preview(Request $request, int $tenantId, int $invoiceId, int $actorId, ?int $selectedLocationId = null): array
    {
        $this->authorize($request, $tenantId, $invoiceId);
        $invoice = $this->invoice($tenantId, $invoiceId);
        $branchId = $this->requiredBranchId($invoice);
        $mode = $this->cashSources->mode($tenantId, $actorId);
        if ($mode === 'selectable' && $selectedLocationId === null) {
            return ['invoiceId' => $invoiceId, 'amount' => Money::decimal($this->payable->invoiceRemainingCents($tenantId, $invoiceId)),
                'branchId' => $branchId, 'financialLocationId' => null, 'financialLocationName' => null,
                'shiftId' => null, 'shiftNumber' => null, 'cashSourceMode' => $mode,
                'allowedCashLocations' => $this->cashSources->allowedLocations($tenantId, $actorId, $branchId)];
        }
        $source = $this->cashSources->resolve($tenantId, $actorId, $branchId, selectedLocationId: $selectedLocationId);

        return $this->summary($invoice, $source, $this->payable->invoiceRemainingCents($tenantId, $invoiceId))
            + ['cashSourceMode' => $mode, 'allowedCashLocations' => $mode === 'selectable' ? $this->cashSources->allowedLocations($tenantId, $actorId, $branchId) : []];
    }

    public function post(Request $request, int $tenantId, int $invoiceId, string $key, int $actorId, ?int $selectedLocationId = null, ?string $paidAmount = null, ?string $paymentDate = null, ?string $receiptDate = null): object
    {
        $this->authorize($request, $tenantId, $invoiceId, $paidAmount === null || Money::cents($paidAmount, 'paidAmount') > 0);

        return DB::transaction(function () use ($request, $tenantId, $invoiceId, $key, $actorId, $selectedLocationId, $paidAmount, $paymentDate, $receiptDate): object {
            $invoice = $this->invoice($tenantId, $invoiceId, true);
            $wasDraft = $invoice->status === 'draft';
            $branchId = $this->requiredBranchId($invoice);
            $existingPayment = DB::table('supplier_payments')->where('tenant_id', $tenantId)
                ->where('idempotency_key', "purchase-post:{$invoiceId}:payment")->first();
            if ($existingPayment) {
                return $this->result($tenantId, $invoiceId, (int) $existingPayment->id);
            }
            if ($invoice->status !== 'draft' && $invoice->posting_idempotency_key === "purchase-post:{$invoiceId}:invoice") {
                return $this->result($tenantId, $invoiceId, null);
            }
            $remainingBeforePost = $this->payable->invoiceRemainingCents($tenantId, $invoiceId);
            $paymentCents = $paidAmount === null ? $remainingBeforePost : Money::cents($paidAmount, 'paidAmount');
            if ($paymentCents > $remainingBeforePost) {
                throw ValidationException::withMessages(['paidAmount' => 'Payment exceeds the outstanding invoice amount.']);
            }

            $source = $paymentCents > 0
                ? $this->cashSources->resolve($tenantId, $actorId, $branchId, lock: true, selectedLocationId: $selectedLocationId)
                : null;
            if ($invoice->status === 'draft') {
                $invoice = $this->invoices->post($request, $tenantId, $invoiceId, [
                    'idempotencyKey' => "purchase-post:{$invoiceId}:invoice",
                ], $actorId);
                $this->audit->record($request, $tenantId, 'purchase_invoice.posted', 'supplier_invoice', $invoiceId, [], [
                    'idempotencyKey' => $key,
                ], $branchId, $actorId);
            } elseif (! in_array($invoice->status, ['posted', 'partially_paid'], true)) {
                throw ValidationException::withMessages(['status' => 'فاتورة الشراء ليست متاحة للترحيل والدفع.']);
            }

            if ($invoice->receipt_mode === 'immediate' || ($invoice->receipt_mode === null && $wasDraft)) {
                $this->receiveRemainingInventory($request, $tenantId, $invoice, $actorId, $receiptDate ?? BranchLocalDate::today($branchId));
            }

            if ($paymentCents === 0) {
                return $this->result($tenantId, $invoiceId, null);
            }

            $remaining = $this->payable->invoiceRemainingCents($tenantId, $invoiceId, lock: true);
            if ($remaining < $paymentCents) {
                throw ValidationException::withMessages(['payment' => 'فاتورة الشراء مدفوعة بالكامل بالفعل.']);
            }
            $payment = $this->payments->pay($request, $tenantId, [
                'supplierId' => (int) $invoice->supplier_id,
                'branchId' => $branchId,
                'paymentDate' => $paymentDate ?? BranchLocalDate::today($branchId),
                'amount' => Money::decimal($paymentCents),
                'paymentMethodId' => (int) $source->method->id,
                'financialLocationId' => (int) $source->location->id,
                'shiftId' => $source->shift ? (int) $source->shift->id : null,
                'externalReference' => $invoice->internal_reference,
                'notes' => "دفع تلقائي لفاتورة الشراء {$invoice->internal_reference}",
                'idempotencyKey' => "purchase-post:{$invoiceId}:payment",
                'allocations' => [['invoiceId' => $invoiceId, 'amount' => Money::decimal($paymentCents)]],
            ], $actorId, $source);

            $voucher = $this->documents->createPostedSupplierPaymentVoucher(
                $request, $tenantId, $payment, $invoice,
                $source->shift ? (int) $source->shift->id : null,
                $actorId,
            );
            DB::table('supplier_payments')->where('tenant_id', $tenantId)->where('id', $payment->id)->update([
                'finance_document_id' => $voucher->id,
                'updated_at' => now(),
            ]);

            $this->audit->record($request, $tenantId, 'purchase.auto_paid', 'supplier_invoice', $invoiceId, [], [
                'paymentId' => (int) $payment->id,
                'voucherId' => (int) $voucher->id,
                'shiftId' => $source->shift ? (int) $source->shift->id : null,
                'financialLocationId' => (int) $source->location->id,
                'amount' => Money::decimal($paymentCents),
            ], $branchId, $actorId);

            return $this->result($tenantId, $invoiceId, (int) $payment->id);
        }, 3);
    }

    private function receiveRemainingInventory(Request $request, int $tenantId, object $invoice, int $actorId, string $receiptDate): void
    {
        $lines = DB::table('supplier_invoice_lines')->where('tenant_id', $tenantId)
            ->where('supplier_invoice_id', $invoice->id)->where('line_type', 'inventory')
            ->orderBy('id')->lockForUpdate()->get();
        if ($lines->isEmpty()) {
            return;
        }
        if ($lines->every(fn (object $line): bool => InventoryDecimal::units($line->received_quantity) >= InventoryDecimal::units($line->base_quantity))) {
            return;
        }

        $receiptLines = [];
        foreach ($lines as $line) {
            $remainingBase = BigDecimal::of($line->base_quantity)->minus($line->received_quantity);
            if ($remainingBase->isLessThanOrEqualTo(0)) {
                continue;
            }
            $quantity = $remainingBase->dividedBy($line->conversion_factor, 3, RoundingMode::UNNECESSARY);
            $receiptLines[] = [
                'supplierInvoiceLineId' => (int) $line->id,
                'quantity' => (string) $quantity,
                'warehouseId' => $line->warehouse_id ? (int) $line->warehouse_id : null,
            ];
        }
        $receipt = $this->receiving->create($request, $tenantId, (int) $invoice->id, [
            'receiptDate' => $receiptDate,
            'reference' => $invoice->internal_reference,
            'notes' => 'استلام تلقائي عند ترحيل فاتورة الشراء',
            'idempotencyKey' => "purchase-post:{$invoice->id}:receipt",
            'lines' => $receiptLines,
        ], $actorId);
        $this->receiving->post($request, $tenantId, (int) $receipt->id, [
            'idempotencyKey' => "purchase-post:{$invoice->id}:receipt-post",
        ], $actorId);
        $this->audit->record($request, $tenantId, 'inventory.received', 'supplier_invoice', (int) $invoice->id, [], [
            'receiptId' => (int) $receipt->id,
        ], $invoice->branch_id ? (int) $invoice->branch_id : null, $actorId);
    }

    private function authorize(Request $request, int $tenantId, int $invoiceId, bool $requiresPayment = true): void
    {
        FinanceAccess::authorize($request, 'finance.purchases.post');
        if ($requiresPayment) {
            FinanceAccess::authorize($request, 'finance.vouchers.create');
            FinanceAccess::authorize($request, 'finance.vouchers.post');
        }
        $hasInventory = DB::table('supplier_invoice_lines')->where('tenant_id', $tenantId)
            ->where('supplier_invoice_id', $invoiceId)->where('line_type', 'inventory')->exists();
        if ($hasInventory) {
            FinanceAccess::authorize($request, 'finance.purchases.receive');
        }
    }

    private function invoice(int $tenantId, int $id, bool $lock = false): object
    {
        $query = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at');
        if ($lock) {
            $query->lockForUpdate();
        }
        $invoice = $query->first();
        abort_unless($invoice, 404, 'Purchase invoice not found.');

        return $invoice;
    }

    private function requiredBranchId(object $invoice): int
    {
        if (! $invoice->branch_id) {
            throw ValidationException::withMessages(['branchId' => 'يجب تحديد فرع لفاتورة الشراء قبل الترحيل.']);
        }

        return (int) $invoice->branch_id;
    }

    private function summary(object $invoice, object $source, int $amountCents): array
    {
        return [
            'invoiceId' => (int) $invoice->id,
            'amount' => Money::decimal($amountCents),
            'branchId' => (int) $invoice->branch_id,
            'financialLocationId' => (int) $source->location->id,
            'financialLocationName' => $source->location->name,
            'shiftId' => $source->shift ? (int) $source->shift->id : null,
            'shiftNumber' => $source->shift?->shift_number,
        ];
    }

    private function result(int $tenantId, int $invoiceId, ?int $paymentId): object
    {
        $invoice = $this->invoice($tenantId, $invoiceId);
        $payment = $paymentId === null ? null : DB::table('supplier_payments')->where('tenant_id', $tenantId)->where('id', $paymentId)->first();
        $voucher = $paymentId === null ? null : DB::table('finance_documents')->where('tenant_id', $tenantId)->where('source_type', 'supplier_payment')->where('source_id', $paymentId)->first();

        return (object) ['invoice' => $invoice, 'payment' => $payment, 'voucher' => $voucher];
    }
}
