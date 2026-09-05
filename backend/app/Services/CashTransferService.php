<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CashTransferService
{
    public function __construct(private readonly AccountingPostingService $posting, private readonly JournalEntryService $entries, private readonly OperationalAuditService $audit) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'] ?? null;
        $fingerprint = $key ? IdempotencyFingerprint::from($data) : null;
        if ($key && ($existing = $this->byKey($tenantId, $key)) !== null) { $this->assertFingerprint($existing, $fingerprint); return $existing; }
        $amount = Money::cents($data['amount'], 'amount');
        if ($amount <= 0) throw ValidationException::withMessages(['amount' => 'Amount must be greater than zero.']);

        try {
            return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $key, $fingerprint, $amount): object {
                if ($key && ($existing = $this->byKey($tenantId, $key, true)) !== null) { $this->assertFingerprint($existing, $fingerprint); return $existing; }
                $location = fn (int $locationId) => DB::table('financial_locations as locations')->join('financial_accounts as accounts', 'accounts.id', '=', 'locations.financial_account_id')->where('locations.tenant_id', $tenantId)->where('locations.id', $locationId)->where('locations.is_active', true)->where('accounts.is_active', true)->whereNull('accounts.deleted_at')->select('locations.*', 'accounts.code as account_code')->lockForUpdate()->first();
                $from = $location((int) $data['fromFinancialLocationId']);
                $to = $location((int) $data['toFinancialLocationId']);
                if (! $from || ! $to) throw ValidationException::withMessages(['account' => 'Both cash or bank accounts must be active and belong to this tenant.']);
                if ($from->id === $to->id) throw ValidationException::withMessages(['toFinancialLocationId' => 'Source and destination must differ.']);
                FinancialActor::assertBranchAccess($actorId, $tenantId, $from->branch_id ? (int) $from->branch_id : null);
                FinancialActor::assertBranchAccess($actorId, $tenantId, $to->branch_id ? (int) $to->branch_id : null);
                $branchId = $data['branchId'] ?? $from->branch_id ?? $to->branch_id;
                if ($branchId) FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $branchId);
                $now = now();
                $id = (int) DB::table('cash_transfers')->insertGetId(['tenant_id' => $tenantId, 'branch_id' => $branchId, 'from_financial_location_id' => $from->id, 'to_financial_location_id' => $to->id, 'amount' => Money::decimal($amount), 'transfer_date' => $data['transferDate'], 'description' => $data['description'] ?? null, 'status' => 'posting', 'idempotency_key' => $key, 'idempotency_fingerprint' => $fingerprint, 'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now]);
                $journalId = $this->posting->postCashTransfer($request, $tenantId, ['branchId' => $branchId, 'sourceId' => $id, 'sourceEvent' => 'CASH_TRANSFER_POSTED', 'entryDate' => $data['transferDate'], 'description' => $data['description'] ?? "Cash transfer {$id}", 'lines' => [['accountCode' => $to->account_code, 'debit' => Money::decimal($amount), 'credit' => '0.00'], ['accountCode' => $from->account_code, 'debit' => '0.00', 'credit' => Money::decimal($amount)]]], $actorId);
                DB::table('cash_transfers')->where('tenant_id', $tenantId)->where('id', $id)->update(['status' => 'posted', 'journal_entry_id' => $journalId, 'updated_at' => now()]);
                $transfer = $this->find($tenantId, $id);
                $this->audit->record($request, $tenantId, 'cash_transfer.posted', 'cash_transfer', $id, [], (array) $transfer, $branchId, $actorId);
                return $transfer;
            });
        } catch (QueryException $exception) {
            if ($key && ($existing = $this->byKey($tenantId, $key)) !== null) { $this->assertFingerprint($existing, $fingerprint); return $existing; }
            throw $exception;
        }
    }

    public function reverse(Request $request, int $tenantId, int $id, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId): object {
            $transfer = DB::table('cash_transfers')->where('tenant_id', $tenantId)->where('id', $id)->lockForUpdate()->first();
            abort_unless($transfer, 404, 'Cash transfer not found.');
            if ($transfer->status !== 'posted' || ! $transfer->journal_entry_id) throw ValidationException::withMessages(['transfer' => 'Only a posted transfer can be reversed.']);
            if ($transfer->reversal_journal_entry_id) throw ValidationException::withMessages(['transfer' => 'This transfer was already reversed.']);
            FinancialActor::assertBranchAccess($actorId, $tenantId, $transfer->branch_id ? (int) $transfer->branch_id : null);
            $reversal = $this->entries->reverse($request, $tenantId, (int) $transfer->journal_entry_id, $actorId);
            DB::table('cash_transfers')->where('tenant_id', $tenantId)->where('id', $id)->update(['status' => 'reversed', 'reversal_journal_entry_id' => $reversal, 'updated_at' => now()]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'cash_transfer.reversed', 'cash_transfer', $id, [], (array) $result, $transfer->branch_id, $actorId);
            return $result;
        });
    }

    public function find(int $tenantId, int $id): object { $row = DB::table('cash_transfers')->where('tenant_id', $tenantId)->where('id', $id)->first(); abort_unless($row, 404, 'Cash transfer not found.'); return $row; }
    private function byKey(int $tenantId, string $key, bool $lock = false): ?object { $query = DB::table('cash_transfers')->where('tenant_id', $tenantId)->where('idempotency_key', $key); if ($lock) $query->lockForUpdate(); return $query->first(); }
    private function assertFingerprint(object $existing, ?string $fingerprint): void { if ($fingerprint === null || ! $existing->idempotency_fingerprint || ! hash_equals($existing->idempotency_fingerprint, $fingerprint)) abort(409, 'This idempotency key was already used for a different transfer request.'); }
}
