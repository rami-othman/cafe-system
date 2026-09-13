<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * CustomerPayment is the ONE authoritative business record for collecting
 * money from a customer against Accounts Receivable (ADR-04). Like
 * SupplierPaymentService, it records money already received, so it is
 * created and posted in one atomic step — there is no draft lifecycle.
 * Phase 3 requires full allocation of the payment amount to open invoices
 * (see docs/sales SALES_ARCHITECTURE_DECISIONS.md §12): there is no concept
 * of unapplied customer credit yet, so an unallocated remainder is rejected
 * outright rather than silently held as credit.
 *
 * It creates exactly one journal — Dr cash/bank, Cr Accounts Receivable —
 * and never touches Sales Revenue, Sales Tax, COGS or Inventory. Those
 * effects belong solely to SalesInvoicePostingService at invoice posting.
 */
final class CustomerPaymentService
{
    public function __construct(
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly SalesAccountResolver $accounts,
        private readonly CustomerReceivableQueryService $receivables,
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

                FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $data['branchId']);
                $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $data['customerId'])->where('is_active', true)->whereNull('deleted_at')->first();
                if (! $customer) {
                    throw ValidationException::withMessages(['customerId' => 'Select an active tenant customer.']);
                }

                [$method, $location] = $this->resolveSettlement($tenantId, $data);
                $amountCents = Money::cents($data['amount']);
                if ($amountCents <= 0) {
                    throw ValidationException::withMessages(['amount' => 'Amount must be greater than zero.']);
                }

                $allocations = $this->validatedAllocations($tenantId, (int) $customer->id, $data['allocations'] ?? [], $amountCents, lock: true);
                $arCode = $this->accounts->accountsReceivable($tenantId);

                $now = now();
                $paymentId = DB::table('customer_payments')->insertGetId([
                    'tenant_id' => $tenantId,
                    'branch_id' => $data['branchId'],
                    'customer_id' => $customer->id,
                    'payment_number' => $this->nextNumber($tenantId),
                    'payment_date' => $data['paymentDate'],
                    'amount' => Money::decimal($amountCents),
                    'payment_method_id' => $method->id,
                    'financial_location_id' => $location->id,
                    'external_reference' => $data['reference'] ?? null,
                    'notes' => $data['notes'] ?? null,
                    'status' => 'posted',
                    'idempotency_key' => $key,
                    'idempotency_fingerprint' => $fingerprint,
                    'created_by' => $actorId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                foreach ($allocations as $line) {
                    DB::table('customer_payment_allocations')->insert([
                        'tenant_id' => $tenantId,
                        'customer_payment_id' => $paymentId,
                        'sales_invoice_id' => $line['invoiceId'],
                        'amount' => Money::decimal($line['amountCents']),
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }

                $journalId = $this->posting->postCustomerPayment($request, $tenantId, [
                    'branchId' => $data['branchId'],
                    'sourceId' => $paymentId,
                    'sourceEvent' => 'CUSTOMER_PAYMENT_POSTED',
                    'entryDate' => $data['paymentDate'],
                    'description' => "Customer Payment — {$customer->name}",
                    'lines' => [
                        ['accountCode' => $location->account_code, 'debit' => Money::decimal($amountCents), 'description' => 'Cash/Bank Received'],
                        ['accountCode' => $arCode, 'credit' => Money::decimal($amountCents), 'description' => 'Accounts Receivable'],
                    ],
                ], $actorId);

                DB::table('customer_payments')->where('id', $paymentId)->update(['journal_entry_id' => $journalId, 'updated_at' => now()]);
                $result = $this->find($tenantId, $paymentId);
                $this->audit->record($request, $tenantId, 'sales.customer_payment.posted', 'customer_payment', $paymentId, [], ['paymentNumber' => $result->payment_number, 'amount' => $result->amount, 'journalEntryId' => $journalId, 'allocations' => $allocations->map(fn (array $l) => ['invoiceId' => $l['invoiceId'], 'amount' => Money::decimal($l['amountCents'])])->values()->all()], $result->branch_id, $actorId);

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

    /**
     * Read-only settlement projection: runs the exact same resolution and
     * allocation validation as pay() but performs no lock, no insert and no
     * journal — zero state changes (§39). Preview and the following post
     * must agree on amount, account, AR credit and resulting invoice
     * outstanding as long as no other change lands on the same rows first.
     */
    public function preview(int $tenantId, array $data): array
    {
        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $data['customerId'] ?? 0)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $customer) {
            throw ValidationException::withMessages(['customerId' => 'Select an active tenant customer.']);
        }
        [$method, $location] = $this->resolveSettlement($tenantId, $data);
        $amountCents = Money::cents($data['amount'] ?? '0');
        if ($amountCents <= 0) {
            throw ValidationException::withMessages(['amount' => 'Amount must be greater than zero.']);
        }
        $allocations = $this->validatedAllocations($tenantId, (int) $customer->id, $data['allocations'] ?? [], $amountCents, lock: false);
        $arCode = $this->accounts->accountsReceivable($tenantId);

        $lines = [];
        foreach ($allocations as $line) {
            $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $line['invoiceId'])->first();
            $totalCents = Money::cents($invoice->total);
            $remainingBeforeCents = $this->receivables->invoiceRemainingCents($tenantId, $invoice->id);
            $paidBeforeCents = $totalCents - $remainingBeforeCents;
            $remainingAfterCents = $remainingBeforeCents - $line['amountCents'];
            $lines[] = [
                'invoiceId' => (int) $invoice->id, 'invoiceNumber' => $invoice->invoice_number, 'total' => Money::decimal($totalCents),
                'paidBefore' => Money::decimal($paidBeforeCents), 'remainingBefore' => Money::decimal($remainingBeforeCents),
                'allocated' => Money::decimal($line['amountCents']),
                'paidAfter' => Money::decimal($paidBeforeCents + $line['amountCents']), 'remainingAfter' => Money::decimal($remainingAfterCents),
                'paymentStatusAfter' => $this->receivables->paymentStatus($totalCents, $remainingAfterCents),
            ];
        }

        return [
            'customer' => ['id' => (int) $customer->id, 'name' => $customer->name],
            'amount' => Money::decimal($amountCents),
            'settlementAccount' => ['id' => (int) $location->id, 'code' => $location->account_code, 'name' => $location->name],
            'accounting' => ['debitAccountCode' => $location->account_code, 'debitAmount' => Money::decimal($amountCents), 'creditAccountCode' => $arCode, 'creditAmount' => Money::decimal($amountCents)],
            'allocations' => $lines,
        ];
    }

    /**
     * Reverses a posted customer payment: a new reversing journal (Dr AR;
     * Cr cash/bank) plus removing its allocations so the invoice's live
     * remaining balance is restored — never a delete of the original
     * payment (§21). This is a payment-reversal correction, distinct from a
     * Sales Credit Note or a Return, which remain Phase 4.
     */
    public function reverse(Request $request, int $tenantId, int $id, ?int $actorId, ?string $reason = null): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId, $reason): object {
            $payment = $this->find($tenantId, $id, true);
            FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $payment->branch_id);
            if ($payment->status !== 'posted' || ! $payment->journal_entry_id) {
                throw ValidationException::withMessages(['status' => 'Only a posted, unreversed customer payment can be reversed.']);
            }

            $allocations = DB::table('customer_payment_allocations')->where('tenant_id', $tenantId)->where('customer_payment_id', $id)->orderBy('sales_invoice_id')->lockForUpdate()->get();
            foreach ($allocations as $allocation) {
                DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $allocation->sales_invoice_id)->lockForUpdate()->first();
            }

            $reversalJournalId = $this->entries->reverse($request, $tenantId, (int) $payment->journal_entry_id, $actorId);
            $now = now();
            foreach ($allocations as $allocation) {
                DB::table('customer_payment_allocation_history')->updateOrInsert(
                    ['customer_payment_id' => $id, 'sales_invoice_id' => $allocation->sales_invoice_id],
                    ['tenant_id' => $tenantId, 'amount' => $allocation->amount, 'payment_date' => $payment->payment_date, 'reversed_at' => $now, 'updated_at' => $now, 'created_at' => $now],
                );
            }
            DB::table('customer_payment_allocations')->where('tenant_id', $tenantId)->where('customer_payment_id', $id)->delete();
            DB::table('customer_payments')->where('tenant_id', $tenantId)->where('id', $id)->update([
                'status' => 'reversed', 'reversal_journal_entry_id' => $reversalJournalId, 'reversed_by' => $actorId, 'reversed_at' => $now, 'updated_at' => $now,
            ]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'sales.customer_payment.reversed', 'customer_payment', $id, (array) $payment, ['reason' => $reason] + (array) $result, $result->branch_id, $actorId);

            return $result;
        });
    }

    public function find(int $tenantId, int $id, bool $lock = false): object
    {
        $query = DB::table('customer_payments')->where('tenant_id', $tenantId)->where('id', $id);
        if ($lock) {
            $query->lockForUpdate();
        }
        $row = $query->first();
        abort_unless($row, 404, 'Customer payment not found.');

        return $row;
    }

    /**
     * Shared by pay() (lock: true, inside the posting transaction) and
     * preview() (lock: false, no transaction) so both apply exactly the
     * same rules: unique invoices, allocations summing to the payment
     * amount exactly (§12 — no unapplied credit in Phase 3), same
     * customer (§13), posted invoice only (§14), and never beyond the
     * invoice's remaining balance (§11).
     */
    private function validatedAllocations(int $tenantId, int $customerId, array $input, int $amountCents, bool $lock): Collection
    {
        $allocations = collect($input)
            ->map(fn (array $line) => ['invoiceId' => (int) ($line['invoiceId'] ?? $line['salesInvoiceId'] ?? 0), 'amountCents' => Money::cents($line['amount'])])
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
            $invoiceQuery = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $line['invoiceId']);
            $invoice = $lock ? $invoiceQuery->lockForUpdate()->first() : $invoiceQuery->first();
            if (! $invoice || (int) $invoice->customer_id !== $customerId) {
                throw ValidationException::withMessages(['allocations' => "Invoice #{$line['invoiceId']} does not belong to the selected customer."]);
            }
            if (! in_array($invoice->status, CustomerReceivableQueryService::OPEN_STATUSES, true)) {
                throw ValidationException::withMessages(['allocations' => "Invoice {$invoice->invoice_number} is not open for payment."]);
            }
            $remainingCents = $this->receivables->invoiceRemainingCents($tenantId, (int) $invoice->id, lock: $lock);
            if ($line['amountCents'] > $remainingCents) {
                throw ValidationException::withMessages(['allocations' => "Allocation for {$invoice->invoice_number} exceeds its remaining balance of ".Money::decimal($remainingCents).'.']);
            }
        }

        return $allocations;
    }

    /** @return array{0:object,1:object} */
    private function resolveSettlement(int $tenantId, array $data): array
    {
        $method = DB::table('payment_methods')->where('tenant_id', $tenantId)->where('id', $data['paymentMethodId'] ?? 0)->where('is_active', true)->first();
        $location = DB::table('financial_locations as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
            ->where('l.tenant_id', $tenantId)->where('l.id', $data['financialLocationId'] ?? 0)->where('l.is_active', true)
            ->where('a.is_active', true)->whereNull('a.deleted_at')->select('l.*', 'a.code as account_code', 'a.name_ar as account_name')->first();
        if (! $method || ! $location || (int) $method->financial_account_id !== (int) $location->financial_account_id) {
            throw ValidationException::withMessages(['payment' => 'Select an active payment method and matching cash or bank account from this tenant.']);
        }

        return [$method, $location];
    }

    private function byKey(int $tenantId, string $key, bool $lock = false): ?object
    {
        $query = DB::table('customer_payments')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    private function assertFingerprint(object $payment, string $fingerprint): void
    {
        if (! $payment->idempotency_fingerprint || ! hash_equals($payment->idempotency_fingerprint, $fingerprint)) {
            abort(409, 'This idempotency key was already used for a different customer payment request.');
        }
    }

    private function nextNumber(int $tenantId): string
    {
        $year = now()->year;
        // Locks the tenant row (not an aggregate) so PostgreSQL accepts the
        // lock and per-tenant numbering serializes, matching the existing
        // SalesInvoiceService/JournalEntryService numbering convention.
        DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->first();
        $count = DB::table('customer_payments')->where('tenant_id', $tenantId)->where('payment_number', 'like', "CR-{$year}-%")->count() + 1;

        return sprintf('CR-%d-%06d', $year, $count);
    }
}
