<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Read-only financial ledger query. Balances are always derived from posted
 * journal lines; no Cash/Bank business table contains an authoritative total.
 */
class FinancialAccountBalanceQuery
{
    /** Actual posted cash movements before a UTC instant, independent of date-only labels. */
    public function balanceBefore(int $tenantId, int $accountId, int $locationId, string $end): string
    {
        $account = $this->account($tenantId, $accountId);
        $lines = $this->baseLines($tenantId, $accountId, null, null, $locationId)
            ->whereRaw('COALESCE(entries.posted_at, entries.created_at) < ?', [$end])->get(['lines.debit', 'lines.credit']);

        return Money::decimal($this->normalisedBalance($account->normal_balance,
            $lines->sum(fn ($line) => Money::cents($line->debit)),
            $lines->sum(fn ($line) => Money::cents($line->credit))));
    }

    public function summary(int $tenantId, int $accountId, ?string $from = null, ?string $to = null, ?int $locationId = null, bool $externalOnly = false): array
    {
        $account = $this->account($tenantId, $accountId);
        $all = $this->lines($tenantId, $accountId, null, $to, $locationId);
        $period = $this->lines($tenantId, $accountId, $from, $to, $locationId, $externalOnly);
        $allDebit = $all->sum(fn (object $line) => Money::cents($line->debit));
        $allCredit = $all->sum(fn (object $line) => Money::cents($line->credit));
        $periodDebit = $period->sum(fn (object $line) => Money::cents($line->debit));
        $periodCredit = $period->sum(fn (object $line) => Money::cents($line->credit));

        return [
            'balance' => Money::decimal($this->normalisedBalance($account->normal_balance, $allDebit, $allCredit)),
            'periodDebit' => Money::decimal($periodDebit),
            'periodCredit' => Money::decimal($periodCredit),
            'incoming' => Money::decimal($account->normal_balance === 'debit' ? $periodDebit : $periodCredit),
            'outgoing' => Money::decimal($account->normal_balance === 'debit' ? $periodCredit : $periodDebit),
        ];
    }

    /** Current balance + total debit/credit/last movement for one account, rolled up with all of its descendant accounts — posted lines only. */
    public function balanceWithChildren(int $tenantId, int $accountId): array
    {
        return $this->balancesForAccounts($tenantId, [$accountId])[$accountId]
            ?? ['balance' => '0.00', 'totalDebit' => '0.00', 'totalCredit' => '0.00', 'lastMovementDate' => null];
    }

    /**
     * Same as balanceWithChildren(), batched for many accounts in exactly 2
     * queries total (the account hierarchy, then one grouped aggregate over
     * posted journal lines) — never one balance query per account, however
     * many accounts are requested.
     *
     * @param array<int, int> $accountIds
     * @return array<int, array{balance:string, totalDebit:string, totalCredit:string, lastMovementDate:?string}>
     */
    public function balancesForAccounts(int $tenantId, array $accountIds): array
    {
        if ($accountIds === []) {
            return [];
        }
        $all = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')->get(['id', 'parent_account_id', 'normal_balance'])->keyBy('id');
        $childrenByParent = [];
        foreach ($all as $row) {
            if ($row->parent_account_id) {
                $childrenByParent[(int) $row->parent_account_id][] = (int) $row->id;
            }
        }
        $descendantIds = function (int $id) use (&$descendantIds, $childrenByParent): array {
            $ids = [$id];
            foreach ($childrenByParent[$id] ?? [] as $childId) {
                $ids = [...$ids, ...$descendantIds($childId)];
            }

            return $ids;
        };
        $movements = DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->where('lines.tenant_id', $tenantId)->where('entries.tenant_id', $tenantId)->where('entries.status', 'posted')
            ->groupBy('lines.financial_account_id')
            ->selectRaw('lines.financial_account_id, COALESCE(SUM(lines.debit),0) as debit, COALESCE(SUM(lines.credit),0) as credit, MAX(entries.entry_date) as last_date')
            ->get()->keyBy('financial_account_id');

        $result = [];
        foreach ($accountIds as $accountId) {
            $account = $all->get($accountId);
            if (! $account) {
                continue;
            }
            $debit = 0;
            $credit = 0;
            $lastDate = null;
            foreach ($descendantIds($accountId) as $id) {
                $row = $movements->get($id);
                if (! $row) {
                    continue;
                }
                $debit += Money::cents($row->debit);
                $credit += Money::cents($row->credit);
                if ($row->last_date !== null && ($lastDate === null || $row->last_date > $lastDate)) {
                    $lastDate = $row->last_date;
                }
            }
            $result[$accountId] = [
                'balance' => Money::decimal($this->normalisedBalance($account->normal_balance, $debit, $credit)),
                'totalDebit' => Money::decimal($debit),
                'totalCredit' => Money::decimal($credit),
                'lastMovementDate' => $lastDate,
            ];
        }

        return $result;
    }

    public function transactions(int $tenantId, int $accountId, ?string $from = null, ?string $to = null, ?string $search = null, ?int $locationId = null): array
    {
        $account = $this->account($tenantId, $accountId);
        $opening = $this->summary($tenantId, $accountId, null, $from ? now()->parse($from)->subDay()->toDateString() : null, $locationId)['balance'];
        $running = Money::cents($opening);
        $query = $this->baseLines($tenantId, $accountId, $from, $to, $locationId);
        if ($search) {
            $needle = '%'.strtolower($search).'%';
            $query->where(fn ($items) => $items->whereRaw('LOWER(entries.entry_number) LIKE ?', [$needle])->orWhereRaw('LOWER(COALESCE(entries.description, \'\')) LIKE ?', [$needle])->orWhereRaw('LOWER(COALESCE(entries.source_type, \'\')) LIKE ?', [$needle]));
        }
        $rows = $query->orderBy('entries.entry_date')->orderBy('entries.id')->orderBy('lines.line_number')->get();

        return $rows->map(function (object $line) use (&$running, $account): array {
            $debit = Money::cents($line->debit);
            $credit = Money::cents($line->credit);
            $running += $this->normalisedBalance($account->normal_balance, $debit, $credit);

            return ['id' => (int) $line->id, 'date' => $line->entry_date, 'journalEntryId' => (int) $line->journal_entry_id, 'entryNumber' => $line->entry_number, 'sourceType' => $line->source_type, 'description' => $line->line_description ?? $line->entry_description, 'debit' => Money::decimal($debit), 'credit' => Money::decimal($credit), 'runningBalance' => Money::decimal($running), 'status' => $line->status];
        })->values()->all();
    }

    private function lines(int $tenantId, int $accountId, ?string $from, ?string $to, ?int $locationId = null, bool $externalOnly = false)
    {
        $query = $this->baseLines($tenantId, $accountId, $from, $to, $locationId);
        if ($externalOnly) {
            $query->where('entries.source_type', '<>', 'cash_transfer')->whereNotExists(fn ($reversal) => $reversal->selectRaw('1')->from('journal_entries as originals')->whereColumn('originals.id', 'entries.reversal_of_id')->where('originals.tenant_id', $tenantId)->where('originals.source_type', 'cash_transfer'));
        }

        return $query->get(['lines.debit', 'lines.credit']);
    }

    private function baseLines(int $tenantId, int $accountId, ?string $from, ?string $to, ?int $locationId = null)
    {
        $query = DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')->where('lines.tenant_id', $tenantId)->where('lines.financial_account_id', $accountId)->where('entries.tenant_id', $tenantId)->where('entries.status', 'posted')->select('lines.*', 'entries.entry_date', 'entries.entry_number', 'entries.source_type', 'entries.description as entry_description', 'lines.description as line_description', 'entries.status');
        if ($from) {
            $query->whereDate('entries.entry_date', '>=', $from);
        }
        if ($to) {
            $query->whereDate('entries.entry_date', '<=', $to);
        }
        if ($locationId !== null) {
            $query->where('lines.financial_location_id', $locationId);
        }

        return $query;
    }

    private function account(int $tenantId, int $accountId): object
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->whereNull('deleted_at')->first();
        if (! $account) {
            throw ValidationException::withMessages(['financialAccountId' => 'الحساب المالي غير موجود لهذا المستأجر.']);
        }

        return $account;
    }

    private function normalisedBalance(string $normalBalance, int $debit, int $credit): int
    {
        return $normalBalance === 'credit' ? $credit - $debit : $debit - $credit;
    }
}
