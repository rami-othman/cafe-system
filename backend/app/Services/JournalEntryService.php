<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class JournalEntryService
{
    public function __construct(private readonly OperationalAuditService $audit, private readonly AccountingPeriodGuard $periods) {}

    /**
     * Lines may carry their own 'branchId' (null = company-wide) and 'costCenterId'. A line
     * without the 'branchId' key inherits the entry's branch. When the lines span several
     * branches, every branch must balance on its own; with 'autoBalanceBranches' => true the
     * service adds the balancing lines on the inter-branch account (جاري الفروع) instead.
     */

    public function createOpeningDraft(Request $request, int $tenantId, int $periodId, array $data, int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $periodId, $data, $actorId): int {
            $period = DB::table('accounting_periods')->where('tenant_id', $tenantId)
                ->where('id', $periodId)->lockForUpdate()->first();
            abort_unless($period, 404, 'Accounting period not found.');
            if ($period->status !== 'open') {
                throw ValidationException::withMessages(['period' => 'القيد الافتتاحي يحتاج إلى سنة محاسبية مفتوحة.']);
            }
            if ($data['entryDate'] !== $period->start_date) {
                throw ValidationException::withMessages(['entryDate' => 'تاريخ القيد الافتتاحي يجب أن يساوي أول يوم في السنة المحاسبية.']);
            }
            if (DB::table('journal_entries')->where('tenant_id', $tenantId)->where('source_type', 'opening_balance')
                ->where('source_id', $periodId)->exists()) {
                throw ValidationException::withMessages(['period' => 'يوجد قيد افتتاحي لهذه السنة المحاسبية مسبقًا.']);
            }

            return $this->createDraft($request, $tenantId, [
                'entryDate' => $period->start_date,
                'branchId' => null,
                'sourceType' => 'opening_balance',
                'sourceId' => $periodId,
                'description' => $data['description'] ?? 'قيد افتتاحي — '.$period->name,
                'lines' => $data['lines'],
            ], $actorId);
        });
    }

    public function createDraft(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        $this->assertBranch($tenantId, $data['branchId'] ?? null, $actorId);
        $data['lines'] = $this->resolveLineDimensions($tenantId, $data, $actorId);
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
                'source_event' => $data['sourceEvent'] ?? null,
                'reversal_of_id' => $data['reversalOfId'] ?? null,
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
                    'financial_location_id' => isset($line['locationId']) ? (int) $line['locationId'] : null,
                    'branch_id' => $line['branchId'],
                    'cost_center_id' => $line['costCenterId'],
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
                // This is deliberately at the shared draft -> posted
                // transition: manual entries, automatic domain postings and
                // reversal entries all inherit the same financial-date lock.
                $this->periods->assertPostingAllowed($tenantId, $entry->entry_date);
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

    /**
     * Reverses a posted journal entry with a new, separate posted entry
     * whose debit/credit lines are swapped from the original.
     *
     * The original entry is never edited, deleted, or given a different
     * status — accounting history is immutable. "Has this entry been
     * reversed" is answered by whether another entry exists with
     * reversal_of_id pointing at it (see hasBeenReversed()), not by a status
     * value on the original, which would be ambiguous: a status like
     * "reversed" could be misread as meaning the entry's own posting was
     * undone, when in fact both the original and its reversal remain posted
     * forever, side by side, as two balanced entries.
     */
    /** Entries owned by a module ledger (assets, partners): reversing them directly would desync that ledger. */
    public const MODULE_MANAGED_SOURCES = [
        'asset_acquisition' => 'الأصول الثابتة', 'asset_addition' => 'الأصول الثابتة', 'asset_maintenance' => 'الأصول الثابتة', 'asset_expense' => 'الأصول الثابتة', 'asset_disposal' => 'الأصول الثابتة',
        'asset_transfer' => 'الأصول الثابتة', 'asset_depreciation' => 'مذكرات الاهتلاك',
        'partner_transaction' => 'الشركاء', 'profit_distribution' => 'توزيع الأرباح', 'overhead_allocation' => 'توزيع مصاريف الإدارة',
    ];

    public function reverse(Request $request, int $tenantId, int $entryId, ?int $actorId, bool $sourceManaged = false, ?string $reversalDate = null): int
    {
        return DB::transaction(function () use ($request, $tenantId, $entryId, $actorId, $sourceManaged, $reversalDate): int {
            $original = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('id', $entryId)->lockForUpdate()->first();
            abort_unless($original, 404, 'Journal entry not found.');
            if ($original->status !== 'posted') {
                throw ValidationException::withMessages(['entry' => 'Only a posted journal entry can be reversed.']);
            }
            if (! $sourceManaged && isset(self::MODULE_MANAGED_SOURCES[$original->source_type])) {
                throw ValidationException::withMessages(['entry' => 'هذا القيد ناتج عن شاشة «'.self::MODULE_MANAGED_SOURCES[$original->source_type].'»؛ اعكس العملية من هناك.']);
            }
            if ($original->source_type === 'sales_invoice'
                && DB::table('customer_payments')->where('tenant_id', $tenantId)
                    ->where('journal_entry_id', $entryId)->whereNotNull('direct_sales_invoice_id')->exists()) {
                throw ValidationException::withMessages(['entry' => 'عكس قيد البيع النقدي يحتاج إلى إجراء رد نقدي معتمد.']);
            }
            if ($original->source_type === 'cash_transfer'
                && DB::table('cash_transfers as transfers')
                    ->join('shifts', 'shifts.close_transfer_id', '=', 'transfers.id')
                    ->where('transfers.tenant_id', $tenantId)
                    ->where('transfers.journal_entry_id', $entryId)
                    ->where('shifts.tenant_id', $tenantId)->where('shifts.status', 'closed')->exists()) {
                throw ValidationException::withMessages(['entry' => 'A closed shift transfer cannot be reversed directly; an approved correction procedure is required.']);
            }
            $this->assertBranch($tenantId, $original->branch_id, $actorId);
            // $original is already locked above, so every concurrent
            // reverse() call against the same entry serializes here — the
            // second caller only reaches this check after the first
            // reversal (if any) has committed and become visible.
            if ($this->hasBeenReversed($tenantId, $entryId)) {
                throw ValidationException::withMessages(['entry' => 'This journal entry has already been reversed.']);
            }

            $lines = DB::table('journal_entry_lines')->where('tenant_id', $tenantId)->where('journal_entry_id', $entryId)->orderBy('line_number')->get();
            $now = now();
            $reversalOn = $reversalDate ?? $now->toDateString();
            $reversalId = (int) DB::table('journal_entries')->insertGetId([
                'tenant_id' => $tenantId,
                'branch_id' => $original->branch_id,
                'entry_number' => $this->nextEntryNumber($tenantId, $reversalOn),
                'entry_date' => $reversalOn,
                'source_type' => 'journal_reversal',
                'source_id' => $entryId,
                'source_event' => null,
                'reversal_of_id' => $entryId,
                'description' => 'عكس القيد '.$original->entry_number.($original->description ? ' — '.$original->description : ''),
                'status' => 'draft',
                'created_by' => $actorId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            foreach ($lines as $index => $line) {
                DB::table('journal_entry_lines')->insert([
                    'tenant_id' => $tenantId,
                    'journal_entry_id' => $reversalId,
                    'financial_account_id' => $line->financial_account_id,
                    'financial_location_id' => $line->financial_location_id,
                    'branch_id' => $line->branch_id ?? $original->branch_id,
                    'cost_center_id' => $line->cost_center_id ?? null,
                    'line_number' => $index + 1,
                    'description' => $line->description,
                    'debit' => $line->credit,
                    'credit' => $line->debit,
                    'created_by' => $actorId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            // Reuses the existing post() transition: re-locks the draft,
            // re-checks debit == credit (defense in depth against a
            // corrupted swap), and marks it posted — the same guarantee
            // every other journal entry gets.
            $this->post($request, $tenantId, $reversalId, $actorId);

            $this->audit->record($request, $tenantId, 'journal_entry.reversed', 'journal_entry', $entryId, [], ['reversalEntryId' => $reversalId, 'reversalEntryNumber' => $this->find($tenantId, $reversalId)->entry_number], $original->branch_id, $actorId);

            return $reversalId;
        });
    }

    public function hasBeenReversed(int $tenantId, int $entryId): bool
    {
        return DB::table('journal_entries')->where('tenant_id', $tenantId)->where('reversal_of_id', $entryId)->exists();
    }

    public function find(int $tenantId, int $entryId): object
    {
        $entry = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('id', $entryId)->first();
        abort_unless($entry, 404, 'Journal entry not found.');

        return $entry;
    }

    /** @return array{0:int,1:int} */
    public function totals(int $tenantId, int $entryId, array $excludeAccountIds = []): array
    {
        $debit = 0;
        $credit = 0;
        DB::table('journal_entry_lines')->where('tenant_id', $tenantId)->where('journal_entry_id', $entryId)
            ->when($excludeAccountIds !== [], fn ($q) => $q->whereNotIn('financial_account_id', $excludeAccountIds))->orderBy('line_number')->get()->each(function (object $line) use (&$debit, &$credit): void {
            $debit += Money::cents($line->debit, 'debit');
            $credit += Money::cents($line->credit, 'credit');
        });

        return [$debit, $credit];
    }

    /** @return array<int, array<string,mixed>> lines with explicit branchId / costCenterId (+ inter-branch balancing lines) */
    private function resolveLineDimensions(int $tenantId, array $data, ?int $actorId): array
    {
        $headerBranch = isset($data['branchId']) && $data['branchId'] ? (int) $data['branchId'] : null;
        $lines = [];
        $checkedBranches = [];
        foreach (array_values($data['lines']) as $index => $line) {
            $branch = array_key_exists('branchId', $line) ? ($line['branchId'] ? (int) $line['branchId'] : null) : $headerBranch;
            if ($branch !== null && $branch !== $headerBranch && ! isset($checkedBranches[$branch])) {
                $this->assertBranch($tenantId, $branch, $actorId);
                $checkedBranches[$branch] = true;
            }
            $costCenter = isset($line['costCenterId']) && $line['costCenterId'] ? (int) $line['costCenterId'] : null;
            if ($costCenter !== null && ! DB::table('cost_centers')->where('tenant_id', $tenantId)->where('id', $costCenter)
                ->where('is_active', true)->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(["lines.$index.costCenterId" => 'مركز الكلفة غير متاح.']);
            }
            $lines[] = ['branchId' => $branch, 'costCenterId' => $costCenter] + $line;
        }

        $net = [];
        foreach ($lines as $index => $line) {
            $key = $line['branchId'] === null ? 'company' : (string) $line['branchId'];
            $net[$key] = ($net[$key] ?? 0)
                + Money::cents($line['debit'] ?? '0', "lines.$index.debit")
                - Money::cents($line['credit'] ?? '0', "lines.$index.credit");
        }
        if (count($net) < 2 || array_filter($net) === []) {
            return $lines;
        }
        if (! ($data['autoBalanceBranches'] ?? false)) {
            throw ValidationException::withMessages(['lines' => 'القيد موزع على أكثر من فرع: يجب أن يتوازن كل فرع لوحده (أو استخدم حساب جاري الفروع).']);
        }
        $clearing = app(InterBranchAccount::class)->id($tenantId);
        foreach ($net as $key => $cents) {
            if ($cents === 0) {
                continue;
            }
            $lines[] = [
                'accountId' => $clearing,
                'branchId' => $key === 'company' ? null : (int) $key,
                'costCenterId' => null,
                'description' => 'موازنة جاري الفروع',
                'debit' => $cents < 0 ? Money::decimal(-$cents) : '0.00',
                'credit' => $cents > 0 ? Money::decimal($cents) : '0.00',
            ];
        }

        return $lines;
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
        // PostgreSQL rejects FOR UPDATE on aggregate queries.  Locking the
        // tenant row serializes per-tenant numbering while retaining the
        // existing deterministic daily sequence across all supported DBs.
        DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->first();
        $count = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('entry_date', $date)->count() + 1;

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
