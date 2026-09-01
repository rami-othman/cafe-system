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
    public function summary(int $tenantId, int $accountId, ?string $from = null, ?string $to = null): array
    {
        $account = $this->account($tenantId, $accountId);
        $all = $this->lines($tenantId, $accountId, null, $to);
        $period = $this->lines($tenantId, $accountId, $from, $to);
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

    public function transactions(int $tenantId, int $accountId, ?string $from = null, ?string $to = null, ?string $search = null): array
    {
        $account = $this->account($tenantId, $accountId);
        $opening = $this->summary($tenantId, $accountId, null, $from ? now()->parse($from)->subDay()->toDateString() : null)['balance'];
        $running = Money::cents($opening);
        $query = $this->baseLines($tenantId, $accountId, $from, $to);
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

    private function lines(int $tenantId, int $accountId, ?string $from, ?string $to)
    {
        return $this->baseLines($tenantId, $accountId, $from, $to)->get(['lines.debit', 'lines.credit']);
    }

    private function baseLines(int $tenantId, int $accountId, ?string $from, ?string $to)
    {
        $query = DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')->where('lines.tenant_id', $tenantId)->where('lines.financial_account_id', $accountId)->where('entries.tenant_id', $tenantId)->where('entries.status', 'posted')->select('lines.*', 'entries.entry_date', 'entries.entry_number', 'entries.source_type', 'entries.description as entry_description', 'lines.description as line_description', 'entries.status');
        if ($from) $query->whereDate('entries.entry_date', '>=', $from);
        if ($to) $query->whereDate('entries.entry_date', '<=', $to);

        return $query;
    }

    private function account(int $tenantId, int $accountId): object
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->whereNull('deleted_at')->first();
        if (! $account) throw ValidationException::withMessages(['financialAccountId' => 'Financial account was not found for this tenant.']);

        return $account;
    }

    private function normalisedBalance(string $normalBalance, int $debit, int $credit): int
    {
        return $normalBalance === 'credit' ? $credit - $debit : $debit - $credit;
    }
}
