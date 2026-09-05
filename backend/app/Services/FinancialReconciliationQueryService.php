<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

final class FinancialReconciliationQueryService
{
    public function __construct(
        private readonly DailyClosingSummaryService $dailyClosingSummary,
        private readonly DailyClosingReconciliationPolicy $dailyClosingPolicy,
    ) {}

    public function list(int $tenant, int $actor, array $filters): array { $q = $this->visible($tenant, $actor); if (! empty($filters['status'])) $q->where('sessions.status', $filters['status']); if (! empty($filters['type'])) $q->where('sessions.type', $filters['type']); if (! empty($filters['financialLocationId'])) $q->where('sessions.financial_location_id', $filters['financialLocationId']); if (! empty($filters['from'])) $q->whereDate('sessions.date_to', '>=', $filters['from']); if (! empty($filters['to'])) $q->whereDate('sessions.date_from', '<=', $filters['to']); if (! empty($filters['search'])) $q->where('sessions.reference', 'like', '%'.$filters['search'].'%'); $p = $q->orderByDesc('sessions.date_to')->orderByDesc('sessions.id')->paginate($filters['perPage'] ?? 25); return ['data' => collect($p->items())->map(fn (object $s) => $this->serialize($tenant, $s))->values(), 'meta' => ['currentPage' => $p->currentPage(), 'perPage' => $p->perPage(), 'total' => $p->total(), 'lastPage' => $p->lastPage()]]; }
    public function detail(int $tenant, int $actor, int $id): array { $session = $this->visible($tenant, $actor)->where('sessions.id', $id)->first(); abort_unless($session, 404, 'Reconciliation not found.'); $data = $this->serialize($tenant, $session); $data['statementLines'] = $this->lines($tenant, $id); $data['matches'] = $this->matches($tenant, $id); return $data; }
    public function systemTransactions(int $tenant, int $actor, int $id): array { $session = $this->visible($tenant, $actor)->where('sessions.id', $id)->first(); abort_unless($session, 404); return $this->transactionRows($tenant, $session); }
    public function suggestions(int $tenant, int $actor, int $id): array { $session = $this->visible($tenant, $actor)->where('sessions.id', $id)->first(); abort_unless($session, 404); $transactions = collect($this->systemTransactions($tenant, $actor, $id))->filter(fn (array $t) => Money::cents($t['amount']) > Money::cents($t['matchedAmount'])); return collect($this->lines($tenant, $id))->filter(fn (array $line) => Money::cents($line['remainingAmount']) > 0)->map(function (array $line) use ($transactions): array { $candidates = $transactions->filter(fn (array $t) => $t['direction'] === $line['direction'] && $t['amount'] === $line['remainingAmount'] && abs(now()->parse($t['date'])->diffInDays(now()->parse($line['transactionDate']))) <= 3)->values(); return ['statementLineId' => $line['id'], 'confidence' => $candidates->count() === 1 ? 'high' : ($candidates->isEmpty() ? null : 'possible'), 'candidates' => $candidates->take(5)->all()]; })->values()->all(); }
    public function blockers(int $tenant, object $session): array { $reasons = []; if ($session->status === 'completed') return ['SESSION_ALREADY_COMPLETED']; if ($session->type === 'cash' && $session->actual_cash_count === null) $reasons[] = 'MISSING_ACTUAL_CASH_COUNT'; if ($session->type !== 'cash' && $session->external_closing_balance === null) $reasons[] = 'MISSING_EXTERNAL_CLOSING_BALANCE'; if ($session->difference === null || $this->signedCents($session->difference) !== 0) $reasons[] = 'NON_ZERO_DIFFERENCE'; if ($session->type !== 'cash') { $lines = $this->lines($tenant, $session->id); if (collect($lines)->contains(fn (array $line) => Money::cents($line['remainingAmount']) !== 0)) $reasons[] = 'UNMATCHED_STATEMENT_LINES'; if (collect($this->transactionRows($tenant, $session))->contains(fn (array $entry) => $entry['amount'] !== $entry['matchedAmount'])) $reasons[] = 'UNMATCHED_SYSTEM_TRANSACTIONS'; } return $reasons; }

    /** Compact Phase 8/9-owned reconciliation state for the Finance Dashboard. */
    public function summaryForFinanceContext(int $tenant, int $actor, array $context): array
    {
        $sessions = $this->visible($tenant, $actor)
            ->whereDate('sessions.date_to', '>=', $context['dateFrom'])
            ->whereDate('sessions.date_from', '<=', $context['dateTo'])
            ->get(['sessions.type', 'sessions.status']);

        $types = [];
        foreach (['cash', 'card', 'bank'] as $type) {
            $subset = $sessions->where('type', $type);
            $types[$type] = ['sessionCount' => $subset->count(), 'completedCount' => $subset->where('status', 'completed')->count(), 'incompleteSessionCount' => $subset->where('status', '!=', 'completed')->count(), 'requiredCount' => 0, 'incompleteRequiredCount' => 0];
        }

        $incomplete = [];
        $accountIds = [];
        foreach ($context['scopeBranchIds'] as $branchId) {
            for ($date = CarbonImmutable::parse($context['dateFrom']); $date->lte(CarbonImmutable::parse($context['dateTo'])); $date = $date->addDay()) {
                $businessDate = $date->toDateString();
                $summary = $this->dailyClosingSummary->summarize($tenant, (int) $branchId, $businessDate);
                $policy = $this->dailyClosingPolicy->evaluate($tenant, (int) $branchId, $businessDate, $summary);
                foreach ($policy['accounts'] as $requirement) {
                    $type = $requirement['kind'];
                    $types[$type]['requiredCount']++;
                    if ($requirement['complete']) continue;
                    $types[$type]['incompleteRequiredCount']++;
                    $ids = array_map('intval', $requirement['financialAccountIds'] ?? [$requirement['financialAccountId']]);
                    foreach ($ids as $id) $accountIds[$id] = true;
                    $incomplete[] = ['type' => $type, 'branchId' => (int) $branchId, 'date' => $businessDate, 'financialAccountIds' => $ids, 'severity' => $type === 'cash' ? 'blocking' : 'warning'];
                }
            }
        }

        $accounts = DB::table('financial_accounts')->where('tenant_id', $tenant)->whereIn('id', array_keys($accountIds))->get(['id', 'code', 'name_ar', 'name_en'])->keyBy('id');
        foreach ($incomplete as &$item) {
            $item['accounts'] = collect($item['financialAccountIds'])->map(function (int $id) use ($accounts): array {
                $account = $accounts->get($id);
                return ['code' => $account->code ?? null, 'name' => $account->name_en ?? $account->name_ar ?? null];
            })->values()->all();
        }
        unset($item);

        return ['types' => $types, 'incompleteRequired' => $incomplete];
    }
    private function visible(int $tenant, int $actor): Builder { $q = DB::table('financial_reconciliations as sessions')->leftJoin('financial_locations as locations', 'locations.id', '=', 'sessions.financial_location_id')->leftJoin('financial_accounts as accounts', 'accounts.id', '=', 'sessions.financial_account_id')->leftJoin('branches', 'branches.id', '=', 'sessions.branch_id')->where('sessions.tenant_id', $tenant)->select('sessions.*', 'locations.name as location_name', 'locations.code as location_code', 'locations.kind as location_kind', 'accounts.code as account_code', 'accounts.name_ar as account_name', 'branches.name as branch_name'); $role = DB::table('users')->where('tenant_id', $tenant)->where('id', $actor)->value('role'); if ($role !== 'owner') { $branches = DB::table('user_branches')->where('tenant_id', $tenant)->where('user_id', $actor)->pluck('branch_id')->all(); $q->where(fn (Builder $b) => $b->whereNull('sessions.branch_id')->orWhereIn('sessions.branch_id', $branches ?: [-1])); } return $q; }
    private function serialize(int $tenant, object $s): array { $lines = $this->lines($tenant, $s->id); $transactions = collect($this->transactionRows($tenant, $s)); $matched = $transactions->sum(fn (array $transaction) => Money::cents($transaction['matchedAmount'])); $blockers = $this->blockers($tenant, $s); return ['id' => (int) $s->id, 'reference' => $s->reference, 'type' => $s->type, 'status' => $s->status, 'account' => ['financialAccountId' => (int) $s->financial_account_id, 'financialAccountCode' => $s->account_code, 'financialAccountName' => $s->account_name, 'financialLocationId' => $s->financial_location_id ? (int) $s->financial_location_id : null, 'name' => $s->location_name, 'type' => $s->location_kind, 'branchId' => $s->branch_id ? (int) $s->branch_id : null, 'branchName' => $s->branch_name], 'period' => ['from' => $s->date_from, 'to' => $s->date_to], 'balances' => ['bookOpening' => $this->money($s->book_opening_balance), 'bookClosing' => $this->money($s->book_closing_balance), 'externalOpening' => $this->money($s->external_opening_balance), 'externalClosing' => $this->money($s->external_closing_balance), 'actualCash' => $this->money($s->actual_cash_count), 'difference' => $this->money($s->difference), 'differenceDirection' => $this->differenceDirection($s->difference)], 'summary' => ['systemTransactionsCount' => $transactions->count(), 'statementLinesCount' => count($lines), 'matchedCount' => DB::table('financial_reconciliation_matches')->where('tenant_id', $tenant)->where('financial_reconciliation_id', $s->id)->count(), 'unmatchedSystemCount' => $transactions->filter(fn (array $e) => $e['amount'] !== $e['matchedAmount'])->count(), 'unmatchedStatementCount' => collect($lines)->filter(fn (array $l) => Money::cents($l['remainingAmount']) !== 0)->count(), 'matchedAmount' => Money::decimal($matched), 'unmatchedSystemAmount' => Money::decimal($transactions->sum(fn (array $e) => Money::cents($e['amount']) - Money::cents($e['matchedAmount']))), 'unmatchedStatementAmount' => Money::decimal(collect($lines)->sum(fn (array $l) => Money::cents($l['remainingAmount'])))], 'canComplete' => $blockers === [], 'blockingReasons' => $blockers, 'createdBy' => $s->created_by ? (int) $s->created_by : null, 'completedBy' => $s->completed_by ? (int) $s->completed_by : null, 'createdAt' => $s->created_at, 'completedAt' => $s->completed_at]; }
    private function money(mixed $value): ?string { return $value === null ? null : Money::decimal($this->signedCents($value)); }
    private function signedCents(mixed $value): int { $value = trim((string) $value); return str_starts_with($value, '-') ? -Money::cents(substr($value, 1)) : Money::cents($value); }
    private function differenceDirection(mixed $value): ?string { if ($value === null) return null; $cents = $this->signedCents($value); return $cents === 0 ? 'balanced' : ($cents > 0 ? 'over' : 'short'); }
    private function lines(int $tenant, int $session): array { return DB::table('financial_reconciliation_statement_lines as lines')->leftJoin('financial_reconciliation_matches as matches', fn ($join) => $join->on('matches.statement_line_id', '=', 'lines.id')->where('matches.tenant_id', $tenant))->where('lines.tenant_id', $tenant)->where('lines.financial_reconciliation_id', $session)->groupBy('lines.id', 'lines.transaction_date', 'lines.value_date', 'lines.reference', 'lines.description', 'lines.amount', 'lines.direction', 'lines.external_identifier')->orderBy('lines.transaction_date')->orderBy('lines.id')->selectRaw('lines.id, lines.transaction_date, lines.value_date, lines.reference, lines.description, lines.amount, lines.direction, lines.external_identifier, COALESCE(SUM(matches.matched_amount), 0) as matched_amount')->get()->map(function (object $l): array { $matched = Money::cents($l->matched_amount); return ['id' => (int) $l->id, 'transactionDate' => $l->transaction_date, 'valueDate' => $l->value_date, 'reference' => $l->reference, 'description' => $l->description, 'amount' => $this->money($l->amount), 'direction' => $l->direction, 'externalIdentifier' => $l->external_identifier, 'matchedAmount' => Money::decimal($matched), 'remainingAmount' => Money::decimal(Money::cents($l->amount) - $matched)]; })->all(); }
    private function transactionRows(int $tenant, object $session): array { $normal = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('id', $session->financial_account_id)->value('normal_balance'); $allocations = $this->journalAllocations($tenant, $session->id); return $this->eligible($tenant, $session)->get()->map(function (object $entry) use ($normal, $allocations): array { $debit = Money::cents($entry->debit); $credit = Money::cents($entry->credit); return ['journalEntryId' => (int) $entry->id, 'reference' => $entry->entry_number, 'date' => $entry->entry_date, 'description' => $entry->description, 'direction' => (($normal === 'credit') ? $credit > $debit : $debit > $credit) ? 'inflow' : 'outflow', 'amount' => Money::decimal(max($debit, $credit)), 'matchedAmount' => Money::decimal($allocations[(int) $entry->id] ?? 0)]; })->values()->all(); }
    private function journalAllocations(int $tenant, int $session): array { return DB::table('financial_reconciliation_matches')->where('tenant_id', $tenant)->where('financial_reconciliation_id', $session)->selectRaw('journal_entry_id, COALESCE(SUM(matched_amount), 0) as matched_amount')->groupBy('journal_entry_id')->get()->mapWithKeys(fn (object $row) => [(int) $row->journal_entry_id => Money::cents($row->matched_amount)])->all(); }
    private function matches(int $tenant, int $session): array { return DB::table('financial_reconciliation_matches as matches')->join('journal_entries as entries', 'entries.id', '=', 'matches.journal_entry_id')->where('matches.tenant_id', $tenant)->where('matches.financial_reconciliation_id', $session)->get(['matches.*', 'entries.entry_number'])->map(fn (object $m) => ['id' => (int) $m->id, 'statementLineId' => (int) $m->statement_line_id, 'journalEntryId' => (int) $m->journal_entry_id, 'journalReference' => $m->entry_number, 'amount' => $m->matched_amount])->all(); }
    private function eligible(int $tenant, object $session): Builder { return DB::table('journal_entries as entries')->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')->where('entries.tenant_id', $tenant)->where('lines.tenant_id', $tenant)->where('entries.status', 'posted')->where('lines.financial_account_id', $session->financial_account_id)->whereDate('entries.entry_date', '>=', $session->date_from)->whereDate('entries.entry_date', '<=', $session->date_to)->selectRaw('entries.id, entries.entry_number, entries.entry_date, entries.description, SUM(lines.debit) as debit, SUM(lines.credit) as credit')->groupBy('entries.id', 'entries.entry_number', 'entries.entry_date', 'entries.description'); }
    private function matchedLine(int $tenant, int $line): int { return (int) DB::table('financial_reconciliation_matches')->where('tenant_id', $tenant)->where('statement_line_id', $line)->sum(DB::raw('matched_amount * 100')); }
    private function matchedJournal(int $tenant, int $session, int $journal): int { return (int) DB::table('financial_reconciliation_matches')->where('tenant_id', $tenant)->where('financial_reconciliation_id', $session)->where('journal_entry_id', $journal)->sum(DB::raw('matched_amount * 100')); }
}
