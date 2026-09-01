<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinancialReconciliationQueryService;
use App\Services\FinancialReconciliationService;
use App\Support\FinancialActor;
use App\Support\FinanceAccess;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

final class FinancialReconciliationController extends Controller
{
    public function __construct(private readonly FinancialReconciliationService $service, private readonly FinancialReconciliationQueryService $query) {}
    public function index(Request $r): JsonResponse { [$t,$a] = $this->actor($r); $result=$this->query->list($t, $a, $r->validate(['status' => ['nullable', Rule::in(['draft','in_progress','completed'])], 'type' => ['nullable', Rule::in(['cash','bank','card'])], 'financialLocationId' => ['nullable','integer'], 'from' => ['nullable','date'], 'to' => ['nullable','date'], 'search' => ['nullable','string','max:80'], 'perPage' => ['nullable','integer','min:1','max:100']])); $permissions=array_fill_keys(FinanceAccess::capabilities($r),true);$result['data']=collect($result['data'])->map(fn(array $row)=>$this->decorate($row,$permissions))->values();return response()->json($result); }
    public function store(Request $r): JsonResponse { [$t,$a] = $this->actor($r); $row = $this->service->create($r, $t, $this->createData($r), $a); return response()->json(['data' => $this->decorate($this->query->detail($t, $a, $row->id),array_fill_keys(FinanceAccess::capabilities($r),true))], 201); }
    public function show(Request $r, int $reconciliation): JsonResponse { [$t,$a] = $this->actor($r); return response()->json(['data' => $this->decorate($this->query->detail($t, $a, $reconciliation),array_fill_keys(FinanceAccess::capabilities($r),true))]); }
    public function update(Request $r, int $reconciliation): JsonResponse { [$t,$a] = $this->actor($r); $row = $this->service->update($r, $t, $reconciliation, $r->validate(['externalOpeningBalance' => ['nullable','regex:/^\d+(\.\d{1,2})?$/'], 'externalClosingBalance' => ['nullable','regex:/^\d+(\.\d{1,2})?$/'], 'actualCashCount' => ['nullable','regex:/^\d+(\.\d{1,2})?$/'], 'notes' => ['nullable','string','max:4000']]), $a); return response()->json(['data' => $this->decorate($this->query->detail($t, $a, $row->id),array_fill_keys(FinanceAccess::capabilities($r),true))]); }
    public function systemTransactions(Request $r, int $reconciliation): JsonResponse { [$t,$a] = $this->actor($r); return response()->json(['data' => $this->query->systemTransactions($t, $a, $reconciliation)]); }
    public function suggestions(Request $r, int $reconciliation): JsonResponse { [$t,$a] = $this->actor($r); return response()->json(['data' => $this->query->suggestions($t, $a, $reconciliation)]); }
    public function addLine(Request $r, int $reconciliation): JsonResponse { [$t,$a] = $this->actor($r); return response()->json(['data' => $this->service->addLine($r, $t, $reconciliation, $this->lineData($r, true), $a)], 201); }
    public function updateLine(Request $r, int $reconciliation, int $line): JsonResponse { [$t,$a] = $this->actor($r); return response()->json(['data' => $this->service->updateLine($r, $t, $reconciliation, $line, $this->lineData($r, false), $a)]); }
    public function deleteLine(Request $r, int $reconciliation, int $line): JsonResponse { [$t,$a] = $this->actor($r); $this->service->deleteLine($r, $t, $reconciliation, $line, $a); return response()->json([], 204); }
    public function match(Request $r, int $reconciliation): JsonResponse { [$t,$a] = $this->actor($r); return response()->json(['data' => $this->service->match($r, $t, $reconciliation, $r->validate(['statementLineId' => ['required','integer'], 'journalEntryId' => ['required','integer'], 'amount' => ['required','regex:/^\d+(\.\d{1,2})?$/'], 'idempotencyKey' => ['nullable','string','max:120']]), $a)], 201); }
    public function unmatch(Request $r, int $reconciliation, int $match): JsonResponse { [$t,$a] = $this->actor($r); $this->service->unmatch($r, $t, $reconciliation, $match, $a); return response()->json([], 204); }
    public function complete(Request $r, int $reconciliation): JsonResponse { [$t,$a] = $this->actor($r); $row = $this->service->complete($r, $t, $reconciliation, $a, $this->query); return response()->json(['data' => $this->query->detail($t, $a, $row->id)]); }
    private function actor(Request $r): array { $tenant = TenantContext::id($r); return [$tenant, FinancialActor::id($r, $tenant)]; }
    private function decorate(array $row,array $permissions):array{$actions=[];if($row['status']!=='completed'&&isset($permissions['finance.reconciliation.manage']))$actions=['edit','match','statementLineManage'];if($row['canComplete']&&isset($permissions['finance.reconciliation.complete']))$actions[]='complete';$row['allowedActions']=$actions;return $row;}
    private function createData(Request $r): array { return $r->validate(['type' => ['required', Rule::in(['cash','bank','card'])], 'financialLocationId' => ['nullable','integer','required_unless:type,card'], 'paymentMethodId' => ['nullable','integer','required_if:type,card'], 'dateFrom' => ['required','date'], 'dateTo' => ['required','date','after_or_equal:dateFrom'], 'externalOpeningBalance' => ['nullable','regex:/^\d+(\.\d{1,2})?$/'], 'externalClosingBalance' => ['nullable','regex:/^\d+(\.\d{1,2})?$/'], 'actualCashCount' => ['nullable','regex:/^\d+(\.\d{1,2})?$/'], 'notes' => ['nullable','string','max:4000'], 'idempotencyKey' => ['nullable','string','max:120']]); }
    private function lineData(Request $r, bool $required): array { return $r->validate(['transactionDate' => [$required ? 'required':'nullable','date'], 'valueDate' => ['nullable','date'], 'reference' => ['nullable','string','max:120'], 'description' => [$required ? 'required':'nullable','string','max:4000'], 'amount' => [$required ? 'required':'nullable','regex:/^\d+(\.\d{1,2})?$/'], 'direction' => [$required ? 'required':'nullable', Rule::in(['inflow','outflow'])], 'externalIdentifier' => ['nullable','string','max:120']]); }
}
