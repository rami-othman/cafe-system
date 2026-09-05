<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * A Supplier Payment records real money already leaving the business, so —
 * unlike a Supplier Invoice — it is created and posted in one atomic step
 * (the same shape as CashTransferService). Phase 5 requires full allocation
 * of the payment amount to open invoices (see docs §17): there is no concept
 * of unallocated supplier credit yet, so nothing is silently lost — an
 * unallocated remainder is rejected outright rather than accepted and
 * forgotten.
 */
class SupplierPaymentService
{
    public function __construct(
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly SupplierPayableQueryService $payable,
        private readonly OperationalAuditService $audit,
    ) {}

    public function pay(Request $request, int $tenantId, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'];
        $fingerprint = IdempotencyFingerprint::from($data);
        if (($existing = $this->byKey($tenantId, $key)) !== null) {
            $this->assertFingerprint($existing, $fingerprint);

            return $existing;
        }

        try {
            return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $key, $fingerprint): object {
                $existing = $this->byKey($tenantId, $key, true);
                if ($existing !== null) {
                    $this->assertFingerprint($existing, $fingerprint);

                    return $existing;
                }

                $supplier = DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $data['supplierId'])->where('is_active', true)->whereNull('deleted_at')->first();
                if (! $supplier) {
                    throw ValidationException::withMessages(['supplierId' => 'Select an active tenant supplier.']);
                }
                if (! empty($data['branchId'])) {
                    FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $data['branchId']);
                }

                $method = DB::table('payment_methods')->where('tenant_id', $tenantId)->where('id', $data['paymentMethodId'])->where('is_active', true)->lockForUpdate()->first();
                $location = DB::table('financial_locations as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
                    ->where('l.tenant_id', $tenantId)->where('l.id', $data['financialLocationId'])->where('l.is_active', true)
                    ->where('a.is_active', true)->whereNull('a.deleted_at')->select('l.*', 'a.code as account_code')->lockForUpdate()->first();
                if (! $method || ! $location || (int) $method->financial_account_id !== (int) $location->financial_account_id) {
                    throw ValidationException::withMessages(['payment' => 'Select an active payment method and matching cash or bank account from this tenant.']);
                }

                $amountCents = Money::cents($data['amount']);
                if ($amountCents <= 0) {
                    throw ValidationException::withMessages(['amount' => 'Amount must be greater than zero.']);
                }

                $allocations = collect($data['allocations'] ?? [])
                    ->map(fn (array $line) => ['invoiceId' => (int) $line['invoiceId'], 'amountCents' => Money::cents($line['amount'])])
                    ->sortBy('invoiceId')->values();
                if ($allocations->isEmpty()) {
                    throw ValidationException::withMessages(['allocations' => 'At least one invoice allocation is required.']);
                }
                if ($allocations->pluck('invoiceId')->unique()->count() !== $allocations->count()) {
                    throw ValidationException::withMessages(['allocations' => 'The same invoice cannot be allocated twice in one payment.']);
                }
                $allocatedTotalCents = $allocations->sum('amountCents');
                if ($allocatedTotalCents !== $amountCents) {
                    throw ValidationException::withMessages(['allocations' => 'Allocations must add up to exactly the payment amount.']);
                }

                foreach ($allocations as $line) {
                    if ($line['amountCents'] <= 0) {
                        throw ValidationException::withMessages(['allocations' => 'Each allocation must be greater than zero.']);
                    }
                    $invoice = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $line['invoiceId'])->lockForUpdate()->first();
                    if (! $invoice || (int) $invoice->supplier_id !== (int) $supplier->id) {
                        throw ValidationException::withMessages(['allocations' => "Invoice #{$line['invoiceId']} does not belong to the selected supplier."]);
                    }
                    if (! in_array($invoice->status, ['posted', 'partially_paid'], true)) {
                        throw ValidationException::withMessages(['allocations' => "Invoice {$invoice->internal_reference} is not open for payment."]);
                    }
                    $remainingCents = $this->payable->invoiceRemainingCents($tenantId, $invoice->id, lock: true);
                    if ($line['amountCents'] > $remainingCents) {
                        throw ValidationException::withMessages(['allocations' => "Allocation for {$invoice->internal_reference} exceeds its remaining balance of ".Money::decimal($remainingCents).'.']);
                    }
                }

                $now = now();
                $paymentId = DB::table('supplier_payments')->insertGetId([
                    'tenant_id' => $tenantId,
                    'branch_id' => $data['branchId'] ?? null,
                    'supplier_id' => $supplier->id,
                    'payment_number' => $this->nextNumber($tenantId),
                    'payment_date' => $data['paymentDate'],
                    'amount' => Money::decimal($amountCents),
                    'payment_method_id' => $method->id,
                    'financial_location_id' => $location->id,
                    'external_reference' => $data['externalReference'] ?? null,
                    'notes' => $data['notes'] ?? null,
                    'status' => 'posted',
                    'idempotency_key' => $key,
                    'idempotency_fingerprint' => $fingerprint,
                    'created_by' => $actorId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                foreach ($allocations as $line) {
                    DB::table('payment_allocations')->insert([
                        'tenant_id' => $tenantId,
                        'supplier_payment_id' => $paymentId,
                        'supplier_invoice_id' => $line['invoiceId'],
                        'amount' => Money::decimal($line['amountCents']),
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                    $this->recomputeInvoiceStatus($tenantId, $line['invoiceId']);
                }

                $journalId = $this->posting->postSupplierPayment($request, $tenantId, [
                    'branchId' => $data['branchId'] ?? null,
                    'sourceId' => $paymentId,
                    'sourceEvent' => 'SUPPLIER_PAYMENT_POSTED',
                    'entryDate' => $data['paymentDate'],
                    'description' => "Supplier Payment — {$supplier->name}",
                    'lines' => [
                        ['accountCode' => '2000', 'debit' => Money::decimal($amountCents), 'credit' => '0.00'],
                        ['accountCode' => $location->account_code, 'debit' => '0.00', 'credit' => Money::decimal($amountCents)],
                    ],
                ], $actorId);

                DB::table('supplier_payments')->where('id', $paymentId)->update(['journal_entry_id' => $journalId, 'updated_at' => now()]);
                $result = $this->find($tenantId, $paymentId);
                $this->audit->record($request, $tenantId, 'supplier_payment.posted', 'supplier_payment', $paymentId, [], (array) $result, $result->branch_id, $actorId);

                return $result;
            });
        } catch (QueryException $exception) {
            $existing = $this->byKey($tenantId, $key);
            if ($existing !== null) {
                $this->assertFingerprint($existing, $fingerprint);

                return $existing;
            }
            throw $exception;
        }
    }

    public function reverse(Request $request, int $tenantId, int $id, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId): object {
            $payment = $this->find($tenantId, $id, true);
            if (! empty($payment->branch_id)) {
                FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $payment->branch_id);
            }
            if ($payment->status !== 'posted' || ! $payment->journal_entry_id) {
                throw ValidationException::withMessages(['status' => 'Only a posted, unreversed supplier payment can be reversed.']);
            }

            $allocations = DB::table('payment_allocations')->where('tenant_id', $tenantId)->where('supplier_payment_id', $id)->orderBy('supplier_invoice_id')->lockForUpdate()->get();
            foreach ($allocations as $allocation) {
                DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $allocation->supplier_invoice_id)->lockForUpdate()->first();
            }

            $reversal = $this->entries->reverse($request, $tenantId, (int) $payment->journal_entry_id, $actorId);
            $now = now();
            foreach ($allocations as $allocation) {
                DB::table('supplier_payment_allocation_history')->updateOrInsert(
                    ['supplier_payment_id' => $id, 'supplier_invoice_id' => $allocation->supplier_invoice_id],
                    ['tenant_id' => $tenantId, 'amount' => $allocation->amount, 'payment_date' => $payment->payment_date, 'reversed_at' => $now, 'updated_at' => $now, 'created_at' => $now],
                );
            }
            DB::table('payment_allocations')->where('tenant_id', $tenantId)->where('supplier_payment_id', $id)->delete();
            DB::table('supplier_payments')->where('tenant_id', $tenantId)->where('id', $id)->update([
                'status' => 'reversed', 'reversal_journal_entry_id' => $reversal, 'reversed_by' => $actorId, 'reversed_at' => $now, 'updated_at' => $now,
            ]);
            foreach ($allocations as $allocation) {
                $this->recomputeInvoiceStatus($tenantId, (int) $allocation->supplier_invoice_id);
            }
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_payment.reversed', 'supplier_payment', $id, (array) $payment, (array) $result, $result->branch_id, $actorId);

            return $result;
        });
    }

    public function find(int $tenantId, int $id, bool $lock = false): object
    {
        $query = DB::table('supplier_payments')->where('tenant_id', $tenantId)->where('id', $id);
        if ($lock) {
            $query->lockForUpdate();
        }
        $row = $query->first();
        abort_unless($row, 404, 'Supplier payment not found.');

        return $row;
    }

    private function recomputeInvoiceStatus(int $tenantId, int $invoiceId): void
    {
        $invoice = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first();
        if (! $invoice || ! in_array($invoice->status, ['posted', 'partially_paid', 'paid'], true)) {
            return;
        }
        $remainingCents = $this->payable->invoiceRemainingCents($tenantId, $invoiceId);
        $totalCents = Money::cents($invoice->total_amount);
        $status = $remainingCents <= 0 ? 'paid' : ($remainingCents < $totalCents ? 'partially_paid' : 'posted');
        DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->update(['status' => $status, 'updated_at' => now()]);
    }

    private function byKey(int $tenantId, string $key, bool $lock = false): ?object
    {
        $query = DB::table('supplier_payments')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    private function assertFingerprint(object $payment, string $fingerprint): void
    {
        if (! $payment->idempotency_fingerprint || ! hash_equals($payment->idempotency_fingerprint, $fingerprint)) {
            abort(409, 'This idempotency key was already used for a different supplier payment request.');
        }
    }

    private function nextNumber(int $tenantId): string
    {
        $last = DB::table('supplier_payments')->where('tenant_id', $tenantId)->lockForUpdate()->orderByDesc('id')->value('payment_number');
        $number = $last && preg_match('/(\d+)$/', $last, $match) ? ((int) $match[1] + 1) : 1;

        return 'SPAY-'.str_pad((string) $number, 6, '0', STR_PAD_LEFT);
    }
}
