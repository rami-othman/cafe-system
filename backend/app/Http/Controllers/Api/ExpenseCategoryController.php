<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ExpenseCategoryService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ExpenseCategoryController extends Controller
{
    public function __construct(private readonly ExpenseCategoryService $categories) {}
    public function index(Request $request): JsonResponse { $tenant = TenantContext::id($request); $rows = DB::table('expense_categories as c')->join('financial_accounts as a', 'a.id', '=', 'c.financial_account_id')->where('c.tenant_id', $tenant)->whereNull('c.deleted_at')->orderBy('c.sort_order')->orderBy('c.code')->get(['c.*', 'a.code as account_code', 'a.name_ar as account_name']); return response()->json(['data' => $rows->map($this->serialize(...))->values()]); }
    public function store(Request $request): JsonResponse { $tenant = TenantContext::id($request); $id = $this->categories->save($request, $tenant, $this->data($request), null, FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->one($tenant, $id)], 201); }
    public function update(Request $request, int $category): JsonResponse { $tenant = TenantContext::id($request); $this->categories->save($request, $tenant, $this->data($request, $category), $category, FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->one($tenant, $category)]); }
    public function status(Request $request, int $category): JsonResponse { $data = $request->validate(['isActive' => ['required', 'boolean']]); $tenant = TenantContext::id($request); $this->categories->status($request, $tenant, $category, $data['isActive'], FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->one($tenant, $category)]); }
    private function data(Request $request, ?int $id = null): array { $tenant = TenantContext::id($request); $unique = Rule::unique('expense_categories', 'code')->where(fn ($q) => $q->where('tenant_id', $tenant)); if ($id) $unique->ignore($id); return $request->validate(['code' => ['required', 'string', 'max:40', 'regex:/^[A-Za-z0-9_-]+$/', $unique], 'name' => ['required', 'string', 'max:255'], 'financialAccountId' => ['required', 'integer'], 'isActive' => ['required', 'boolean'], 'sortOrder' => ['nullable', 'integer', 'min:0']]); }
    private function one(int $tenant, int $id): array { $row = DB::table('expense_categories as c')->join('financial_accounts as a', 'a.id', '=', 'c.financial_account_id')->where('c.tenant_id', $tenant)->where('c.id', $id)->whereNull('c.deleted_at')->first(['c.*', 'a.code as account_code', 'a.name_ar as account_name']); abort_unless($row, 404); return $this->serialize($row); }
    private function serialize(object $row): array { return ['id' => (int) $row->id, 'code' => $row->code, 'name' => $row->name, 'financialAccountId' => (int) $row->financial_account_id, 'financialAccountCode' => $row->account_code, 'financialAccountName' => $row->account_name, 'isActive' => (bool) $row->is_active, 'sortOrder' => (int) $row->sort_order]; }
}
