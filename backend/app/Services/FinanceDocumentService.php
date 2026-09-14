<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Receipt and payment vouchers are document metadata around the one existing
 * General Ledger poster.  The document never maintains a second balance.
 */
final class FinanceDocumentService
{
    public function __construct(
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
    ) {}

    public function createDraft(Request $request, int $tenantId, array $data, ?int $actorId): object
    {
        $this->validatePayload($tenantId, $data, $actorId);
        $key = $data['idempotencyKey'] ?? null;
        $fingerprint = $key ? IdempotencyFingerprint::from($data) : null;

        return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $key, $fingerprint): object {
            if ($key && ($existing = $this->byKey($tenantId, $key, true))) {
                $this->assertFingerprint($existing, $fingerprint);
                return $existing;
            }
            $now = now();
            $id = (int) DB::table('finance_documents')->insertGetId([
                'tenant_id' => $tenantId,
                'branch_id' => $data['branchId'] ?? null,
                'document_number' => $this->nextNumber($tenantId, $data['documentType'], $data['documentDate']),
                'document_type' => $data['documentType'],
                'status' => 'draft',
                'document_date' => $data['documentDate'],
                'financial_location_id' => $data['financialLocationId'],
                'counterparty_type' => $data['counterpartyType'] ?? null,
                'counterparty_id' => $data['counterpartyId'] ?? null,
                'currency_code' => $data['currencyCode'] ?? 'SYP',
                'exchange_rate' => $data['exchangeRate'] ?? '1.000000',
                'amount' => Money::decimal(Money::cents($data['amount'], 'amount')),
                'external_reference' => $data['externalReference'] ?? null,
                'description' => $data['description'] ?? null,
                'notes' => $data['notes'] ?? null,
                'idempotency_key' => $key,
                'idempotency_fingerprint' => $fingerprint,
                'created_by' => $actorId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            foreach (array_values($this->postingLines($tenantId, $data)) as $index => $line) {
                DB::table('finance_document_lines')->insert([
                    'tenant_id' => $tenantId, 'finance_document_id' => $id,
                    'financial_account_id' => $line['accountId'], 'line_number' => $index + 1,
                    'description' => $line['description'] ?? null,
                    'debit' => Money::decimal($line['debit']), 'credit' => Money::decimal($line['credit']),
                    'cost_center' => $line['costCenter'] ?? null, 'reference' => $line['reference'] ?? null,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
            }
            $document = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'finance_document.draft_created', 'finance_document', $id, [], ['number' => $document->document_number, 'type' => $document->document_type], $document->branch_id, $actorId);
            return $document;
        });
    }

    public function post(Request $request, int $tenantId, int $id, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId): object {
            $document = DB::table('finance_documents')->where('tenant_id', $tenantId)->where('id', $id)->lockForUpdate()->first();
            abort_unless($document, 404, 'Finance document not found.');
            if ($document->status !== 'draft') {
                throw ValidationException::withMessages(['document' => 'Only draft vouchers can be posted.']);
            }
            FinancialActor::assertBranchAccess($actorId, $tenantId, $document->branch_id ? (int) $document->branch_id : null);
            $lines = DB::table('finance_document_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
                ->where('lines.tenant_id', $tenantId)->where('lines.finance_document_id', $id)
                ->orderBy('lines.line_number')->get(['accounts.code', 'lines.debit', 'lines.credit', 'lines.description']);
            $journalId = $this->posting->post($request, $tenantId, [
                'branchId' => $document->branch_id,
                'sourceType' => 'finance_document', 'sourceId' => $id, 'sourceEvent' => 'FINANCE_DOCUMENT_POSTED',
                'entryDate' => $document->document_date,
                'description' => $document->document_number.($document->description ? ' — '.$document->description : ''),
                'lines' => $lines->map(fn (object $line) => ['accountCode' => $line->code, 'debit' => $line->debit, 'credit' => $line->credit, 'description' => $line->description])->all(),
            ], $actorId);
            DB::table('finance_documents')->where('tenant_id', $tenantId)->where('id', $id)->update(['status' => 'posted', 'journal_entry_id' => $journalId, 'posted_by' => $actorId, 'posted_at' => now(), 'updated_at' => now()]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'finance_document.posted', 'finance_document', $id, [], ['number' => $result->document_number, 'journalEntryId' => $journalId], $result->branch_id, $actorId);
            return $result;
        });
    }

    public function reverse(Request $request, int $tenantId, int $id, string $reason, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $reason, $actorId): object {
            $document = DB::table('finance_documents')->where('tenant_id', $tenantId)->where('id', $id)->lockForUpdate()->first();
            abort_unless($document, 404, 'Finance document not found.');
            if ($document->status !== 'posted' || ! $document->journal_entry_id || $document->reversal_journal_entry_id) {
                throw ValidationException::withMessages(['document' => 'Only an unreversed posted voucher can be reversed.']);
            }
            FinancialActor::assertBranchAccess($actorId, $tenantId, $document->branch_id ? (int) $document->branch_id : null);
            $reversal = $this->entries->reverse($request, $tenantId, (int) $document->journal_entry_id, $actorId);
            DB::table('finance_documents')->where('tenant_id', $tenantId)->where('id', $id)->update([
                'status' => 'reversed', 'reversal_journal_entry_id' => $reversal,
                'reversed_at' => now(), 'reversed_by' => $actorId, 'reversal_reason' => $reason, 'updated_at' => now(),
            ]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'finance_document.reversed', 'finance_document', $id, [], ['number' => $result->document_number, 'reversalJournalEntryId' => $reversal, 'reason' => $reason], $result->branch_id, $actorId);
            return $result;
        });
    }

    public function find(int $tenantId, int $id): object
    {
        $row = DB::table('finance_documents')->where('tenant_id', $tenantId)->where('id', $id)->first();
        abort_unless($row, 404, 'Finance document not found.');
        return $row;
    }

    /** @return array<int, array{accountId:int,debit:int,credit:int,description:?string,costCenter?:?string,reference?:?string}> */
    private function postingLines(int $tenantId, array $data): array
    {
        $locationAccount = (int) DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $data['financialLocationId'])->value('financial_account_id');
        $amount = Money::cents($data['amount'], 'amount');
        $lines = $data['lines'];
        $result = [[
            'accountId' => $locationAccount,
            'debit' => $data['documentType'] === 'receipt' ? $amount : 0,
            'credit' => $data['documentType'] === 'payment' ? $amount : 0,
            'description' => $data['description'] ?? null,
        ]];
        foreach ($lines as $line) {
            $lineAmount = Money::cents($line['amount'], 'lines.amount');
            $result[] = [
                'accountId' => (int) $line['accountId'],
                'debit' => $data['documentType'] === 'payment' ? $lineAmount : 0,
                'credit' => $data['documentType'] === 'receipt' ? $lineAmount : 0,
                'description' => $line['description'] ?? null,
                'costCenter' => $line['costCenter'] ?? null,
                'reference' => $line['reference'] ?? null,
            ];
        }
        return $result;
    }

    private function validatePayload(int $tenantId, array $data, ?int $actorId): void
    {
        $amount = Money::cents($data['amount'], 'amount');
        if ($amount <= 0) throw ValidationException::withMessages(['amount' => 'Amount must be greater than zero.']);
        $location = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $data['financialLocationId'])->where('is_active', true)->first();
        if (! $location) throw ValidationException::withMessages(['financialLocationId' => 'The selected cash or bank account is not active for this tenant.']);
        $branchId = $data['branchId'] ?? $location->branch_id;
        if ($branchId && ! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages(['branchId' => 'The selected branch does not belong to this tenant.']);
        }
        FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId ? (int) $branchId : null);
        if (($data['counterpartyType'] ?? null) === 'supplier') throw ValidationException::withMessages(['counterpartyType' => 'Supplier invoice payments must use the existing supplier payment workflow to avoid double posting.']);
        $distributed = 0;
        foreach ($data['lines'] as $index => $line) {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $line['accountId'])->where('is_active', true)->whereNull('deleted_at')->exists();
            if (! $account) throw ValidationException::withMessages(["lines.$index.accountId" => 'The selected account is not active for this tenant.']);
            $distributed += Money::cents($line['amount'], "lines.$index.amount");
        }
        if ($distributed !== $amount) throw ValidationException::withMessages(['lines' => 'The distributed amount must exactly equal the voucher amount.']);
    }

    private function nextNumber(int $tenantId, string $type, string $date): string
    {
        $prefix = $type === 'receipt' ? 'RV' : 'PV';
        DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->first();
        $count = DB::table('finance_documents')->where('tenant_id', $tenantId)->where('document_type', $type)->whereYear('document_date', substr($date, 0, 4))->count() + 1;
        return $prefix.'-'.substr($date, 0, 4).'-'.str_pad((string) $count, 6, '0', STR_PAD_LEFT);
    }

    private function byKey(int $tenantId, string $key, bool $lock = false): ?object
    {
        $query = DB::table('finance_documents')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) $query->lockForUpdate();
        return $query->first();
    }

    private function assertFingerprint(object $existing, ?string $fingerprint): void
    {
        if ($fingerprint === null || ! $existing->idempotency_fingerprint || ! hash_equals($existing->idempotency_fingerprint, $fingerprint)) abort(409, 'This idempotency key was already used for a different voucher request.');
    }
}
