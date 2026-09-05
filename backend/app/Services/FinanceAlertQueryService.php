<?php

namespace App\Services;

use App\Domain\Inventory\InventoryAccountingMapper;
use App\Support\BranchScope;
use App\Support\Money;
use Illuminate\Support\Facades\DB;

/**
 * Every alert here reads real operational state from an existing phase —
 * nothing is invented. Dedup policy: a stale/blocked Daily Closing day
 * already carries its own sub-blocker codes (cash difference, open shifts,
 * incomplete cash reconciliation, ...) as DAILY_CLOSING_BLOCKED metadata,
 * so those sub-conditions are never ALSO raised as their own standalone
 * alerts. The two exceptions are inventory posting failures and late
 * activity after close: both are promoted to their own CRITICAL alerts
 * with full per-item metadata because they are actionable independently of
 * whether a Daily Closing row happens to exist for that day. Draft journal
 * entries get a standalone WARNING alert only for entries NOT already
 * counted inside a DAILY_CLOSING_BLOCKED alert for that exact branch/date.
 */
final class FinanceAlertQueryService
{
    private const INVENTORY_POSTING_TYPES = ['waste', 'stock_count_variance', 'adjustment_in', 'adjustment_out'];

    public function __construct(
        private readonly DailyClosingSummaryService $summary,
        private readonly DailyClosingReadinessService $readiness,
        private readonly DailyClosingIntegrityService $integrity,
        private readonly SupplierPayableQueryService $payables,
        private readonly InventoryAccountingMapper $mapper,
        private readonly FinancialSetupService $setup,
    ) {}

    public function alerts(array $context, string $dateFrom, string $dateTo, array $reconciliation): array
    {
        [$closingAlerts, $coveredDates] = $this->dailyClosingBlocked($context, $dateFrom, $dateTo);

        return [
            ...$this->pendingExpenseApprovals($context),
            ...$this->overdueSupplierInvoices($context),
            ...$closingAlerts,
            ...$this->incompleteReconciliations($context, $reconciliation['incompleteRequired'], $coveredDates['reconciliations']),
            ...$this->lateActivityAfterClose($context, $dateFrom, $dateTo),
            ...$this->unpostedInventoryFinancialEvents($context, $dateFrom, $dateTo),
            ...$this->draftJournalEntries($context, $dateFrom, $dateTo, $coveredDates['drafts']),
            ...$this->financeConfiguration($context),
        ];
    }

    private function pendingExpenseApprovals(array $context): array
    {
        $query = DB::table('expenses')->where('tenant_id', $context['tenantId'])->where('status', 'pending_approval')->whereNull('deleted_at');
        BranchScope::apply($query, 'branch_id', $context['branchId'], $context['authorizedBranchIds']);
        $rows = $query->groupBy('branch_id')->selectRaw('branch_id, COUNT(*) as count, COALESCE(SUM(total_amount),0) as amount')->get();

        return $rows->map(fn ($row) => [
            'code' => 'PENDING_EXPENSE_APPROVAL', 'severity' => 'warning', 'sourceType' => 'expense', 'sourceId' => null, 'reference' => null,
            'branch' => $this->branchRef($context, $row->branch_id ? (int) $row->branch_id : null), 'amount' => Money::decimal(Money::cents($row->amount ?: '0')),
            'occurredAt' => null, 'metadata' => ['count' => (int) $row->count],
        ])->values()->all();
    }

    private function overdueSupplierInvoices(array $context): array
    {
        return collect($this->payables->overdueInvoices($context['tenantId'], 20))
            ->filter(fn (array $invoice) => $context['branchId'] !== null ? $invoice['branchId'] === $context['branchId'] : ($invoice['branchId'] === null || in_array($invoice['branchId'], $context['authorizedBranchIds'], true)))
            ->map(fn (array $invoice) => [
                'code' => 'SUPPLIER_INVOICE_OVERDUE', 'severity' => 'warning', 'sourceType' => 'supplier_invoice', 'sourceId' => $invoice['id'], 'reference' => $invoice['reference'],
                'branch' => $this->branchRef($context, $invoice['branchId']), 'amount' => $invoice['remaining'], 'occurredAt' => $invoice['dueDate'],
                'metadata' => ['supplierName' => $invoice['supplierName'], 'dueDate' => $invoice['dueDate']],
            ])->values()->all();
    }

    /** @return array{0: array, 1: array<int, array<string, bool>>} [alerts, coveredDates[branchId][businessDate]] */
    private function dailyClosingBlocked(array $context, string $dateFrom, string $dateTo): array
    {
        $today = now($context['timezone'])->toDateString();
        $rows = DB::table('daily_closings')->where('tenant_id', $context['tenantId'])
            ->whereIn('branch_id', $context['scopeBranchIds'])->where('status', 'open')
            ->whereDate('business_date', '>=', $dateFrom)->whereDate('business_date', '<=', $dateTo)
            ->whereDate('business_date', '<', $today)
            ->get(['id', 'branch_id', 'business_date', 'actual_cash']);

        $alerts = [];
        $covered = ['drafts' => [], 'reconciliations' => []];
        foreach ($rows as $row) {
            $branchId = (int) $row->branch_id;
            $summary = $this->summary->summarize($context['tenantId'], $branchId, $row->business_date);
            $readinessResult = $this->readiness->evaluate($context['tenantId'], $branchId, $row->business_date, $summary, $row->actual_cash);
            $covered['drafts'][$branchId][$row->business_date] = true;
            if (collect($readinessResult['blockers'])->contains(fn (array $blocker) => $blocker['code'] === 'CASH_RECONCILIATION_INCOMPLETE')) {
                $covered['reconciliations'][$branchId][$row->business_date] = true;
            }
            $alerts[] = [
                'code' => 'DAILY_CLOSING_BLOCKED', 'severity' => 'warning', 'sourceType' => 'daily_closing', 'sourceId' => (int) $row->id, 'reference' => null,
                'branch' => $this->branchRef($context, $branchId), 'amount' => null, 'occurredAt' => $row->business_date,
                'metadata' => ['businessDate' => $row->business_date, 'canClose' => $readinessResult['canClose'], 'blockers' => array_column($readinessResult['blockers'], 'code')],
            ];
        }

        return [$alerts, $covered];
    }

    /**
     * Requiredness and completion come from the shared Phase 9 policy through
     * FinancialReconciliationQueryService. A blocked Daily Closing is the more
     * actionable alert for the same cash/date issue, so it intentionally wins.
     */
    private function incompleteReconciliations(array $context, array $incomplete, array $covered): array
    {
        return collect($incomplete)->filter(fn (array $item) => ! isset($covered[$item['branchId']][$item['date']]))
            ->map(fn (array $item) => [
                'code' => 'RECONCILIATION_INCOMPLETE', 'severity' => 'warning', 'sourceType' => 'financial_reconciliation', 'sourceId' => null,
                'reference' => collect($item['accounts'])->pluck('code')->filter()->implode(', ') ?: null,
                'branch' => $this->branchRef($context, $item['branchId']), 'amount' => null, 'occurredAt' => $item['date'],
                'metadata' => ['type' => $item['type'], 'required' => true, 'policySeverity' => $item['severity'], 'accounts' => $item['accounts']],
            ])->values()->all();
    }

    private function financeConfiguration(array $context): array
    {
        $readiness = $this->setup->financeReadiness($context['tenantId']);
        if ($readiness['ready']) return [];

        return [[
            'code' => 'FINANCE_CONFIGURATION_REQUIRED',
            'severity' => collect($readiness['issues'])->contains(fn (array $issue) => $issue['severity'] === 'critical') ? 'critical' : 'warning',
            'sourceType' => 'finance_setup', 'sourceId' => null, 'reference' => null, 'branch' => null, 'amount' => null, 'occurredAt' => null,
            'metadata' => ['issues' => $readiness['issues']],
        ]];
    }

    private function lateActivityAfterClose(array $context, string $dateFrom, string $dateTo): array
    {
        $rows = DB::table('daily_closings')->where('tenant_id', $context['tenantId'])
            ->whereIn('branch_id', $context['scopeBranchIds'])->where('status', 'closed')
            ->whereDate('business_date', '>=', $dateFrom)->whereDate('business_date', '<=', $dateTo)
            ->get(['id', 'branch_id', 'business_date', 'closed_at']);

        $alerts = [];
        foreach ($rows as $row) {
            $branchId = (int) $row->branch_id;
            foreach ($this->integrity->lateActivityAfterClose($context['tenantId'], $branchId, $row->business_date, $row->closed_at) as $item) {
                $alerts[] = [
                    'code' => 'LATE_FINANCIAL_ACTIVITY_AFTER_CLOSE', 'severity' => 'critical', 'sourceType' => 'journal_entry', 'sourceId' => $item['journalId'], 'reference' => $item['reference'],
                    'branch' => $this->branchRef($context, $branchId), 'amount' => $item['amount'], 'occurredAt' => $item['postedAt'],
                    'metadata' => ['businessDate' => $row->business_date, 'sourceType' => $item['sourceType']],
                ];
            }
        }

        return $alerts;
    }

    private function unpostedInventoryFinancialEvents(array $context, string $dateFrom, string $dateTo): array
    {
        $range = BusinessDayRangeResolver::utcRangeForTimezone($context['timezone'], $dateFrom, $dateTo);
        $query = DB::table('stock_movements as m')->leftJoin('inventory_items as i', 'i.id', '=', 'm.inventory_item_id')
            ->where('m.tenant_id', $context['tenantId'])->whereIn('m.type', self::INVENTORY_POSTING_TYPES)
            ->whereBetween('m.occurred_at', [$range['start'], $range['end']]);
        BranchScope::apply($query, 'm.branch_id', $context['branchId'], $context['authorizedBranchIds']);
        $movements = $query->limit(500)->get(['m.id', 'm.type', 'm.branch_id', 'm.total_cost', 'm.quantity_out', 'm.occurred_at', 'i.name_en as item_name_en', 'i.name_ar as item_name_ar']);

        $alerts = [];
        foreach ($movements as $movement) {
            $impact = $this->mapper->impactForMovement($context['tenantId'], $movement);
            if (! in_array($impact['status'], ['CONFIGURATION_REQUIRED', 'FAILED'], true)) {
                continue;
            }
            $alerts[] = [
                'code' => 'UNPOSTED_INVENTORY_FINANCIAL_EVENT', 'severity' => 'critical', 'sourceType' => 'stock_movement', 'sourceId' => (int) $movement->id, 'reference' => null,
                'branch' => $this->branchRef($context, $movement->branch_id ? (int) $movement->branch_id : null), 'amount' => Money::decimal(Money::cents((string) $movement->total_cost, 'totalCost')), 'occurredAt' => $movement->occurred_at,
                'metadata' => ['type' => $movement->type, 'item' => $movement->item_name_en ?? $movement->item_name_ar, 'financeStatus' => $impact['status']],
            ];
            if (count($alerts) >= 50) {
                break;
            }
        }

        return $alerts;
    }

    private function draftJournalEntries(array $context, string $dateFrom, string $dateTo, array $coveredDates): array
    {
        $query = DB::table('journal_entries')->where('tenant_id', $context['tenantId'])->where('status', 'draft')
            ->where('entry_date', '>=', $dateFrom)->where('entry_date', '<=', $dateTo);
        BranchScope::apply($query, 'branch_id', $context['branchId'], $context['authorizedBranchIds']);
        $rows = $query->get(['id', 'branch_id', 'entry_date']);

        $counts = [];
        foreach ($rows as $row) {
            $branchKey = $row->branch_id ? (int) $row->branch_id : 0;
            if (isset($coveredDates[$branchKey][$row->entry_date])) {
                continue;
            }
            $counts[$branchKey] = ($counts[$branchKey] ?? 0) + 1;
        }

        $alerts = [];
        foreach ($counts as $branchKey => $count) {
            $alerts[] = [
                'code' => 'DRAFT_JOURNAL_ENTRIES', 'severity' => 'warning', 'sourceType' => 'journal_entry', 'sourceId' => null, 'reference' => null,
                'branch' => $branchKey ? $this->branchRef($context, $branchKey) : null, 'amount' => null, 'occurredAt' => null, 'metadata' => ['count' => $count],
            ];
        }

        return $alerts;
    }

    private function branchRef(array $context, ?int $branchId): ?array
    {
        if ($branchId === null) {
            return null;
        }

        return collect($context['authorizedBranches'])->firstWhere('id', $branchId);
    }
}
