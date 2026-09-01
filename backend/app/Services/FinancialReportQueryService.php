<?php

namespace App\Services;

use App\Support\BranchScope;
use App\Support\Money;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Formal reports: every amount is a sum of posted journal lines, never a dashboard cache. */
final class FinancialReportQueryService
{
    public function __construct(private readonly FinancialReportContext $contexts, private readonly SupplierPayableQueryService $payables) {}

    public function context(int $tenant, int $actor, array $filters): array { return $this->contexts->resolve($tenant, $actor, $filters); }

    public function profitAndLoss(array $ctx): array
    {
        $current = $this->profitAndLossRange($ctx, $ctx['dateFrom'], $ctx['dateTo']);
        $comparison = $ctx['comparisonFrom'] ? $this->profitAndLossRange($ctx, $ctx['comparisonFrom'], $ctx['comparisonTo']) : null;
        return $current + ['comparison' => $comparison ? $this->comparison($current['totals'], $comparison['totals']) : null, 'integrity' => ['ledgerBased' => true]];
    }

    public function balanceSheet(array $ctx, string $asOf): array
    {
        $rows = $this->accountRows($ctx, null, $asOf, false);
        $groups = ['assets' => [], 'liabilities' => [], 'equity' => []];
        $totals = ['assets' => 0, 'liabilities' => 0, 'equity' => 0];
        foreach ($rows as $row) {
            if (! isset($groups[$row['group']])) continue;
            $groups[$row['group']][] = $row;
            $totals[$row['group']] += $row['normalisedCents'];
        }
        $earnings = $this->earningsThrough($ctx, $asOf);
        $equityWithEarnings = $totals['equity'] + $earnings;
        $difference = $totals['assets'] - $totals['liabilities'] - $equityWithEarnings;
        return ['asOfDate' => $asOf, 'assets' => ['accounts' => $groups['assets'], 'total' => Money::decimal($totals['assets'])], 'liabilities' => ['accounts' => $groups['liabilities'], 'total' => Money::decimal($totals['liabilities'])], 'equity' => ['accounts' => $groups['equity'], 'currentPeriodEarnings' => ['amount' => Money::decimal($earnings), 'reportDerived' => true], 'total' => Money::decimal($equityWithEarnings)], 'integrity' => ['balanced' => $difference === 0, 'difference' => Money::decimal($difference)]];
    }

    public function trialBalance(array $ctx, bool $includeZero = false): array
    {
        $rows = $this->accountRows($ctx, $ctx['dateFrom'], $ctx['dateTo'], true);
        if (! $includeZero) $rows = array_values(array_filter($rows, fn (array $r) => $r['closingDebitCents'] !== 0 || $r['closingCreditCents'] !== 0));
        $debit = array_sum(array_column($rows, 'closingDebitCents')); $credit = array_sum(array_column($rows, 'closingCreditCents'));
        return ['dateFrom' => $ctx['dateFrom'], 'dateTo' => $ctx['dateTo'], 'accounts' => array_map(fn (array $r) => $this->withoutCents($r), $rows), 'totals' => ['debit' => Money::decimal($debit), 'credit' => Money::decimal($credit), 'difference' => Money::decimal($debit - $credit), 'balanced' => $debit === $credit]];
    }

    public function generalLedger(array $ctx, int $accountId, int $page = 1, int $perPage = 50): array
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $ctx['tenantId'])->where('id', $accountId)->whereNull('deleted_at')->first();
        if (! $account) throw ValidationException::withMessages(['accountId' => 'Financial account was not found for this tenant.']);
        $base = $this->ledgerLines($ctx, $accountId)->whereBetween('entries.entry_date', [$ctx['dateFrom'], $ctx['dateTo']]);
        $total = (clone $base)->count(); $page = max(1, $page); $perPage = min(max(1, $perPage), 100); $offset = ($page - 1) * $perPage;
        $lines = (clone $base)->orderBy('entries.entry_date')->orderBy('entries.id')->orderBy('lines.id')->offset($offset)->limit($perPage)->get();
        $opening = $this->accountNormalised($ctx, $accountId, null, now()->parse($ctx['dateFrom'])->subDay()->toDateString(), $account->normal_balance);
        $before = 0;
        if ($lines->isNotEmpty()) {
            $first = $lines->first();
            $prior = (clone $base)->where(function (Builder $q) use ($first): void { $q->where('entries.entry_date', '<', $first->entry_date)->orWhere(function (Builder $same) use ($first): void { $same->where('entries.entry_date', $first->entry_date)->where(function (Builder $tie) use ($first): void { $tie->where('entries.id', '<', $first->journal_entry_id)->orWhere(fn (Builder $last) => $last->where('entries.id', $first->journal_entry_id)->where('lines.id', '<', $first->id)); }); }); })->select([])->selectRaw('COALESCE(SUM(lines.debit),0) debit, COALESCE(SUM(lines.credit),0) credit')->first();
            $before = $this->normalised($account->normal_balance, Money::cents($prior->debit), Money::cents($prior->credit));
        }
        $running = $opening + $before;
        $mapped = $lines->map(function (object $line) use (&$running, $account): array { $debit = Money::cents($line->debit); $credit = Money::cents($line->credit); $running += $this->normalised($account->normal_balance, $debit, $credit); return ['id' => (int) $line->id, 'accountingDate' => $line->entry_date, 'journal' => ['id' => (int) $line->journal_entry_id, 'reference' => $line->entry_number], 'source' => ['type' => $line->source_type, 'id' => $line->source_id], 'description' => $line->line_description ?? $line->entry_description, 'debit' => Money::decimal($debit), 'credit' => Money::decimal($credit), 'runningBalance' => Money::decimal($running), 'drillDown' => ['resourceKind' => 'journal_entry', 'id' => (int) $line->journal_entry_id, 'reference' => $line->entry_number]]; })->values();
        $closing = $this->accountNormalised($ctx, $accountId, null, $ctx['dateTo'], $account->normal_balance);
        return ['account' => ['id' => (int) $account->id, 'code' => $account->code, 'name' => $account->name_en, 'normalBalance' => $account->normal_balance], 'dateFrom' => $ctx['dateFrom'], 'dateTo' => $ctx['dateTo'], 'openingBalance' => Money::decimal($opening), 'lines' => $mapped, 'closingBalance' => Money::decimal($closing), 'meta' => ['currentPage' => $page, 'perPage' => $perPage, 'total' => $total, 'lastPage' => max(1, (int) ceil($total / $perPage))]];
    }

    public function cashFlow(array $ctx): array
    {
        $cashAccounts = DB::table('financial_locations')->where('tenant_id', $ctx['tenantId'])->whereIn('kind', ['cash', 'bank'])->where('is_active', true)->pluck('financial_account_id')->all();
        $opening = $this->cashBalance($ctx, $cashAccounts, now()->parse($ctx['dateFrom'])->subDay()->toDateString()); $closing = $this->cashBalance($ctx, $cashAccounts, $ctx['dateTo']);
        if ($cashAccounts === []) return ['dateFrom' => $ctx['dateFrom'], 'dateTo' => $ctx['dateTo'], 'sections' => [], 'openingCashBanks' => '0.00', 'closingCashBanks' => '0.00', 'netCashFlow' => '0.00', 'integrity' => ['reconciled' => true, 'difference' => '0.00', 'unclassified' => '0.00']];
        $rows = $this->posted($ctx)->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')->where('lines.tenant_id', $ctx['tenantId'])->whereIn('lines.financial_account_id', $cashAccounts)->whereBetween('entries.entry_date', [$ctx['dateFrom'], $ctx['dateTo']])->groupBy('entries.id', 'entries.entry_date', 'entries.entry_number', 'entries.source_type', 'entries.source_id')->selectRaw('entries.id, entries.entry_date, entries.entry_number, entries.source_type, entries.source_id, SUM(lines.debit) debit, SUM(lines.credit) credit')->get();
        $sections = ['operating' => [], 'investing' => [], 'financing' => [], 'internal_transfer' => [], 'unclassified' => []]; $net = 0; $unclassified = 0;
        foreach ($rows as $row) { $amount = Money::cents($row->debit) - Money::cents($row->credit); $kind = match ($row->source_type) { 'pos_order' => 'operating', 'payment_refund', 'expense', 'supplier_payment' => 'operating', 'cash_transfer' => 'internal_transfer', default => 'unclassified' }; $item = ['journalId' => (int) $row->id, 'reference' => $row->entry_number, 'date' => $row->entry_date, 'sourceType' => $row->source_type, 'amount' => Money::decimal($amount)]; $sections[$kind][] = $item; if ($kind !== 'internal_transfer') $net += $amount; if ($kind === 'unclassified') $unclassified += abs($amount); }
        $difference = $opening + $net - $closing;
        return ['dateFrom' => $ctx['dateFrom'], 'dateTo' => $ctx['dateTo'], 'sections' => $sections, 'openingCashBanks' => Money::decimal($opening), 'closingCashBanks' => Money::decimal($closing), 'netCashFlow' => Money::decimal($net), 'integrity' => ['reconciled' => $difference === 0, 'difference' => Money::decimal($difference), 'unclassified' => Money::decimal($unclassified)]];
    }

    public function supplierAging(array $ctx, string $asOf, ?int $supplierId = null): array
    {
        if ($supplierId && ! DB::table('suppliers')->where('tenant_id', $ctx['tenantId'])->where('id', $supplierId)->exists()) throw ValidationException::withMessages(['supplierId' => 'Supplier was not found for this tenant.']);
        $invoices = $this->payables->invoicesAsOf($ctx['tenantId'], $asOf, $ctx['branchId'], $ctx['authorizedBranchIds'], $supplierId); $buckets = ['current' => 0, 'days1To30' => 0, 'days31To60' => 0, 'days61To90' => 0, 'days90Plus' => 0]; $suppliers = [];
        foreach ($invoices as $invoice) { if ($invoice['remainingCents'] <= 0) continue; $age = max(0, now()->parse($asOf)->diffInDays(now()->parse($invoice['dueDate']), false) * -1); $key = $invoice['dueDate'] >= $asOf ? 'current' : ($age <= 30 ? 'days1To30' : ($age <= 60 ? 'days31To60' : ($age <= 90 ? 'days61To90' : 'days90Plus'))); $id = $invoice['supplierId']; if (! isset($suppliers[$id])) $suppliers[$id] = ['supplier' => ['id' => $id, 'name' => $invoice['supplierName']], 'current' => 0, 'days1To30' => 0, 'days31To60' => 0, 'days61To90' => 0, 'days90Plus' => 0, 'totalOutstanding' => 0]; $suppliers[$id][$key] += $invoice['remainingCents']; $suppliers[$id]['totalOutstanding'] += $invoice['remainingCents']; $buckets[$key] += $invoice['remainingCents']; }
        $format = fn (array $row): array => collect($row)->map(fn ($v, $k) => is_int($v) ? Money::decimal($v) : $v)->all(); return ['asOfDate' => $asOf, 'suppliers' => array_values(array_map($format, $suppliers)), 'totals' => $format($buckets + ['totalOutstanding' => array_sum($buckets)])];
    }

    public function supplierStatement(array $ctx, int $supplierId): array
    {
        if (! DB::table('suppliers')->where('tenant_id', $ctx['tenantId'])->where('id', $supplierId)->exists()) throw ValidationException::withMessages(['supplierId' => 'Supplier was not found for this tenant.']);
        $before = now()->parse($ctx['dateFrom'])->subDay()->toDateString();
        $opening = array_sum(array_column($this->payables->invoicesAsOf($ctx['tenantId'], $before, $ctx['branchId'], $ctx['authorizedBranchIds'], $supplierId), 'remainingCents'));
        $events = [];
        foreach ($this->payables->invoicesAsOf($ctx['tenantId'], $ctx['dateTo'], $ctx['branchId'], $ctx['authorizedBranchIds'], $supplierId) as $invoice) {
            if ($invoice['postedDate'] >= $ctx['dateFrom'] && $invoice['postedDate'] <= $ctx['dateTo']) $events[] = ['date' => $invoice['postedDate'], 'type' => 'supplier_invoice', 'reference' => $invoice['reference'], 'description' => 'Supplier invoice', 'debitCents' => $invoice['totalCents'], 'creditCents' => 0, 'resourceKind' => 'supplier_invoice', 'id' => $invoice['id']];
        }
        $payments = DB::table('payment_allocations as allocations')->join('supplier_payments as payments', 'payments.id', '=', 'allocations.supplier_payment_id')->join('supplier_invoices as invoices', 'invoices.id', '=', 'allocations.supplier_invoice_id')->where('allocations.tenant_id', $ctx['tenantId'])->where('invoices.supplier_id', $supplierId)->whereBetween('payments.payment_date', [$ctx['dateFrom'], $ctx['dateTo']]);
        if ($ctx['branchId'] !== null) $payments->where('payments.branch_id', $ctx['branchId']); else $payments->where(fn ($q) => $q->whereIn('payments.branch_id', $ctx['authorizedBranchIds'])->orWhereNull('payments.branch_id'));
        foreach ($payments->get(['payments.id', 'payments.payment_number', 'payments.payment_date', 'allocations.amount']) as $payment) $events[] = ['date' => $payment->payment_date, 'type' => 'supplier_payment', 'reference' => $payment->payment_number, 'description' => 'Supplier payment allocation', 'debitCents' => 0, 'creditCents' => Money::cents($payment->amount), 'resourceKind' => 'supplier_payment', 'id' => (int) $payment->id];
        usort($events, fn (array $a, array $b) => [$a['date'], $a['type'], $a['id']] <=> [$b['date'], $b['type'], $b['id']]); $running = $opening;
        $lines = array_map(function (array $event) use (&$running): array { $running += $event['debitCents'] - $event['creditCents']; return ['date' => $event['date'], 'type' => $event['type'], 'reference' => $event['reference'], 'description' => $event['description'], 'debit' => Money::decimal($event['debitCents']), 'credit' => Money::decimal($event['creditCents']), 'runningOutstanding' => Money::decimal($running), 'drillDown' => ['resourceKind' => $event['resourceKind'], 'id' => $event['id'], 'reference' => $event['reference']]]; }, $events);
        return ['supplierId' => $supplierId, 'dateFrom' => $ctx['dateFrom'], 'dateTo' => $ctx['dateTo'], 'openingBalance' => Money::decimal($opening), 'lines' => $lines, 'closingBalance' => Money::decimal($running)];
    }

    private function profitAndLossRange(array $ctx, string $from, string $to): array { $rows = $this->accountRows($ctx, $from, $to, false); $sections = ['revenue' => [], 'costOfSales' => [], 'operatingExpenses' => []]; $totals = ['revenue' => 0, 'costOfSales' => 0, 'operatingExpenses' => 0]; foreach ($rows as $row) { $key = match ($row['group']) { 'revenue' => 'revenue', 'cost_of_sales' => 'costOfSales', 'expenses', 'expense' => 'operatingExpenses', default => null }; if (! $key) continue; $amount = $this->incomeStatementAmount($row); $row['normalisedCents'] = $amount; $row['normalisedBalance'] = Money::decimal($amount); $sections[$key][] = $row; $totals[$key] += $amount; } $totals['grossProfit'] = $totals['revenue'] - $totals['costOfSales']; $totals['netOperatingProfit'] = $totals['grossProfit'] - $totals['operatingExpenses']; return ['dateFrom' => $from, 'dateTo' => $to, 'sections' => array_map(fn ($rows) => array_map(fn ($r) => $this->withoutCents($r), $rows), $sections), 'totals' => $this->decimalMap($totals)]; }
    private function accountRows(array $ctx, ?string $from, string $to, bool $withOpening): array { $accounts = DB::table('financial_accounts')->where('tenant_id', $ctx['tenantId'])->whereNull('deleted_at')->orderBy('account_group')->orderBy('code')->get(); $period = $this->accountAggregates($ctx, $from, $to); $opening = $withOpening && $from ? $this->accountAggregates($ctx, null, now()->parse($from)->subDay()->toDateString()) : collect(); $all = $withOpening ? $this->accountAggregates($ctx, null, $to) : collect(); return $accounts->map(function (object $a) use ($period, $opening, $all): array { $p = $period[$a->id] ?? (object) ['debit' => '0', 'credit' => '0']; $o = $opening[$a->id] ?? (object) ['debit' => '0', 'credit' => '0']; $c = $all[$a->id] ?? $p; $pd = Money::cents($p->debit); $pc = Money::cents($p->credit); $od = Money::cents($o->debit); $oc = Money::cents($o->credit); $cd = Money::cents($c->debit); $cc = Money::cents($c->credit); return ['id' => (int) $a->id, 'code' => $a->code, 'name' => $a->name_en, 'group' => $a->account_group, 'normalBalance' => $a->normal_balance, 'parentAccountId' => $a->parent_account_id ? (int) $a->parent_account_id : null, 'debit' => Money::decimal($pd), 'credit' => Money::decimal($pc), 'normalisedBalance' => Money::decimal($this->normalised($a->normal_balance, $pd, $pc)), 'normalisedCents' => $this->normalised($a->normal_balance, $pd, $pc), 'openingDebit' => Money::decimal($od), 'openingCredit' => Money::decimal($oc), 'periodDebit' => Money::decimal($pd), 'periodCredit' => Money::decimal($pc), 'closingDebit' => Money::decimal(max(0, $cd - $cc)), 'closingCredit' => Money::decimal(max(0, $cc - $cd)), 'closingDebitCents' => max(0, $cd - $cc), 'closingCreditCents' => max(0, $cc - $cd)]; })->all(); }
    private function accountAggregates(array $ctx, ?string $from, string $to) { $q = $this->posted($ctx)->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')->where('lines.tenant_id', $ctx['tenantId'])->whereDate('entries.entry_date', '<=', $to); if ($from) $q->whereDate('entries.entry_date', '>=', $from); return $q->groupBy('lines.financial_account_id')->selectRaw('lines.financial_account_id, SUM(lines.debit) debit, SUM(lines.credit) credit')->get()->keyBy('financial_account_id'); }
    private function posted(array $ctx): Builder { $q = DB::table('journal_entries as entries')->where('entries.tenant_id', $ctx['tenantId'])->where('entries.status', 'posted'); return BranchScope::apply($q, 'entries.branch_id', $ctx['branchId'], $ctx['authorizedBranchIds']); }
    private function ledgerLines(array $ctx, int $account): Builder { return $this->posted($ctx)->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')->where('lines.tenant_id', $ctx['tenantId'])->where('lines.financial_account_id', $account)->select('lines.id', 'lines.journal_entry_id', 'lines.debit', 'lines.credit', 'lines.description as line_description', 'entries.id as entry_id', 'entries.entry_date', 'entries.entry_number', 'entries.source_type', 'entries.source_id', 'entries.description as entry_description'); }
    private function accountNormalised(array $ctx, int $account, ?string $from, string $to, string $normal): int { $q = $this->posted($ctx)->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')->where('lines.tenant_id', $ctx['tenantId'])->where('lines.financial_account_id', $account)->whereDate('entries.entry_date', '<=', $to); if ($from) $q->whereDate('entries.entry_date', '>=', $from); $row = $q->selectRaw('COALESCE(SUM(lines.debit),0) debit, COALESCE(SUM(lines.credit),0) credit')->first(); return $this->normalised($normal, Money::cents($row->debit), Money::cents($row->credit)); }
    private function cashBalance(array $ctx, array $accounts, string $to): int { if ($accounts === []) return 0; $rows = $this->posted($ctx)->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')->where('lines.tenant_id', $ctx['tenantId'])->whereIn('lines.financial_account_id', $accounts)->whereDate('entries.entry_date', '<=', $to)->groupBy('accounts.normal_balance')->selectRaw('accounts.normal_balance, SUM(lines.debit) debit, SUM(lines.credit) credit')->get(); return $rows->sum(fn ($r) => $this->normalised($r->normal_balance, Money::cents($r->debit), Money::cents($r->credit))); }
    private function earningsThrough(array $ctx, string $to): int { $rows = $this->accountRows($ctx, null, $to, false); $earnings = 0; foreach ($rows as $r) if ($r['group'] === 'revenue') $earnings += $this->incomeStatementAmount($r); elseif (in_array($r['group'], ['cost_of_sales', 'expenses', 'expense'], true)) $earnings -= $this->incomeStatementAmount($r); return $earnings; }
    private function incomeStatementAmount(array $row): int { return $row['group'] === 'revenue' && $row['normalBalance'] === 'debit' ? -$row['normalisedCents'] : $row['normalisedCents']; }
    private function normalised(string $normal, int $debit, int $credit): int { return $normal === 'credit' ? $credit - $debit : $debit - $credit; }
    private function decimalMap(array $values): array { return array_map(fn ($v) => Money::decimal($v), $values); }
    private function withoutCents(array $row): array { unset($row['normalisedCents'], $row['closingDebitCents'], $row['closingCreditCents']); return $row; }
    private function comparison(array $current, array $previous): array { $result = []; foreach ($current as $key => $value) { $now = Money::cents($value); $before = Money::cents($previous[$key] ?? '0'); $delta = $now - $before; $result[$key] = ['current' => $value, 'previous' => Money::decimal($before), 'change' => Money::decimal($delta), 'percentageChange' => $before === 0 ? null : $this->percentage($delta, $before)]; } return $result; }
    private function percentage(int $delta, int $before): string { $negative = ($delta < 0) !== ($before < 0); $basisPoints = intdiv(abs($delta) * 10000 + intdiv(abs($before), 2), abs($before)); return ($negative ? '-' : '').intdiv($basisPoints, 100).'.'.str_pad((string) ($basisPoints % 100), 2, '0', STR_PAD_LEFT); }
}
