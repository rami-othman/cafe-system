<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class JournalEntryService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function createDraft(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        $this->assertBranch($tenantId, $data['branchId'] ?? null, $actorId);
        $this->validateLines($tenantId, $data['lines']);

        return DB::transaction(function () use ($request, $tenantId, $data, $actorId): int {
            $now = now();
            $entryId = (int) DB::table('journal_entries')->insertGetId([
                'tenant_id' => $tenantId,
                'branch_id' => $data['branchId'] ?? null,
                'entry_number' => $this->nextEntryNumber($tenantId, $data['entryDate']),
                'entry_date' => $data['entryDate'],
                'source_type' => $data['sourceType'] ?? 'manual',
                'source_id' => $data['sourceId'] ?? null,
                'description' => $data['description'] ?? null,
                'status' => 'draft',
                'created_by' => $actorId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            foreach (array_values($data['lines']) as $index => $line) {
                DB::table('journal_entry_lines')->insert([
                    'tenant_id' => $tenantId,
                    'journal_entry_id' => $entryId,
                    'financial_account_id' => (int) $line['accountId'],
                    'line_number' => $index + 1,
                    'description' => $line['description'] ?? null,
                    'debit' => Money::decimal(Money::cents($line['debit'] ?? '0', "lines.$index.debit")),
                    'credit' => Money::decimal(Money::cents($line['credit'] ?? '0', "lines.$index.credit")),
                    'created_by' => $actorId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            $entry = $this->find($tenantId, $entryId);
            $this->audit->record($request, $tenantId, 'journal_entry.draft_created', 'journal_entry', $entryId, [], $this->auditState($tenantId, $entryId), $entry->branch_id, $actorId);

            return $entryId;
        });
    }

    public function post(Request $request, int $tenantId, int $entryId, ?int $actorId): void
    {
        try {
            DB::transaction(function () use ($request, $tenantId, $entryId, $actorId): void {
                $entry = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('id', $entryId)->lockForUpdate()->first();
                abort_unless($entry, 404, 'Journal entry not found.');
                if ($entry->status !== 'draft') {
                    throw ValidationException::withMessages(['entry' => 'Only draft journal entries can be posted.']);
                }
                $this->assertBranch($tenantId, $entry->branch_id, $actorId);
                [$debit, $credit] = $this->totals($tenantId, $entryId);
                if ($debit <= 0 || $debit !== $credit) {
                    throw ValidationException::withMessages(['lines' => 'A journal entry must have equal, non-zero debit and credit totals before posting.']);
                }

                DB::table('journal_entries')->where('tenant_id', $tenantId)->where('id', $entryId)->update([
                    'status' => 'posted',
                    'posted_by' => $actorId,
                    'posted_at' => now(),
                    'updated_at' => now(),
                ]);
                $this->audit->record($request, $tenantId, 'journal_entry.posted', 'journal_entry', $entryId, (array) $entry, $this->auditState($tenantId, $entryId), $entry->branch_id, $actorId);
            });
        } catch (ValidationException $exception) {
            $entry = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('id', $entryId)->first();
            if ($entry) {
                $this->audit->record($request, $tenantId, 'journal_entry.posting_failed', 'journal_entry', $entryId, [], ['errors' => $exception->errors()], $entry->branch_id, $actorId);
            }
            throw $exception;
        }
    }

    public function find(int $tenantId, int $entryId): object
    {
        $entry = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('id', $entryId)->first();
        abort_unless($entry, 404, 'Journal entry not found.');

        return $entry;
    }

    /** @return array{0:int,1:int} */
    public function totals(int $tenantId, int $entryId): array
    {
        $debit = 0;
        $credit = 0;
        DB::table('journal_entry_lines')->where('tenant_id', $tenantId)->where('journal_entry_id', $entryId)->orderBy('line_number')->get()->each(function (object $line) use (&$debit, &$credit): void {
            $debit += Money::cents($line->debit, 'debit');
            $credit += Money::cents($line->credit, 'credit');
        });

        return [$debit, $credit];
    }

    private function validateLines(int $tenantId, array $lines): void
    {
        if (count($lines) < 2) {
            throw ValidationException::withMessages(['lines' => 'A journal entry requires at least two lines.']);
        }
        foreach (array_values($lines) as $index => $line) {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $line['accountId'])->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $account) {
                throw ValidationException::withMessages(["lines.$index.accountId" => 'The selected account is not active for this tenant.']);
            }
            $debit = Money::cents($line['debit'] ?? '0', "lines.$index.debit");
            $credit = Money::cents($line['credit'] ?? '0', "lines.$index.credit");
            if (($debit > 0) === ($credit > 0)) {
                throw ValidationException::withMessages(["lines.$index" => 'Each journal line must contain either a debit or a credit amount.']);
            }
        }
    }

    private function assertBranch(int $tenantId, mixed $branchId, ?int $actorId): void
    {
        if (! $branchId) {
            return;
        }
        if (! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages(['branchId' => 'The selected branch does not belong to this tenant.']);
        }
        FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $branchId);
    }

    private function nextEntryNumber(int $tenantId, string $date): string
    {
        $prefix = 'JE-'.str_replace('-', '', $date).'-';
        $count = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('entry_date', $date)->lockForUpdate()->count() + 1;

        return $prefix.str_pad((string) $count, 4, '0', STR_PAD_LEFT);
    }

    private function auditState(int $tenantId, int $entryId): array
    {
        $entry = $this->find($tenantId, $entryId);
        [$debit, $credit] = $this->totals($tenantId, $entryId);

        return [
            'entryNumber' => $entry->entry_number,
            'status' => $entry->status,
            'debitTotal' => Money::decimal($debit),
            'creditTotal' => Money::decimal($credit),
        ];
    }
}
