<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;

final class AccountingPeriodReadinessService
{
    public function __construct(private readonly DailyClosingIntegrityService $integrity) {}

    public function evaluate(int $tenantId, string $from, string $to): array
    {
        $blockers = [];
        $drafts = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('status', 'draft')
            ->whereBetween('entry_date', [$from, $to])->count();
        if ($drafts) $blockers[] = ['code' => 'DRAFT_JOURNALS', 'count' => $drafts];

        $unbalancedRows = DB::table('journal_entries as entries')->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')
            ->where('entries.tenant_id', $tenantId)->where('lines.tenant_id', $tenantId)->where('entries.status', 'posted')
            ->whereBetween('entries.entry_date', [$from, $to])->groupBy('entries.id')
            ->selectRaw('entries.id, MIN(entries.entry_number) as entry_number, MIN(entries.source_type) as source_type, SUM(lines.debit) as debit, SUM(lines.credit) as credit')->get()
            ->filter(fn ($row) => Money::cents($row->debit) !== Money::cents($row->credit) || Money::cents($row->debit) <= 0)->values();
        $unbalanced = $unbalancedRows->count();
        if ($unbalanced) $blockers[] = ['code' => 'UNBALANCED_POSTED_JOURNALS', 'count' => $unbalanced, 'journals' => $unbalancedRows->map(fn ($row) => ['id' => (int) $row->id, 'reference' => $row->entry_number, 'sourceType' => $row->source_type, 'debit' => $row->debit, 'credit' => $row->credit])->all()];

        $openClosings = DB::table('daily_closings')->where('tenant_id', $tenantId)->where('status', 'open')
            ->whereBetween('business_date', [$from, $to])->count();
        if ($openClosings) $blockers[] = ['code' => 'OPEN_DAILY_CLOSINGS', 'count' => $openClosings];

        $inventoryIssues = 0;
        foreach (DB::table('stock_movements')->where('tenant_id', $tenantId)->whereBetween('occurred_at', [$from.' 00:00:00', $to.' 23:59:59'])->whereNotNull('branch_id')->selectRaw('branch_id, DATE(occurred_at) as business_date')->distinct()->get() as $day) {
            $inventoryIssues += count($this->integrity->inventoryPostingIssues($tenantId, (int) $day->branch_id, $day->business_date));
        }
        if ($inventoryIssues) $blockers[] = ['code' => 'FAILED_MANDATORY_FINANCIAL_POSTINGS', 'count' => $inventoryIssues];

        $late = 0;
        foreach (DB::table('daily_closings')->where('tenant_id', $tenantId)->where('status', 'closed')->whereBetween('business_date', [$from, $to])->get(['branch_id', 'business_date', 'closed_at']) as $closing) {
            $late += count($this->integrity->lateActivityAfterClose($tenantId, (int) $closing->branch_id, $closing->business_date, $closing->closed_at));
        }
        if ($late) $blockers[] = ['code' => 'LATE_FINANCIAL_ACTIVITY', 'count' => $late];

        return ['canClose' => $blockers === [], 'blockers' => $blockers, 'warnings' => []];
    }
}
