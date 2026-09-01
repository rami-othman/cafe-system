<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AccountingPeriodService;
use App\Support\FinancialActor;
use App\Support\FinanceAccess;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class AccountingPeriodController extends Controller
{
    public function __construct(private readonly AccountingPeriodService $periods) {}
    public function index(Request $request): JsonResponse { $tenant = TenantContext::id($request); $permissions=array_fill_keys(FinanceAccess::capabilities($request),true); return response()->json(['data' => DB::table('accounting_periods')->where('tenant_id', $tenant)->orderByDesc('start_date')->get()->map(fn ($r) => $this->serialize($r)+['allowedActions'=>$r->status==='open'&&isset($permissions['finance.periods.manage'])?['edit']:[]])->values()]); }
    public function show(Request $request, int $period): JsonResponse { $tenant = TenantContext::id($request); $row = $this->periods->find($tenant, $period); $readiness=$this->periods->readiness($tenant, $period); return response()->json(['data' => $this->decorate($this->serialize($row) + ['readiness' => $readiness],$request)]); }
    public function store(Request $request): JsonResponse { $tenant = TenantContext::id($request); $row = $this->periods->create($request, $tenant, $this->data($request, false), FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->decorate($this->serialize($row),$request)], 201); }
    public function update(Request $request, int $period): JsonResponse { $tenant = TenantContext::id($request); $row = $this->periods->update($request, $tenant, $period, $this->data($request, true), FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->decorate($this->serialize($row),$request)]); }
    public function close(Request $request, int $period): JsonResponse { $tenant = TenantContext::id($request); return response()->json(['data' => $this->decorate($this->serialize($this->periods->close($request, $tenant, $period, FinancialActor::id($request, $tenant))),$request)]); }
    public function lock(Request $request, int $period): JsonResponse { $tenant = TenantContext::id($request); return response()->json(['data' => $this->decorate($this->serialize($this->periods->lock($request, $tenant, $period, FinancialActor::id($request, $tenant))),$request)]); }
    private function data(Request $request, bool $partial): array { return $request->validate(['name' => [$partial ? 'sometimes' : 'required', 'string', 'max:120'], 'startDate' => [$partial ? 'sometimes' : 'required', 'date_format:Y-m-d'], 'endDate' => [$partial ? 'sometimes' : 'required', 'date_format:Y-m-d'], 'notes' => ['sometimes', 'nullable', 'string', 'max:4000']]); }
    private function serialize(object $r): array { return ['id' => (int) $r->id, 'name' => $r->name, 'startDate' => $r->start_date, 'endDate' => $r->end_date, 'status' => $r->status, 'closedAt' => $r->closed_at, 'closedBy' => $r->closed_by ? (int) $r->closed_by : null, 'lockedAt' => $r->locked_at, 'lockedBy' => $r->locked_by ? (int) $r->locked_by : null, 'notes' => $r->notes, 'createdAt' => $r->created_at, 'updatedAt' => $r->updated_at]; }
    private function decorate(array $row,Request $request):array{$permissions=array_fill_keys(FinanceAccess::capabilities($request),true);$actions=[];if($row['status']==='open'){if(isset($permissions['finance.periods.manage']))$actions[]='edit';if(($row['readiness']['canClose']??false)&&isset($permissions['finance.periods.close']))$actions[]='close';}if($row['status']==='closed'&&isset($permissions['finance.periods.lock']))$actions[]='lock';$row['allowedActions']=$actions;return $row;}
}
