<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\Money;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Authoritative read model over journal_entries and linked business sources. */
final class FinancialTransactionQueryService
{
    public function __construct(private readonly FinancialTransactionSourceResolver $sources) {}

    public function list(Request $request, int $tenantId, int $actorId, array $filters): array
    {
        $query = $this->filtered($tenantId, $actorId, $filters);
        $paginator = $query->orderByDesc('entries.entry_date')->orderByDesc('entries.id')->paginate($filters['perPage'] ?? 25);
        return ['data' => $this->enrich($tenantId, collect($paginator->items())), 'meta' => $this->meta($paginator)];
    }

    public function detail(Request $request, int $tenantId, int $actorId, int $id): array
    {
        $entry = $this->visible($tenantId, $actorId)->where('entries.id', $id)->first();
        abort_unless($entry, 404, 'Financial transaction not found.');
        $transaction = $this->enrich($tenantId, collect([$entry]))[0];
        $lines = DB::table('journal_entry_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $tenantId)->where('lines.journal_entry_id', $id)->orderBy('lines.line_number')
            ->get(['lines.id', 'lines.line_number', 'lines.description', 'lines.debit', 'lines.credit', 'accounts.id as account_id', 'accounts.code as account_code', 'accounts.name_ar as account_name_ar', 'accounts.name_en as account_name_en'])
            ->map(fn (object $line) => ['id' => (int) $line->id, 'lineNumber' => (int) $line->line_number, 'accountId' => (int) $line->account_id, 'accountCode' => $line->account_code, 'accountNameAr' => $line->account_name_ar, 'accountNameEn' => $line->account_name_en, 'description' => $line->description, 'debit' => Money::decimal(Money::cents($line->debit)), 'credit' => Money::decimal(Money::cents($line->credit))])->values();
        $transaction['journal']['lines'] = $lines;
        return $transaction;
    }

    public function summary(Request $request, int $tenantId, int $actorId, array $filters): array
    {
        $entries = $this->filtered($tenantId, $actorId, $filters)->get();
        $cash = $this->cashEffects($tenantId, $entries);
        $in = 0; $out = 0;
        foreach ($entries as $entry) {
            if ($entry->status !== 'posted') continue;
            $effect = $cash[(int) $entry->id] ?? null;
            if (($effect['direction'] ?? null) === 'inflow') $in += Money::cents($effect['amount']);
            if (($effect['direction'] ?? null) === 'outflow') $out += Money::cents($effect['amount']);
        }
        return ['transactionCount' => $entries->count(), 'externalCashInflow' => Money::decimal($in), 'externalCashOutflow' => Money::decimal($out), 'draftJournalCount' => $entries->where('status', 'draft')->count(), 'reversedOriginalCount' => $entries->filter(fn (object $entry) => $entry->reversal_entry_id !== null)->count()];
    }

    private function filtered(int $tenantId, int $actorId, array $filters): Builder
    {
        $query = $this->visible($tenantId, $actorId);
        if (! empty($filters['dateFrom'])) $query->whereDate('entries.entry_date', '>=', $filters['dateFrom']);
        if (! empty($filters['dateTo'])) $query->whereDate('entries.entry_date', '<=', $filters['dateTo']);
        if (! empty($filters['branchId'])) {
            FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $filters['branchId']);
            $query->where(fn (Builder $branches) => $branches->where('entries.branch_id', $filters['branchId'])->orWhereNull('entries.branch_id'));
        }
        if (! empty($filters['status'])) $query->where('entries.status', $filters['status']);
        if (! empty($filters['sourceType'])) $this->filterSourceType($query, $filters['sourceType']);
        if (! empty($filters['reversalState'])) {
            match ($filters['reversalState']) {
                'original_reversed' => $query->whereNotNull('reversal_entries.id'),
                'reversal_entry' => $query->whereNotNull('entries.reversal_of_id'),
                default => $query->whereNull('entries.reversal_of_id')->whereNull('reversal_entries.id'),
            };
        }
        if (! empty($filters['accountId'])) $this->assertAccount($tenantId, (int) $filters['accountId']);
        if (! empty($filters['accountCode'])) $filters['accountId'] = $this->accountIdByCode($tenantId, $filters['accountCode']);
        if (! empty($filters['accountId'])) $query->whereExists(fn (Builder $lines) => $lines->selectRaw('1')->from('journal_entry_lines as filter_lines')->whereColumn('filter_lines.journal_entry_id', 'entries.id')->where('filter_lines.tenant_id', $tenantId)->where('filter_lines.financial_account_id', $filters['accountId']));
        if (! empty($filters['paymentMethodId'])) { $this->assertPaymentMethod($tenantId, (int) $filters['paymentMethodId']); $this->paymentMethod($query, $tenantId, (int) $filters['paymentMethodId']); }
        if (! empty($filters['search'])) $this->search($query, $tenantId, $filters['search']);
        return $query;
    }

    private function visible(int $tenantId, int $actorId): Builder
    {
        $query = DB::table('journal_entries as entries')->leftJoin('branches', 'branches.id', '=', 'entries.branch_id')
            ->leftJoin('users as creators', 'creators.id', '=', 'entries.created_by')
            ->leftJoin('journal_entries as reversal_entries', fn ($join) => $join->on('reversal_entries.reversal_of_id', '=', 'entries.id')->where('reversal_entries.tenant_id', $tenantId))
            ->leftJoin('journal_entries as original_entries', fn ($join) => $join->on('original_entries.id', '=', 'entries.reversal_of_id')->where('original_entries.tenant_id', $tenantId))
            ->where('entries.tenant_id', $tenantId)
            ->select('entries.*', 'branches.name as branch_name', 'creators.name as creator_name', 'reversal_entries.id as reversal_entry_id', 'reversal_entries.entry_number as reversal_entry_number', 'original_entries.entry_number as original_entry_number');
        $role = DB::table('users')->where('tenant_id', $tenantId)->where('id', $actorId)->value('role');
        if ($role !== 'owner') {
            $branchIds = DB::table('user_branches')->where('tenant_id', $tenantId)->where('user_id', $actorId)->pluck('branch_id')->all();
            $query->where(fn (Builder $scope) => $scope->whereNull('entries.branch_id')->orWhereIn('entries.branch_id', $branchIds ?: [-1]));
        }
        return $query;
    }

    private function enrich(int $tenantId, Collection $entries): array
    {
        $totals = $this->totals($tenantId, $entries->pluck('id')->all());
        $source = $this->sources->resolve($tenantId, $entries->map(function (object $entry) use ($totals): object { $entry->total_debit = $totals[$entry->id]['debit'] ?? '0.00'; return $entry; }));
        $cash = $this->cashEffects($tenantId, $entries);
        $accounts = $this->accountsSummary($tenantId, $entries->pluck('id')->all());
        return $entries->map(function (object $entry) use ($totals, $source, $cash, $accounts): array {
            $total = $totals[$entry->id] ?? ['debit' => '0.00', 'credit' => '0.00', 'count' => 0]; $info = $source[$entry->id];
            return ['id' => (int) $entry->id, 'reference' => $entry->entry_number, 'transactionDate' => $entry->entry_date, 'createdAt' => $entry->created_at, 'postedAt' => $entry->posted_at,
                'branch' => ['id' => $entry->branch_id ? (int) $entry->branch_id : null, 'name' => $entry->branch_name], 'source' => $info['source'], 'description' => $entry->description,
                'displayAmount' => $info['displayAmount'], 'paymentMethod' => $info['paymentMethod'],
                'journal' => ['id' => (int) $entry->id, 'reference' => $entry->entry_number, 'status' => $entry->status, 'totalDebit' => $total['debit'], 'totalCredit' => $total['credit'], 'balanced' => $total['debit'] === $total['credit'], 'linesCount' => $total['count']],
                'reversal' => $this->reversal($entry), 'cashEffect' => $cash[(int) $entry->id] ?? null, 'accountsSummary' => $accounts[$entry->id] ?? ['count' => 0, 'accounts' => []], 'actor' => $entry->created_by ? ['id' => (int) $entry->created_by, 'name' => $entry->creator_name] : null];
        })->values()->all();
    }

    private function totals(int $tenantId, array $ids): array
    {
        if ($ids === []) return [];
        return DB::table('journal_entry_lines')->where('tenant_id', $tenantId)->whereIn('journal_entry_id', $ids)->selectRaw('journal_entry_id, SUM(debit) as debit, SUM(credit) as credit, COUNT(*) as line_count')->groupBy('journal_entry_id')->get()->mapWithKeys(fn (object $row) => [(int) $row->journal_entry_id => ['debit' => Money::decimal(Money::cents($row->debit)), 'credit' => Money::decimal(Money::cents($row->credit)), 'count' => (int) $row->line_count]])->all();
    }

    private function cashEffects(int $tenantId, Collection $entries): array
    {
        $ids = $entries->pluck('id')->all(); if ($ids === []) return [];
        $cashAccounts = DB::table('financial_locations')->where('tenant_id', $tenantId)->whereIn('kind', ['cash', 'bank'])->pluck('financial_account_id')->map(fn ($id) => (int) $id)->all(); if ($cashAccounts === []) return [];
        $rows = DB::table('journal_entry_lines')->where('tenant_id', $tenantId)->whereIn('journal_entry_id', $ids)->whereIn('financial_account_id', $cashAccounts)->selectRaw('journal_entry_id, SUM(debit) as debit, SUM(credit) as credit')->groupBy('journal_entry_id')->get()->keyBy('journal_entry_id');
        return $entries->mapWithKeys(function (object $entry) use ($rows): array {
            if ($entry->status !== 'posted' || ! isset($rows[$entry->id])) return [(int) $entry->id => null];
            $row = $rows[$entry->id]; $debit = Money::cents($row->debit); $credit = Money::cents($row->credit);
            if ($entry->source_type === 'cash_transfer') return [(int) $entry->id => ['direction' => 'internal_transfer', 'amount' => Money::decimal(max($debit, $credit))]];
            if ($debit === $credit) return [(int) $entry->id => null];
            return [(int) $entry->id => ['direction' => $debit > $credit ? 'inflow' : 'outflow', 'amount' => Money::decimal(abs($debit - $credit))]];
        })->all();
    }

    private function accountsSummary(int $tenantId, array $ids): array
    {
        if ($ids === []) return [];
        return DB::table('journal_entry_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')->where('lines.tenant_id', $tenantId)->whereIn('lines.journal_entry_id', $ids)->orderBy('lines.line_number')->get(['lines.journal_entry_id', 'accounts.code', 'accounts.name_ar'])->groupBy('journal_entry_id')->map(fn (Collection $lines) => ['count' => $lines->count(), 'accounts' => $lines->take(3)->map(fn (object $line) => ['code' => $line->code, 'name' => $line->name_ar])->values()])->all();
    }

    private function reversal(object $entry): array
    {
        if ($entry->reversal_of_id) return ['state' => 'reversal_entry', 'originalJournalId' => (int) $entry->reversal_of_id, 'originalReference' => $entry->original_entry_number, 'reversalJournalId' => (int) $entry->id, 'reversalReference' => $entry->entry_number];
        if ($entry->reversal_entry_id) return ['state' => 'original_reversed', 'originalJournalId' => (int) $entry->id, 'originalReference' => $entry->entry_number, 'reversalJournalId' => (int) $entry->reversal_entry_id, 'reversalReference' => $entry->reversal_entry_number];
        return ['state' => 'none', 'originalJournalId' => null, 'originalReference' => null, 'reversalJournalId' => null, 'reversalReference' => null];
    }

    private function filterSourceType(Builder $query, string $type): void { if (in_array($type, ['sale','refund','expense','cash_transfer','supplier_invoice','supplier_payment','manual_journal','journal_reversal'], true)) { $query->where('entries.source_type', ['sale' => 'pos_order', 'refund' => 'payment_refund', 'manual_journal' => 'manual'][$type] ?? $type); return; } if ($type === 'inventory_waste') { $query->where('entries.source_type', 'inventory_movement')->where('entries.source_event', 'INVENTORY_WASTE'); return; } if ($type === 'stock_count_variance') { $query->where('entries.source_type', 'inventory_movement')->whereIn('entries.source_event', ['STOCK_COUNT_SHORTAGE','STOCK_COUNT_SURPLUS']); return; } $query->where('entries.source_type', $type); }
    private function paymentMethod(Builder $query, int $tenantId, int $methodId): void { $exists = fn (string $table, string $foreign) => fn (Builder $sub) => $sub->selectRaw('1')->from($table)->where("$table.tenant_id", $tenantId)->whereColumn("$table.id", 'entries.source_id')->where("$table.$foreign", $methodId); $query->where(fn (Builder $sources) => $sources->where(fn (Builder $q) => $q->where('entries.source_type', 'expense')->whereExists($exists('expenses', 'payment_method_id')))->orWhere(fn (Builder $q) => $q->where('entries.source_type', 'supplier_payment')->whereExists($exists('supplier_payments', 'payment_method_id')))->orWhere(fn (Builder $q) => $q->where('entries.source_type', 'pos_order')->whereExists(fn (Builder $p) => $p->selectRaw('1')->from('payments')->where('payments.tenant_id', $tenantId)->whereColumn('payments.order_id', 'entries.source_id')->where('payments.payment_method_id', $methodId)))->orWhere(fn (Builder $q) => $q->where('entries.source_type', 'payment_refund')->whereExists(fn (Builder $r) => $r->selectRaw('1')->from('payment_refunds as refunds')->join('payments', 'payments.id', '=', 'refunds.payment_id')->where('refunds.tenant_id', $tenantId)->whereColumn('refunds.id', 'entries.source_id')->where('payments.payment_method_id', $methodId)))); }
    private function search(Builder $query, int $tenantId, string $search): void { $needle = '%'.strtolower($search).'%'; $query->where(fn (Builder $q) => $q->whereRaw('LOWER(entries.entry_number) LIKE ?', [$needle])->orWhereRaw("LOWER(COALESCE(entries.description, '')) LIKE ?", [$needle])->orWhereExists(fn (Builder $orders) => $orders->selectRaw('1')->from('orders')->where('orders.tenant_id', $tenantId)->whereColumn('orders.id', 'entries.source_id')->where('entries.source_type', 'pos_order')->whereRaw('LOWER(orders.order_number) LIKE ?', [$needle]))->orWhereExists(fn (Builder $expenses) => $expenses->selectRaw('1')->from('expenses')->where('expenses.tenant_id', $tenantId)->whereColumn('expenses.id', 'entries.source_id')->where('entries.source_type', 'expense')->whereRaw('LOWER(expenses.expense_number) LIKE ?', [$needle]))->orWhereExists(fn (Builder $invoices) => $invoices->selectRaw('1')->from('supplier_invoices')->where('supplier_invoices.tenant_id', $tenantId)->whereColumn('supplier_invoices.id', 'entries.source_id')->where('entries.source_type', 'supplier_invoice')->whereRaw('LOWER(supplier_invoices.internal_reference) LIKE ?', [$needle]))); }
    private function assertAccount(int $tenantId, int $id): void { if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at')->exists()) throw ValidationException::withMessages(['accountId' => 'Financial account was not found for this tenant.']); }
    private function assertPaymentMethod(int $tenantId, int $id): void { if (! DB::table('payment_methods')->where('tenant_id', $tenantId)->where('id', $id)->exists()) throw ValidationException::withMessages(['paymentMethodId' => 'Payment method was not found for this tenant.']); }
    private function accountIdByCode(int $tenantId, string $code): int { $id = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', $code)->whereNull('deleted_at')->value('id'); if (! $id) throw ValidationException::withMessages(['accountCode' => 'Financial account was not found for this tenant.']); return (int) $id; }
    private function meta(LengthAwarePaginator $paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }
}
