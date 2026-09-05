<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PaymentMethodService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class PaymentMethodController extends Controller
{
    public function __construct(private readonly PaymentMethodService $methods) {}
    public function index(Request $request): JsonResponse { $tenantId = TenantContext::id($request); $paginator = DB::table('payment_methods as methods')->join('financial_accounts as accounts', 'accounts.id', '=', 'methods.financial_account_id')->leftJoin('financial_locations as locations', 'locations.id', '=', 'methods.financial_location_id')->where('methods.tenant_id', $tenantId)->orderBy('methods.sort_order')->orderBy('methods.code')->paginate($this->perPage($request), ['methods.*', 'accounts.code as account_code', 'accounts.name_ar as account_name_ar', 'locations.name as location_name']); return response()->json(['data' => collect($paginator->items())->map($this->serialize(...))->values(), 'meta' => $this->meta($paginator)]); }
    public function store(Request $request): JsonResponse { $tenantId = TenantContext::id($request); $id = $this->methods->save($request, $tenantId, $this->validateMethod($request), null, FinancialActor::id($request, $tenantId)); return response()->json(['data' => $this->one($tenantId, $id)], 201); }
    public function update(Request $request, int $method): JsonResponse { $tenantId = TenantContext::id($request); $this->methods->save($request, $tenantId, $this->validateMethod($request, $method), $method, FinancialActor::id($request, $tenantId)); return response()->json(['data' => $this->one($tenantId, $method)]); }
    public function status(Request $request, int $method): JsonResponse { $data = $request->validate(['isActive' => ['required', 'boolean']]); $tenantId = TenantContext::id($request); $this->methods->status($request, $tenantId, $method, $data['isActive'], FinancialActor::id($request, $tenantId)); return response()->json(['data' => $this->one($tenantId, $method)]); }
    private function validateMethod(Request $request, ?int $id = null): array { $tenantId = TenantContext::id($request); $code = Rule::unique('payment_methods', 'code')->where(fn ($query) => $query->where('tenant_id', $tenantId)); if ($id) $code->ignore($id); return $request->validate(['code' => ['required','string','max:40','regex:/^[A-Za-z0-9_-]+$/',$code], 'name' => ['required','string','max:255'], 'type' => ['required', Rule::in(['cash','card','bank_transfer','delivery_app','customer_credit','other'])], 'financialAccountId' => ['required','integer'], 'financialLocationId' => ['nullable','integer'], 'isActive' => ['required','boolean'], 'sortOrder' => ['nullable','integer','min:0']]); }
    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 100), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }
    private function one(int $tenantId, int $id): array { $row = DB::table('payment_methods as methods')->join('financial_accounts as accounts', 'accounts.id', '=', 'methods.financial_account_id')->leftJoin('financial_locations as locations', 'locations.id', '=', 'methods.financial_location_id')->where('methods.tenant_id', $tenantId)->where('methods.id', $id)->first(['methods.*', 'accounts.code as account_code', 'accounts.name_ar as account_name_ar', 'locations.name as location_name']); abort_unless($row, 404); return $this->serialize($row); }
    private function serialize(object $row): array { return ['id'=>(int)$row->id,'code'=>$row->code,'name'=>$row->name,'type'=>$row->type,'financialAccountId'=>(int)$row->financial_account_id,'financialAccountCode'=>$row->account_code,'financialAccountNameAr'=>$row->account_name_ar,'financialLocationId'=>$row->financial_location_id ? (int)$row->financial_location_id : null,'financialLocationName'=>$row->location_name,'isActive'=>(bool)$row->is_active,'sortOrder'=>(int)$row->sort_order]; }
}
