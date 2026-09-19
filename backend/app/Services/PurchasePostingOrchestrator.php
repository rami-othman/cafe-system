<?php

namespace App\Services;

use App\Domain\Purchasing\PurchaseReceivingService;
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

    public function preview(Request $request, int $tenantId, int $invoiceId, int $actorId): array
    {
        $this->authorize($request, $tenantId, $invoiceId);
        $invoice = $this->invoice($tenantId, $invoiceId);
        $branchId = $this->requiredBranchId($invoice);
        $source = $this->cashSources->resolve($tenantId, $actorId, $branchId);

        return $this->summary($invoice, $source, $this->payable->invoiceRemainingCents($tenantId, $invoiceId));
    }

    public function post(Request $request, int $tenantId, int $invoiceId, string $key, int $actorId): object
    {
        $this->authorize($request, $tenantId, $invoiceId);

        return DB::transaction(function () use ($request, $tenantId, $invoiceId, $key, $actorId): object {
            $invoice = $this->invoice($tenantId, $invoiceId, true);
            $branchId = $this->requiredBranchId($invoice);

            $existingPayment = DB::table('supplier_payments')->where('tenant_id', $tenantId)
                ->where('idempotency_key', "purchase-post:{$invoiceId}:payment")->first();
            if ($existingPayment) {
                return $this->result($tenantId, $invoiceId, (int) $existingPayment->id);
            }

            $source = $this->cashSources->resolve($tenantId, $actorId, $branchId, lock: true);
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

            $this->receiveRemainingInventory($request, $tenantId, $invoice, $actorId);

            $remaining = $this->payable->invoiceRemainingCents($tenantId, $invoiceId, lock: true);
            if ($remaining <= 0) {
                throw ValidationException::withMessages(['payment' => 'فاتورة الشراء مدفوعة بالكامل بالفعل.']);
            }
            $payment = $this->payments->pay($request, $tenantId, [
                'supplierId' => (int) $invoice->supplier_id,
                'branchId' => $branchId,
                'paymentDate' => now()->toDateString(),
                'amount' => Money::decimal($remaining),
                'paymentMethodId' => (int) $source->method->id,
                'financialLocationId' => (int) $source->location->id,
                'shiftId' => $source->shift ? (int) $source->shift->id : null,
                'externalReference' => $invoice->internal_reference,
                'notes' => "دفع تلقائي لفاتورة الشراء {$invoice->internal_reference}",
                'idempotencyKey' => "purchase-post:{$invoiceId}:payment",
                'allocations' => [['invoiceId' => $invoiceId, 'amount' => Money::decimal($remaining)]],
            ], $actorId);

            $voucher = $this->documents->createPostedSupplierPaymentVoucher(
                $request, $tenantId, $payment, $invoice,
                $source->shift ? (int) $source->shift->id : null,
                $actorId,
            );
            DB::table('supplier_payments')->where('tenant_id', $tenantId)->where('id', $payment->id)->update([
                'finance_document_id' => $voucher->id,
                'updated_at' => now(),
            ]);

            if ($source->shift) {
                DB::table('shift_cash_movements')->insertOrIgnore([
                    'tenant_id' => $tenantId,
                    'branch_id' => $branchId,
                    'shift_id' => $source->shift->id,
                    'kind' => 'expense',
                    'amount' => Money::decimal($remaining),
                    'description' => "دفع فاتورة شراء {$invoice->internal_reference}",
                    'source_type' => 'supplier_payment',
                    'source_id' => $payment->id,
                    'created_by' => $actorId,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
            $this->audit->record($request, $tenantId, 'purchase.auto_paid', 'supplier_invoice', $invoiceId, [], [
                'paymentId' => (int) $payment->id,
                'voucherId' => (int) $voucher->id,
                'shiftId' => $source->shift ? (int) $source->shift->id : null,
                'financialLocationId' => (int) $source->location->id,
                'amount' => Money::decimal($remaining),
            ], $branchId, $actorId);

            return $this->result($tenantId, $invoiceId, (int) $payment->id);
        }, 3);
    }

    private function receiveRemainingInventory(Request $request, int $tenantId, object $invoice, int $actorId): void
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
            'receiptDate' => now()->toDateString(),
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

    private function authorize(Request $request, int $tenantId, int $invoiceId): void
    {
        FinanceAccess::authorize($request, 'finance.purchases.post');
        FinanceAccess::authorize($request, 'finance.vouchers.create');
        FinanceAccess::authorize($request, 'finance.vouchers.post');
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

    private function result(int $tenantId, int $invoiceId, int $paymentId): object
    {
        $invoice = $this->invoice($tenantId, $invoiceId);
        $payment = DB::table('supplier_payments')->where('tenant_id', $tenantId)->where('id', $paymentId)->first();
        $voucher = DB::table('finance_documents')->where('tenant_id', $tenantId)->where('source_type', 'supplier_payment')->where('source_id', $paymentId)->first();

        return (object) ['invoice' => $invoice, 'payment' => $payment, 'voucher' => $voucher];
    }
}
