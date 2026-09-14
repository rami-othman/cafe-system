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
 * Customer Refund settles unapplied customer credit (docs/sales Phase 4
 * §11) — it is a pure Cash/Bank-out-of / Customer-Credit-in-of settlement
 * event, created and posted atomically in one step, mirroring
 * CustomerPaymentService. It creates exactly one journal: Dr Customer
 * Credit; Cr cash/bank. It never touches Revenue, Tax, COGS or Inventory —
 * those are exclusively Credit Note effects.
 */
final class CustomerRefundService
{
    public function __construct(
        private readonly AccountingPostingService $posting,
        private readonly SalesAccountResolver $accounts,
        private readonly CustomerCreditQueryService $credit,
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
                $availableCents = $this->credit->balanceCents($tenantId, (int) $customer->id, lock: true);
                if ($amountCents > $availableCents) {
                    throw ValidationException::withMessages(['amount' => 'Refund amount exceeds the customer\'s available credit of '.Money::decimal($availableCents).'.']);
                }

                $customerCreditCode = $this->accounts->customerCredit($tenantId);
                $now = now();
                $refundId = DB::table('customer_refunds')->insertGetId([
                    'tenant_id' => $tenantId, 'branch_id' => $data['branchId'], 'customer_id' => $customer->id,
                    'refund_number' => $this->nextNumber($tenantId), 'refund_date' => $data['refundDate'], 'amount' => Money::decimal($amountCents),
                    'payment_method_id' => $method->id, 'financial_location_id' => $location->id,
                    'external_reference' => $data['reference'] ?? null, 'notes' => $data['notes'] ?? null, 'status' => 'posted',
                    'idempotency_key' => $key, 'idempotency_fingerprint' => $fingerprint,
                    'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
                ]);

                DB::table('customer_credit_ledger')->insert(['tenant_id' => $tenantId, 'customer_id' => $customer->id, 'customer_refund_id' => $refundId, 'amount' => Money::decimal(-$amountCents), 'created_at' => $now, 'updated_at' => $now]);

                $journalId = $this->posting->postCustomerRefund($request, $tenantId, [
                    'branchId' => $data['branchId'], 'sourceId' => $refundId, 'sourceEvent' => 'CUSTOMER_REFUND_POSTED',
                    'entryDate' => $data['refundDate'], 'description' => "Customer Refund — {$customer->name}",
                    'lines' => [
                        ['accountCode' => $customerCreditCode, 'debit' => Money::decimal($amountCents), 'description' => 'Customer Credit Balance'],
                        ['accountCode' => $location->account_code, 'credit' => Money::decimal($amountCents), 'description' => 'Cash/Bank Paid'],
                    ],
                ], $actorId);

                DB::table('customer_refunds')->where('id', $refundId)->update(['journal_entry_id' => $journalId, 'updated_at' => now()]);
                $result = $this->find($tenantId, $refundId);
                $this->audit->record($request, $tenantId, 'sales.customer_refund.posted', 'customer_refund', $refundId, [], ['refundNumber' => $result->refund_number, 'amount' => $result->amount, 'journalEntryId' => $journalId], $result->branch_id, $actorId);

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

    /** Read-only settlement projection — zero state changes. */
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
        $availableCents = $this->credit->balanceCents($tenantId, (int) $customer->id);
        if ($amountCents > $availableCents) {
            throw ValidationException::withMessages(['amount' => 'Refund amount exceeds the customer\'s available credit of '.Money::decimal($availableCents).'.']);
        }
        $customerCreditCode = $this->accounts->customerCredit($tenantId);

        return [
            'customer' => ['id' => (int) $customer->id, 'name' => $customer->name],
            'availableCredit' => Money::decimal($availableCents),
            'amount' => Money::decimal($amountCents),
            'availableCreditAfter' => Money::decimal($availableCents - $amountCents),
            'settlementAccount' => ['id' => (int) $location->id, 'code' => $location->account_code, 'name' => $location->name],
            'accounting' => ['debitAccountCode' => $customerCreditCode, 'debitAmount' => Money::decimal($amountCents), 'creditAccountCode' => $location->account_code, 'creditAmount' => Money::decimal($amountCents)],
        ];
    }

    public function find(int $tenantId, int $id, bool $lock = false): object
    {
        $query = DB::table('customer_refunds')->where('tenant_id', $tenantId)->where('id', $id);
        if ($lock) {
            $query->lockForUpdate();
        }
        $row = $query->first();
        abort_unless($row, 404, 'Customer refund not found.');

        return $row;
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
        $query = DB::table('customer_refunds')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    private function assertFingerprint(object $refund, string $fingerprint): void
    {
        if (! $refund->idempotency_fingerprint || ! hash_equals($refund->idempotency_fingerprint, $fingerprint)) {
            abort(409, 'This idempotency key was already used for a different customer refund request.');
        }
    }

    private function nextNumber(int $tenantId): string
    {
        $year = now()->year;
        DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->first();
        $count = DB::table('customer_refunds')->where('tenant_id', $tenantId)->where('refund_number', 'like', "RF-{$year}-%")->count() + 1;

        return sprintf('RF-%d-%06d', $year, $count);
    }
}
