<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * A Supplier Invoice is the Accounts Payable business record — it is not the
 * journal entry itself (mirrors ExpenseService's Phase 3 principle). Posting
 * only ever debits the invoice's own frozen debit account and credits the
 * tenant's Accounts Payable account (2000); it never creates a stock
 * movement or inventory quantity, even for invoiceType "inventory" — that is
 * a Goods Receipt's job, and no such workflow exists yet (see docs §10/§40).
 */
class SupplierInvoiceService
{
    public function __construct(
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
    ) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'] ?? null;
        $fingerprint = $key ? IdempotencyFingerprint::from($data) : null;
        if ($key && ($existing = $this->byKey($tenantId, $key))) {
            $this->assertFingerprint($existing, $fingerprint);

            return $existing;
        }

        return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $key, $fingerprint): object {
            if ($key && ($existing = $this->byKey($tenantId, $key, true))) {
                $this->assertFingerprint($existing, $fingerprint);

                return $existing;
            }
            $this->assertSupplierAndBranch($tenantId, $data, $actorId);
            $debitAccountId = $this->resolveDebitAccount($tenantId, $data);
            [$subtotal, $tax] = $this->money($data);

            $id = (int) DB::table('supplier_invoices')->insertGetId($this->draftPayload($data, $debitAccountId, $subtotal, $tax) + [
                'tenant_id' => $tenantId,
                'internal_reference' => $this->nextReference($tenantId),
                'status' => 'draft',
                'idempotency_key' => $key,
                'idempotency_fingerprint' => $fingerprint,
                'created_by' => $actorId,
                'updated_by' => $actorId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $invoice = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_invoice.created', 'supplier_invoice', $id, [], (array) $invoice, $invoice->branch_id, $actorId);

            return $invoice;
        });
    }

    public function update(Request $request, int $tenantId, int $id, array $data, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $data, $actorId): object {
            $before = $this->find($tenantId, $id, true);
            $this->assertBranch($actorId, $tenantId, $before->branch_id);
            if ($before->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'Only draft supplier invoices can be edited.']);
            }
            $this->assertSupplierAndBranch($tenantId, $data, $actorId);
            $debitAccountId = $this->resolveDebitAccount($tenantId, $data);
            [$subtotal, $tax] = $this->money($data);

            DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)
                ->update($this->draftPayload($data, $debitAccountId, $subtotal, $tax) + ['updated_by' => $actorId, 'updated_at' => now()]);
            $invoice = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_invoice.updated', 'supplier_invoice', $id, (array) $before, (array) $invoice, $invoice->branch_id, $actorId);

            return $invoice;
        });
    }

    public function post(Request $request, int $tenantId, int $id, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'];
        $fingerprint = IdempotencyFingerprint::from($data);

        return DB::transaction(function () use ($request, $tenantId, $id, $actorId, $key, $fingerprint): object {
            $used = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('posting_idempotency_key', $key)->lockForUpdate()->first();
            if ($used && (int) $used->id !== $id) {
                abort(409, 'This idempotency key was already used to post a different supplier invoice.');
            }
            $invoice = $this->find($tenantId, $id, true);
            $this->assertBranch($actorId, $tenantId, $invoice->branch_id);
            if ($invoice->status === 'posted' && $invoice->posting_idempotency_key === $key) {
                $this->assertPostingFingerprint($invoice, $fingerprint);

                return $invoice;
            }
            if ($invoice->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'Only a draft supplier invoice can be posted.']);
            }

            $debitAccount = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $invoice->debit_account_id)->where('is_active', true)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $debitAccount) {
                throw ValidationException::withMessages(['debitAccountId' => 'The invoice debit account must remain active before posting.']);
            }
            $supplier = DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $invoice->supplier_id)->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $supplier) {
                throw ValidationException::withMessages(['supplierId' => 'The supplier must remain active before posting.']);
            }

            $total = Money::cents($invoice->total_amount);
            $journalId = $this->posting->postSupplierInvoice($request, $tenantId, [
                'branchId' => $invoice->branch_id,
                'sourceId' => $invoice->id,
                'sourceEvent' => 'SUPPLIER_INVOICE_POSTED',
                'entryDate' => $invoice->invoice_date,
                'description' => "Supplier Invoice {$invoice->internal_reference} — {$supplier->name}",
                'lines' => [
                    ['accountCode' => $debitAccount->code, 'debit' => Money::decimal($total), 'credit' => '0.00'],
                    ['accountCode' => '2000', 'debit' => '0.00', 'credit' => Money::decimal($total)],
                ],
            ], $actorId);

            $now = now();
            DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)->update([
                'status' => 'posted',
                'journal_entry_id' => $journalId,
                'posting_idempotency_key' => $key,
                'posting_idempotency_fingerprint' => $fingerprint,
                'posted_by' => $actorId,
                'posted_at' => $now,
                'updated_at' => $now,
            ]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_invoice.posted', 'supplier_invoice', $id, (array) $invoice, (array) $result, $result->branch_id, $actorId);

            return $result;
        });
    }

    public function reverse(Request $request, int $tenantId, int $id, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId): object {
            $invoice = $this->find($tenantId, $id, true);
            $this->assertBranch($actorId, $tenantId, $invoice->branch_id);
            if ($invoice->status !== 'posted' || ! $invoice->journal_entry_id) {
                throw ValidationException::withMessages(['status' => 'Only a posted, unpaid supplier invoice can be reversed.']);
            }
            $hasAllocations = DB::table('payment_allocations')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $id)->exists();
            if ($hasAllocations) {
                throw ValidationException::withMessages(['status' => 'This invoice already has payments allocated to it; reverse those payments first.']);
            }

            $reversal = $this->entries->reverse($request, $tenantId, (int) $invoice->journal_entry_id, $actorId);
            DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)->update(['status' => 'cancelled', 'reversal_journal_entry_id' => $reversal, 'updated_at' => now()]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_invoice.reversed', 'supplier_invoice', $id, (array) $invoice, (array) $result, $result->branch_id, $actorId);

            return $result;
        });
    }

    public function find(int $tenantId, int $id, bool $lock = false): object
    {
        $query = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at');
        if ($lock) {
            $query->lockForUpdate();
        }
        $row = $query->first();
        abort_unless($row, 404, 'Supplier invoice not found.');

        return $row;
    }

    private function byKey(int $tenantId, string $key, bool $lock = false): ?object
    {
        $query = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('idempotency_key', $key)->whereNull('deleted_at');
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    private function assertFingerprint(object $invoice, string $fingerprint): void
    {
        if (! $invoice->idempotency_fingerprint || ! hash_equals($invoice->idempotency_fingerprint, $fingerprint)) {
            abort(409, 'This idempotency key was already used for a different supplier invoice request.');
        }
    }

    private function assertPostingFingerprint(object $invoice, string $fingerprint): void
    {
        if (! $invoice->posting_idempotency_fingerprint || ! hash_equals($invoice->posting_idempotency_fingerprint, $fingerprint)) {
            abort(409, 'This idempotency key was already used for a different posting request.');
        }
    }

    private function money(array $data): array
    {
        $subtotal = Money::cents($data['subtotal'], 'subtotal');
        $tax = Money::cents($data['taxAmount'] ?? '0', 'taxAmount');
        if ($subtotal <= 0) {
            throw ValidationException::withMessages(['subtotal' => 'Subtotal must be greater than zero.']);
        }

        return [$subtotal, $tax];
    }

    private function draftPayload(array $data, int $debitAccountId, int $subtotal, int $tax): array
    {
        return [
            'branch_id' => $data['branchId'] ?? null,
            'supplier_id' => (int) $data['supplierId'],
            'invoice_number' => $data['invoiceNumber'],
            'invoice_date' => $data['invoiceDate'],
            'due_date' => $data['dueDate'],
            'invoice_type' => $data['invoiceType'],
            'expense_category_id' => $data['invoiceType'] === 'expense' ? (int) $data['expenseCategoryId'] : null,
            'debit_account_id' => $debitAccountId,
            'subtotal' => Money::decimal($subtotal),
            'tax_amount' => Money::decimal($tax),
            'total_amount' => Money::decimal($subtotal + $tax),
            'description' => $data['description'] ?? null,
            'notes' => $data['notes'] ?? null,
            'updated_at' => now(),
        ];
    }

    private function resolveDebitAccount(int $tenantId, array $data): int
    {
        $type = $data['invoiceType'];
        if ($type === 'expense') {
            $category = DB::table('expense_categories as c')->join('financial_accounts as a', 'a.id', '=', 'c.financial_account_id')
                ->where('c.tenant_id', $tenantId)->where('c.id', $data['expenseCategoryId'] ?? null)
                ->where('c.is_active', true)->where('a.is_active', true)->whereNull('c.deleted_at')->whereNull('a.deleted_at')
                ->select('a.id')->first();
            if (! $category) {
                throw ValidationException::withMessages(['expenseCategoryId' => 'Select an active tenant expense category.']);
            }

            return (int) $category->id;
        }

        if ($type === 'inventory') {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1100')->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $account) {
                throw ValidationException::withMessages(['invoiceType' => 'The Inventory Asset account is not active for this tenant.']);
            }

            return (int) $account->id;
        }

        if ($type === 'other') {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $data['debitAccountId'] ?? null)
                ->where('is_active', true)->whereNull('deleted_at')
                ->whereIn('account_group', ['expenses', 'assets', 'cost_of_sales'])
                ->where('code', '!=', '1100')
                ->first();
            if (! $account) {
                throw ValidationException::withMessages(['debitAccountId' => 'Select an active tenant expense, asset, or cost-of-sales account (not Inventory Asset — use invoice type "inventory" for that).']);
            }

            return (int) $account->id;
        }

        throw ValidationException::withMessages(['invoiceType' => 'Invoice type must be expense, inventory, or other.']);
    }

    private function assertSupplierAndBranch(int $tenantId, array $data, ?int $actorId): void
    {
        $supplier = DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $data['supplierId'] ?? null)->where('is_active', true)->whereNull('deleted_at')->exists();
        if (! $supplier) {
            throw ValidationException::withMessages(['supplierId' => 'Select an active tenant supplier.']);
        }
        if (! empty($data['branchId'])) {
            if (! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $data['branchId'])->where('is_active', true)->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(['branchId' => 'The branch does not belong to this tenant.']);
            }
            $this->assertBranch($actorId, $tenantId, (int) $data['branchId']);
        }
        if (isset($data['dueDate'], $data['invoiceDate']) && $data['dueDate'] < $data['invoiceDate']) {
            throw ValidationException::withMessages(['dueDate' => 'Due date cannot be before the invoice date.']);
        }
    }

    private function assertBranch(?int $actorId, int $tenantId, mixed $branchId): void
    {
        FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId ? (int) $branchId : null);
    }

    private function nextReference(int $tenantId): string
    {
        $last = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->lockForUpdate()->orderByDesc('id')->value('internal_reference');
        $number = $last && preg_match('/(\d+)$/', $last, $match) ? ((int) $match[1] + 1) : 1;

        return 'AP-'.str_pad((string) $number, 6, '0', STR_PAD_LEFT);
    }
}
