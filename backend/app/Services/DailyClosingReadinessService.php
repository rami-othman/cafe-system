<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;

final class DailyClosingReadinessService
{
    public function __construct(
        private readonly DailyClosingReconciliationPolicy $reconciliation,
        private readonly DailyClosingIntegrityService $integrity,
    ) {}

    public function evaluate(int $tenant, int $branch, string $date, array $summary, ?string $actualCash): array
    {
        $blockers=[]; $warn=[]; $add=function(string $code,string $severity,array $extra=[]) use (&$blockers,&$warn):void { $row=['code'=>$code,'severity'=>$severity]+$extra; if ($severity === 'blocking') $blockers[]=$row; else $warn[]=$row; };
        if ($summary['shifts']['open'] > 0) $add('OPEN_SHIFTS','blocking',['count'=>$summary['shifts']['open']]);
        if ($summary['operations']['pendingExpensesCount'] > 0) $add('PENDING_EXPENSE_APPROVAL','blocking',['count'=>$summary['operations']['pendingExpensesCount']]);
        if ($actualCash === null) $add('MISSING_ACTUAL_CASH','blocking'); else { $d=Money::cents($actualCash)-Money::cents($summary['cash']['expectedCash']); if ($d !== 0) $add('CASH_DIFFERENCE','blocking',['amount'=>Money::decimal($d)]); }
        $drafts=DB::table('journal_entries')->where('tenant_id',$tenant)->where('branch_id',$branch)->where('status','draft')->whereDate('entry_date',$date)->count(); if ($drafts) $add('DRAFT_JOURNALS','blocking',['count'=>$drafts]);

        $inventoryIssues = $this->integrity->inventoryPostingIssues($tenant, $branch, $date);
        if ($inventoryIssues !== []) $add('UNPOSTED_INVENTORY_FINANCIAL_EVENT','blocking',['count'=>count($inventoryIssues),'items'=>$inventoryIssues]);

        $reconciliation = $this->reconciliation->evaluate($tenant, $branch, $date, $summary);
        foreach ($reconciliation['blockers'] as $row) $blockers[] = $row;
        foreach ($reconciliation['warnings'] as $row) $warn[] = $row;

        $missingPostings = collect($inventoryIssues)->where('financeStatus', 'CONFIGURATION_REQUIRED')->count();
        $failedPostings = collect($inventoryIssues)->where('financeStatus', 'FAILED')->count();

        return ['readiness'=>$blockers===[]?'ready':'blocked','canClose'=>$blockers===[],'blockers'=>$blockers,'warnings'=>$warn,'financialIntegrity'=>['draftJournals'=>$drafts,'missingPostings'=>$missingPostings,'failedPostings'=>$failedPostings,'lateActivityAfterClose'=>0],'reconciliation'=>$reconciliation['summary']+['required'=>$reconciliation['summary']['requiredCount']>0,'complete'=>$reconciliation['summary']['incompleteCount']===0,'unresolvedCount'=>$reconciliation['summary']['incompleteCount'],'accounts'=>$reconciliation['accounts']]];
    }
}
