<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\FinancialAccountRequest;
use App\Services\FinancialAccountService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FinancialAccountController extends Controller
{
    public function __construct(private readonly FinancialAccountService $accounts) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $query = DB::table('financial_accounts as accounts')->leftJoin('financial_accounts as parents', 'parents.id', '=', 'accounts.parent_account_id')->where('accounts.tenant_id', $tenantId)->whereNull('accounts.deleted_at')->select('accounts.*', 'parents.code as parent_code', 'parents.name_ar as parent_name_ar');
        if ($request->filled('search')) {
            $search = '%'.strtolower((string) $request->query('search')).'%';
            $query->where(fn (Builder $items) => $items->whereRaw('LOWER(accounts.code) LIKE ?', [$search])->orWhereRaw('LOWER(accounts.name_ar) LIKE ?', [$search])->orWhereRaw('LOWER(accounts.name_en) LIKE ?', [$search]));
        }
        if ($request->filled('group')) {
            $query->where('accounts.account_group', $request->query('group'));
        }
        if ($request->filled('status')) {
            $query->where('accounts.is_active', $request->query('status') === 'active');
        }
        $paginator = $query->orderBy('accounts.account_group')->orderBy('accounts.code')->paginate($this->perPage($request));

        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row))->values(), 'meta' => $this->meta($paginator)]);
    }

    public function store(FinancialAccountRequest $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $id = $this->accounts->create($request, $tenantId, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serialize($this->accounts->find($tenantId, $id))], 201);
    }

    public function update(FinancialAccountRequest $request, int $account): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->accounts->update($request, $tenantId, $account, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serialize($this->accounts->find($tenantId, $account))]);
    }

    public function status(Request $request, int $account): JsonResponse
    {
        $data = $request->validate(['isActive' => ['required', 'boolean']]);
        $tenantId = TenantContext::id($request);
        $this->accounts->setStatus($request, $tenantId, $account, (bool) $data['isActive'], FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serialize($this->accounts->find($tenantId, $account))]);
    }

    private function serialize(object $row): array
    {
        return ['id' => (int) $row->id, 'parentAccountId' => $row->parent_account_id ? (int) $row->parent_account_id : null, 'parentCode' => $row->parent_code ?? null, 'parentNameAr' => $row->parent_name_ar ?? null, 'code' => $row->code, 'nameAr' => $row->name_ar, 'nameEn' => $row->name_en, 'accountGroup' => $row->account_group, 'normalBalance' => $row->normal_balance, 'isActive' => (bool) $row->is_active, 'isSystemProtected' => (bool) $row->is_system_protected, 'createdAt' => $row->created_at, 'updatedAt' => $row->updated_at];
    }

    private function perPage(Request $request): int
    {
        return min(max((int) $request->query('perPage', 100), 1), 200);
    }

    private function meta($paginator): array
    {
        return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()];
    }
}
