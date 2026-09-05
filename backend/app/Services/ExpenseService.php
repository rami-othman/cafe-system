<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ExpenseService
{
    public function __construct(private readonly AccountingPostingService $posting, private readonly JournalEntryService $entries, private readonly OperationalAuditService $audit, private readonly FinanceApprovalPolicy $approval) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'] ?? null; $fingerprint = $key ? IdempotencyFingerprint::from($data) : null;
        if ($key && ($existing = $this->byKey($tenantId, $key))) { $this->assertFingerprint($existing, $fingerprint); return $existing; }
        try { return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $key, $fingerprint): object {
            if ($key && ($existing = $this->byKey($tenantId, $key, true))) { $this->assertFingerprint($existing, $fingerprint); return $existing; }
            $this->assertDraftReferences($tenantId, $data, $actorId); [$amount, $tax] = $this->money($data);
            $id = (int) DB::table('expenses')->insertGetId($this->draftPayload($data, $amount, $tax, $actorId) + ['tenant_id' => $tenantId, 'expense_number' => $this->nextNumber($tenantId), 'status' => 'draft', 'payment_status' => 'unpaid', 'idempotency_key' => $key, 'idempotency_fingerprint' => $fingerprint, 'created_by' => $actorId, 'created_at' => now(), 'updated_at' => now()]);
            $expense = $this->find($tenantId, $id); $this->audit->record($request, $tenantId, 'expense.created', 'expense', $id, [], (array) $expense, $expense->branch_id, $actorId); return $expense;
        }); } catch (QueryException $e) { if ($key && ($existing = $this->byKey($tenantId, $key))) { $this->assertFingerprint($existing, $fingerprint); return $existing; } throw $e; }
    }

    public function update(Request $request, int $tenantId, int $id, array $data, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $data, $actorId): object {
            $before = $this->find($tenantId, $id, true); $this->assertBranch($actorId, $tenantId, $before->branch_id);
            if ($before->status !== 'draft') throw ValidationException::withMessages(['expense' => 'Only draft expenses can be edited.']);
            $this->assertDraftReferences($tenantId, $data, $actorId); [$amount, $tax] = $this->money($data);
            DB::table('expenses')->where('tenant_id', $tenantId)->where('id', $id)->update($this->draftPayload($data, $amount, $tax, $actorId) + ['updated_at' => now()]);
            $expense = $this->find($tenantId, $id); $this->audit->record($request, $tenantId, 'expense.updated', 'expense', $id, (array) $before, (array) $expense, $expense->branch_id, $actorId); return $expense;
        });
    }

    public function transition(Request $request, int $tenantId, int $id, string $action, array $data, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $action, $data, $actorId): object {
            $before = $this->find($tenantId, $id, true); $this->assertBranch($actorId, $tenantId, $before->branch_id); $now = now();
            if ($action === 'submit' && $before->status === 'draft') $changes = ['status' => 'pending_approval'];
            elseif ($action === 'approve' && $before->status === 'pending_approval') { $this->approval->assertExpenseApproval($tenantId, (int) $actorId, $before); $changes = ['status' => 'approved', 'approved_by' => $actorId, 'approved_at' => $now]; }
            elseif ($action === 'reject' && $before->status === 'pending_approval') { if (trim((string) ($data['rejectionReason'] ?? '')) === '') throw ValidationException::withMessages(['rejectionReason' => 'A rejection reason is required.']); $changes = ['status' => 'rejected', 'rejected_by' => $actorId, 'rejected_at' => $now, 'rejection_reason' => $data['rejectionReason']]; }
            else throw ValidationException::withMessages(['expense' => "Cannot {$action} this expense in its current status."]);
            DB::table('expenses')->where('tenant_id', $tenantId)->where('id', $id)->update($changes + ['updated_at' => $now]); $expense = $this->find($tenantId, $id); $auditAction = ['submit' => 'expense.submitted', 'approve' => 'expense.approved', 'reject' => 'expense.rejected'][$action]; $this->audit->record($request, $tenantId, $auditAction, 'expense', $id, (array) $before, (array) $expense, $expense->branch_id, $actorId); return $expense;
        });
    }

    public function pay(Request $request, int $tenantId, int $id, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey']; $fingerprint = IdempotencyFingerprint::from($data);
        try { return DB::transaction(function () use ($request, $tenantId, $id, $data, $actorId, $key, $fingerprint): object {
            $usedKey = DB::table('expenses')->where('tenant_id', $tenantId)->where('payment_idempotency_key', $key)->lockForUpdate()->first();
            if ($usedKey && (int) $usedKey->id !== $id) abort(409, 'This idempotency key was already used for a different expense payment.');
            $expense = $this->find($tenantId, $id, true); $this->assertBranch($actorId, $tenantId, $expense->branch_id);
            if ($expense->status === 'paid' && $expense->payment_idempotency_key === $key) { $this->assertPaymentFingerprint($expense, $fingerprint); return $expense; }
            if ($expense->status === 'paid') throw ValidationException::withMessages(['expense' => 'This expense is already paid.']);
            if ($expense->status !== 'approved' || $expense->payment_status !== 'unpaid') throw ValidationException::withMessages(['expense' => 'Only an approved unpaid expense can be paid.']);
            $method = DB::table('payment_methods')->where('tenant_id', $tenantId)->where('id', $data['paymentMethodId'])->where('is_active', true)->lockForUpdate()->first();
            $location = DB::table('financial_locations as locations')->join('financial_accounts as accounts', 'accounts.id', '=', 'locations.financial_account_id')->where('locations.tenant_id', $tenantId)->where('locations.id', $data['financialLocationId'])->where('locations.is_active', true)->where('accounts.is_active', true)->whereNull('accounts.deleted_at')->select('locations.*', 'accounts.code as account_code')->lockForUpdate()->first();
            if (! $method || ! $location || ((int) $method->financial_account_id !== (int) $location->financial_account_id)) throw ValidationException::withMessages(['payment' => 'Select an active payment method and matching cash or bank account from this tenant.']);
            $this->assertBranch($actorId, $tenantId, $location->branch_id); $category = DB::table('expense_categories as categories')->join('financial_accounts as accounts', 'accounts.id', '=', 'categories.financial_account_id')->where('categories.tenant_id', $tenantId)->where('categories.id', $expense->expense_category_id)->where('categories.is_active', true)->where('accounts.is_active', true)->whereNull('categories.deleted_at')->whereNull('accounts.deleted_at')->select('categories.*', 'accounts.code as account_code')->lockForUpdate()->first();
            if (! $category) throw ValidationException::withMessages(['expenseCategoryId' => 'The expense category and account must remain active before payment.']);
            $total = Money::cents($expense->total_amount); $journalId = $this->posting->postExpense($request, $tenantId, ['branchId' => $expense->branch_id, 'sourceId' => $expense->id, 'sourceEvent' => 'EXPENSE_PAID', 'entryDate' => $data['paymentDate'], 'description' => $data['description'] ?? $expense->description, 'lines' => [['accountCode' => $category->account_code, 'debit' => Money::decimal($total), 'credit' => '0.00'], ['accountCode' => $location->account_code, 'debit' => '0.00', 'credit' => Money::decimal($total)]]], $actorId);
            DB::table('expenses')->where('tenant_id', $tenantId)->where('id', $id)->update(['status' => 'paid', 'payment_status' => 'paid', 'payment_method_id' => $method->id, 'paid_from_financial_location_id' => $location->id, 'paid_at' => $data['paymentDate'], 'journal_entry_id' => $journalId, 'payment_idempotency_key' => $key, 'payment_idempotency_fingerprint' => $fingerprint, 'updated_at' => now()]);
            $result = $this->find($tenantId, $id); $this->audit->record($request, $tenantId, 'expense.paid', 'expense', $id, (array) $expense, (array) $result, $result->branch_id, $actorId); return $result;
        }); } catch (QueryException $e) { $existing = DB::table('expenses')->where('tenant_id', $tenantId)->where('payment_idempotency_key', $key)->first(); if ($existing && (int) $existing->id === $id) { $this->assertPaymentFingerprint($existing, $fingerprint); return $existing; } if ($existing) abort(409, 'This idempotency key was already used for a different expense payment.'); throw $e; }
    }

    public function reverse(Request $request, int $tenantId, int $id, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId): object { $expense = $this->find($tenantId, $id, true); $this->assertBranch($actorId, $tenantId, $expense->branch_id); if ($expense->status !== 'paid' || ! $expense->journal_entry_id || $expense->reversal_journal_entry_id) throw ValidationException::withMessages(['expense' => 'Only an unreversed paid expense can be reversed.']); $reversal = $this->entries->reverse($request, $tenantId, (int) $expense->journal_entry_id, $actorId); DB::table('expenses')->where('tenant_id', $tenantId)->where('id', $id)->update(['status' => 'reversed', 'reversal_journal_entry_id' => $reversal, 'updated_at' => now()]); $result = $this->find($tenantId, $id); $this->audit->record($request, $tenantId, 'expense.reversed', 'expense', $id, (array) $expense, (array) $result, $result->branch_id, $actorId); return $result; });
    }

    public function find(int $tenantId, int $id, bool $lock = false): object { $query = DB::table('expenses')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at'); if ($lock) $query->lockForUpdate(); $row = $query->first(); abort_unless($row, 404, 'Expense not found.'); return $row; }
    private function byKey(int $tenantId, string $key, bool $lock = false): ?object { $query = DB::table('expenses')->where('tenant_id', $tenantId)->where('idempotency_key', $key)->whereNull('deleted_at'); if ($lock) $query->lockForUpdate(); return $query->first(); }
    private function assertFingerprint(object $expense, string $fingerprint): void { if (! $expense->idempotency_fingerprint || ! hash_equals($expense->idempotency_fingerprint, $fingerprint)) abort(409, 'This idempotency key was already used for a different expense request.'); }
    private function assertPaymentFingerprint(object $expense, string $fingerprint): void { if (! $expense->payment_idempotency_fingerprint || ! hash_equals($expense->payment_idempotency_fingerprint, $fingerprint)) abort(409, 'This idempotency key was already used for a different expense payment request.'); }
    private function money(array $data): array { $amount = Money::cents($data['amount'], 'amount'); $tax = Money::cents($data['taxAmount'] ?? '0', 'taxAmount'); if ($amount <= 0) throw ValidationException::withMessages(['amount' => 'Amount must be greater than zero.']); return [$amount, $tax]; }
    private function draftPayload(array $data, int $amount, int $tax, ?int $actorId): array { return ['branch_id' => $data['branchId'] ?? null, 'expense_category_id' => (int) $data['expenseCategoryId'], 'amount' => Money::decimal($amount), 'tax_amount' => Money::decimal($tax), 'total_amount' => Money::decimal($amount + $tax), 'expense_date' => $data['expenseDate'], 'description' => $data['description'], 'notes' => $data['notes'] ?? null, 'updated_at' => now()]; }
    private function assertDraftReferences(int $tenantId, array $data, ?int $actorId): void { $category = DB::table('expense_categories as c')->join('financial_accounts as a', 'a.id', '=', 'c.financial_account_id')->where('c.tenant_id', $tenantId)->where('c.id', $data['expenseCategoryId'])->where('c.is_active', true)->where('a.is_active', true)->whereIn('a.account_group', ['expense', 'expenses'])->whereNull('c.deleted_at')->whereNull('a.deleted_at')->exists(); if (! $category) throw ValidationException::withMessages(['expenseCategoryId' => 'Select an active tenant expense category.']); if (! empty($data['branchId'])) { if (! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $data['branchId'])->where('is_active', true)->whereNull('deleted_at')->exists()) throw ValidationException::withMessages(['branchId' => 'The branch does not belong to this tenant.']); $this->assertBranch($actorId, $tenantId, (int) $data['branchId']); } }
    private function assertBranch(?int $actorId, int $tenantId, mixed $branchId): void { FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId ? (int) $branchId : null); }
    private function nextNumber(int $tenantId): string { $last = DB::table('expenses')->where('tenant_id', $tenantId)->lockForUpdate()->orderByDesc('id')->value('expense_number'); $number = $last && preg_match('/(\d+)$/', $last, $match) ? ((int) $match[1] + 1) : 1; return 'EXP-'.str_pad((string) $number, 6, '0', STR_PAD_LEFT); }
}
