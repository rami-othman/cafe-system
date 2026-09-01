<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class DailyClosingService
{
    public function __construct(private readonly DailyClosingSummaryService $summary, private readonly DailyClosingReadinessService $readiness, private readonly DailyClosingIntegrityService $integrity, private readonly OperationalAuditService $audit) {}
    public function preview(Request $request,int $tenant,int $branch,string $date,int $actor): array { FinancialActor::assertBranchAccess($actor,$tenant,$branch); $row=DB::table('daily_closings')->where('tenant_id',$tenant)->where('branch_id',$branch)->whereDate('business_date',$date)->first(); return $this->present($tenant,$branch,$date,$row); }
    public function update(Request $request,int $tenant,int $id,array $data,int $actor): array { return DB::transaction(function() use($request,$tenant,$id,$data,$actor) { $row=$this->row($tenant,$id,true); FinancialActor::assertBranchAccess($actor,$tenant,$row->branch_id); if($row->status==='closed') throw ValidationException::withMessages(['closing'=>'Closed daily closings are immutable.']); DB::table('daily_closings')->where('id',$id)->update(['actual_cash'=>array_key_exists('actualCash',$data)?Money::decimal(Money::cents($data['actualCash'])):$row->actual_cash,'notes'=>$data['notes']??$row->notes,'updated_at'=>now()]); $after=$this->row($tenant,$id,true); $this->audit->record($request,$tenant,'daily_closing.updated','daily_closing',$id,(array)$row,(array)$after,$after->branch_id,$actor); return $this->present($tenant,$after->branch_id,$after->business_date,$after); }); }
    public function close(Request $request,int $tenant,int $id,array $data,int $actor): array { return DB::transaction(function() use($request,$tenant,$id,$data,$actor) { $row=$this->row($tenant,$id,true); FinancialActor::assertBranchAccess($actor,$tenant,$row->branch_id); if($row->status==='closed') return $this->present($tenant,$row->branch_id,$row->business_date,$row); $actual=array_key_exists('actualCash',$data)?Money::decimal(Money::cents($data['actualCash'])):$row->actual_cash; $view=$this->present($tenant,$row->branch_id,$row->business_date,(object)[...((array)$row),'actual_cash'=>$actual]); if(! $view['canClose']) throw ValidationException::withMessages(['closing'=>array_column($view['blockers'],'code')]); DB::table('daily_closings')->where('id',$id)->update(['actual_cash'=>$actual,'expected_cash'=>$view['cash']['expectedCash'],'cash_difference'=>$view['cash']['difference'],'summary_snapshot'=>json_encode($view['summary']), 'blockers_snapshot'=>json_encode(['blockers'=>[],'warnings'=>$view['warnings']]),'status'=>'closed','closed_by'=>$actor,'closed_at'=>now(),'calculated_at'=>now(),'notes'=>$data['notes']??$row->notes,'updated_at'=>now()]); $after=$this->row($tenant,$id,true); $this->audit->record($request,$tenant,'daily_closing.closed','daily_closing',$id,(array)$row,(array)$after,$after->branch_id,$actor); return $this->present($tenant,$after->branch_id,$after->business_date,$after); }); }
    public function getOrCreate(Request $request,int $tenant,int $branch,string $date,int $actor): object { return DB::transaction(function() use($request,$tenant,$branch,$date,$actor) { FinancialActor::assertBranchAccess($actor,$tenant,$branch); $row=DB::table('daily_closings')->where('tenant_id',$tenant)->where('branch_id',$branch)->whereDate('business_date',$date)->lockForUpdate()->first(); if($row)return $row; try { $id=DB::table('daily_closings')->insertGetId(['tenant_id'=>$tenant,'branch_id'=>$branch,'business_date'=>$date,'reference'=>'DC-'.Str::upper((string)Str::ulid()),'status'=>'open','created_by'=>$actor,'calculated_at'=>now(),'created_at'=>now(),'updated_at'=>now()]); } catch (\Throwable) { $id=DB::table('daily_closings')->where('tenant_id',$tenant)->where('branch_id',$branch)->whereDate('business_date',$date)->value('id'); } $row=$this->row($tenant,(int)$id,true); $this->audit->record($request,$tenant,'daily_closing.created','daily_closing',$row->id,[],(array)$row,$branch,$actor); return $row; }); }
    public function row(int $tenant,int $id,bool $lock=false):object{$q=DB::table('daily_closings')->where('tenant_id',$tenant)->where('id',$id);if($lock)$q->lockForUpdate();$r=$q->first();abort_unless($r,404,'Daily closing not found.');return $r;}
    public function present(int $tenant,int $branch,string $date,?object $row):array {
        $summary=$row?->status==='closed'?(array)json_decode($row->summary_snapshot,true):$this->summary->summarize($tenant,$branch,$date);
        $actual=$row?->actual_cash;
        $lateActivity=[];
        if ($row?->status==='closed') {
            $lateActivity=$this->integrity->lateActivityAfterClose($tenant,$branch,$date,$row->closed_at);
            $readiness=['readiness'=>'closed','canClose'=>false,'blockers'=>[],'warnings'=>(array)(json_decode($row->blockers_snapshot??'{}',true)['warnings']??[]),'financialIntegrity'=>['draftJournals'=>0,'missingPostings'=>0,'failedPostings'=>0,'lateActivityAfterClose'=>count($lateActivity)],'reconciliation'=>['required'=>false,'complete'=>true,'unresolvedCount'=>0,'requiredCount'=>0,'completedCount'=>0,'incompleteCount'=>0,'blockingCount'=>0,'warningCount'=>0,'accounts'=>[]]];
        } else {
            $readiness=$this->readiness->evaluate($tenant,$branch,$date,$summary,$actual);
        }
        $expected=$summary['cash']['expectedCash'];$diff=$actual===null?null:Money::decimal(Money::cents($actual)-Money::cents($expected));$state=$diff===null?null:(Money::cents(ltrim($diff,'-'))===0?'balanced':(str_starts_with($diff,'-')?'short':'over'));$summary['cash']+=['actualCash'=>$actual===null?null:Money::decimal(Money::cents($actual)),'difference'=>$diff,'differenceState'=>$state];
        return ['id'=>$row?->id,'reference'=>$row?->reference,'businessDate'=>$date,'status'=>$row?->status??'open','readiness'=>$readiness['readiness'],'canClose'=>$readiness['canClose'],'branch'=>$summary['branch'],'sales'=>$summary['sales'],'refunds'=>$summary['refunds'],'cash'=>$summary['cash'],'operations'=>$summary['operations'],'shifts'=>$summary['shifts'],'reconciliation'=>$readiness['reconciliation'],'financialIntegrity'=>$readiness['financialIntegrity'],'integrityIssues'=>['lateActivity'=>$lateActivity],'blockers'=>$readiness['blockers'],'warnings'=>$readiness['warnings'],'summary'=>$summary,'closedBy'=>$row?->closed_by,'closedAt'=>$row?->closed_at];
    }
}
