<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DailyClosingService;
use App\Support\FinancialActor;
use App\Support\FinanceAccess;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class DailyClosingController extends Controller
{
    public function __construct(private readonly DailyClosingService $service) {}
    public function preview(Request $r): JsonResponse { [$t,$a]=$this->actor($r);$d=$r->validate(['branchId'=>['required','integer'],'date'=>['required','date']]);$row=$this->service->getOrCreate($r,$t,(int)$d['branchId'],$d['date'],$a);return response()->json(['data'=>$this->decorate($this->service->present($t,$row->branch_id,$row->business_date,$row),$r)]); }
    public function index(Request $r): JsonResponse { [$t,$a]=$this->actor($r);$d=$r->validate(['branchId'=>['nullable','integer'],'from'=>['nullable','date'],'to'=>['nullable','date'],'status'=>['nullable','in:open,closed'],'perPage'=>['nullable','integer','min:1','max:100']]);$q=DB::table('daily_closings as c')->join('branches as b','b.id','=','c.branch_id')->where('c.tenant_id',$t);if(($role=DB::table('users')->where('tenant_id',$t)->where('id',$a)->value('role'))!=='owner')$q->whereIn('c.branch_id',DB::table('user_branches')->where('tenant_id',$t)->where('user_id',$a)->pluck('branch_id'));foreach(['branchId'=>'c.branch_id','status'=>'c.status']as$k=>$col)if(!empty($d[$k]))$q->where($col,$d[$k]);if(!empty($d['from']))$q->whereDate('c.business_date','>=',$d['from']);if(!empty($d['to']))$q->whereDate('c.business_date','<=',$d['to']);$p=$q->orderByDesc('c.business_date')->paginate($d['perPage']??25,['c.*','b.name as branch_name']);$permissions=array_fill_keys(FinanceAccess::capabilities($r),true);return response()->json(['data'=>collect($p->items())->map(fn($x)=>['id'=>$x->id,'reference'=>$x->reference,'businessDate'=>$x->business_date,'branch'=>['id'=>$x->branch_id,'name'=>$x->branch_name],'status'=>$x->status,'expectedCash'=>$x->expected_cash,'actualCash'=>$x->actual_cash,'difference'=>$x->cash_difference,'closedBy'=>$x->closed_by,'closedAt'=>$x->closed_at,'allowedActions'=>$x->status==='open'?array_values(array_filter(['edit'=>isset($permissions['finance.daily_closing.manage'])?'edit':null,'close'=>isset($permissions['finance.daily_closing.close'])?'close':null])):[]])->values(),'meta'=>['currentPage'=>$p->currentPage(),'perPage'=>$p->perPage(),'total'=>$p->total(),'lastPage'=>$p->lastPage()]]); }
    public function show(Request $r,int $closing):JsonResponse{[$t,$a]=$this->actor($r);$row=$this->service->row($t,$closing);\App\Support\FinancialActor::assertBranchAccess($a,$t,$row->branch_id);return response()->json(['data'=>$this->decorate($this->service->present($t,$row->branch_id,$row->business_date,$row),$r)]);}
    public function update(Request $r,int $closing):JsonResponse{[$t,$a]=$this->actor($r);return response()->json(['data'=>$this->decorate($this->service->update($r,$t,$closing,$r->validate(['actualCash'=>['nullable','regex:/^\d+(\.\d{1,2})?$/'],'notes'=>['nullable','string','max:4000']]),$a),$r)]);}
    public function close(Request $r,int $closing):JsonResponse{[$t,$a]=$this->actor($r);return response()->json(['data'=>$this->decorate($this->service->close($r,$t,$closing,$r->validate(['actualCash'=>['nullable','regex:/^\d+(\.\d{1,2})?$/'],'notes'=>['nullable','string','max:4000']]),$a),$r)]);}
    private function actor(Request $r):array{$t=TenantContext::id($r);return[$t,FinancialActor::id($r,$t)];}
    private function decorate(array $row,Request $r):array{$permissions=array_fill_keys(FinanceAccess::capabilities($r),true);$row['allowedActions']=$row['status']==='open'?array_values(array_filter(['edit'=>isset($permissions['finance.daily_closing.manage'])?'edit':null,'close'=>$row['canClose']&&isset($permissions['finance.daily_closing.close'])?'close':null])):[];return $row;}
}
