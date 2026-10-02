<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\FinancialAccountRequest;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\FinancialAccountService;
use App\Support\ArabicSearch;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class FinancialAccountController extends Controller
{
    public function __construct(private readonly FinancialAccountService $accounts, private readonly FinancialAccountBalanceQuery $balances) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $query = DB::table('financial_accounts as accounts')->leftJoin('financial_accounts as parents', 'parents.id', '=', 'accounts.parent_account_id')->where('accounts.tenant_id', $tenantId)->whereNull('accounts.deleted_at')->select('accounts.*', 'parents.code as parent_code', 'parents.name_ar as parent_name_ar', 'parents.account_group as parent_group', 'parents.normal_balance as parent_normal_balance');
        if ($request->filled('group')) {
            $query->where('accounts.account_group', $request->query('group'));
        }
        if ($request->filled('status')) {
            $query->where('accounts.is_active', $request->query('status') === 'active');
        }
        if ($request->filled('system')) {
            $query->where('accounts.is_system_protected', $request->query('system') === 'system');
        }
        if ($request->filled('search')) {
            return $this->searchIndex($request, $tenantId, $query);
        }
        $paginator = $query->orderBy('accounts.account_group')->orderBy('accounts.code')->paginate($this->perPage($request));
        $rows = collect($paginator->items());
        $balances = $this->balances->balancesForAccounts($tenantId, $rows->pluck('id')->map(fn ($id) => (int) $id)->all());

        return response()->json(['data' => $rows->map(fn (object $row) => $this->serialize($row, $balances[(int) $row->id] ?? null))->values(), 'meta' => $this->meta($paginator)]);
    }

    /**
     * Forgiving search (ArabicSearch): spelling variants, typos and the parent
     * path ("موردين ارت") all match, and the best matches come first.
     */
    private function searchIndex(Request $request, int $tenantId, Builder $query): JsonResponse
    {
        $term = (string) $request->query('search');
        $paths = $this->accountPaths($tenantId);
        $scored = [];
        foreach ($query->get() as $row) {
            $score = ArabicSearch::score($term, [
                (string) $row->code, (string) $row->name_ar, (string) $row->name_en, $paths[(int) $row->id] ?? '',
            ]);
            if ($score > 0) {
                $scored[] = [$score, $row];
            }
        }
        usort($scored, fn (array $a, array $b): int => [$b[0], $a[1]->code] <=> [$a[0], $b[1]->code]);
        $perPage = $this->perPage($request);
        $page = max(1, (int) $request->query('page', 1));
        $total = count($scored);
        $rows = collect(array_column(array_slice($scored, ($page - 1) * $perPage, $perPage), 1));
        $balances = $this->balances->balancesForAccounts($tenantId, $rows->pluck('id')->map(fn ($id) => (int) $id)->all());

        return response()->json([
            'data' => $rows->map(fn (object $row) => $this->serialize($row, $balances[(int) $row->id] ?? null))->values(),
            'meta' => ['currentPage' => $page, 'perPage' => $perPage, 'total' => $total, 'lastPage' => max(1, (int) ceil($total / $perPage))],
        ]);
    }

    /** @return array<int, string> ancestors' names per account, e.g. "الموجودات › الزبائن". */
    private function accountPaths(int $tenantId): array
    {
        $nodes = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')
            ->get(['id', 'parent_account_id', 'name_ar'])->keyBy('id');
        $paths = [];
        foreach ($nodes as $node) {
            $names = [];
            $seen = [(int) $node->id => true];
            for ($parent = $nodes[$node->parent_account_id] ?? null; $parent && ! isset($seen[(int) $parent->id]); $parent = $nodes[$parent->parent_account_id] ?? null) {
                $seen[(int) $parent->id] = true;
                $names[] = $parent->name_ar;
            }
            $paths[(int) $node->id] = implode(' ', $names);
        }

        return $paths;
    }

    /** Lightweight complete hierarchy for the account tree; balances are loaded on detail. */
    public function catalog(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $query = DB::table('financial_accounts as accounts')
            ->leftJoin('financial_accounts as parents', 'parents.id', '=', 'accounts.parent_account_id')
            ->where('accounts.tenant_id', $tenantId)->whereNull('accounts.deleted_at');
        if (Schema::hasColumn('financial_accounts', 'catalog_source') &&
            DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('catalog_source', 'phinix')->exists()) {
            $query->where('accounts.catalog_source', 'phinix');
        }
        $rows = $query
            ->orderBy('accounts.code')
            ->get(['accounts.id', 'accounts.parent_account_id', 'accounts.code', 'accounts.name_ar', 'accounts.name_en',
                'accounts.account_group', 'accounts.normal_balance',
                'accounts.is_active', 'accounts.is_system_protected', 'accounts.created_at', 'accounts.updated_at',
                'parents.code as parent_code', 'parents.name_ar as parent_name_ar',
                'parents.account_group as parent_group', 'parents.normal_balance as parent_normal_balance']);

        return response()->json(['data' => $rows->map(fn (object $row) => $this->serialize($row))->values()]);
    }

    public function store(FinancialAccountRequest $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $id = $this->accounts->create($request, $tenantId, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serialize($this->accounts->find($tenantId, $id))], 201);
    }

    /**
     * Return one tenant-scoped account with its direct parent presentation.
     * The chart list intentionally stays paginated; the detail workspace must
     * never depend on whether the selected account happens to be on that page.
     */
    public function show(Request $request, int $account): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $row = DB::table('financial_accounts as accounts')
            ->leftJoin('financial_accounts as parents', 'parents.id', '=', 'accounts.parent_account_id')
            ->where('accounts.tenant_id', $tenantId)
            ->where('accounts.id', $account)
            ->whereNull('accounts.deleted_at')
            ->select('accounts.*', 'parents.code as parent_code', 'parents.name_ar as parent_name_ar', 'parents.account_group as parent_group', 'parents.normal_balance as parent_normal_balance')
            ->first();

        abort_unless($row, 404, 'Financial account not found.');
        $balance = $this->balances->balanceWithChildren($tenantId, $account);

        return response()->json(['data' => $this->serialize($row, $balance)]);
    }

    public function transactions(Request $request, int $account): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->accounts->find($tenantId, $account);
        $filters = $request->validate([
            'page' => ['nullable', 'integer', 'min:1'],
            'perPage' => ['nullable', 'integer', 'min:1', 'max:100'],
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:from'],
            'search' => ['nullable', 'string', 'max:120'],
        ]);
        $page = (int) ($filters['page'] ?? 1);
        $perPage = (int) ($filters['perPage'] ?? 50);
        $rows = $this->balances->transactions(
            $tenantId,
            $account,
            $filters['from'] ?? null,
            $filters['to'] ?? null,
            $filters['search'] ?? null,
        );
        $total = count($rows);

        return response()->json([
            'data' => array_slice($rows, ($page - 1) * $perPage, $perPage),
            'meta' => [
                'currentPage' => $page,
                'perPage' => $perPage,
                'total' => $total,
                'lastPage' => max(1, (int) ceil($total / $perPage)),
            ],
        ]);
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

    private function serialize(object $row, ?array $balance = null): array
    {
        $parent = null;
        if ($row->parent_account_id && ! isset($row->parent_group)) {
            $parent = DB::table('financial_accounts')->where('id', $row->parent_account_id)->first(['code', 'name_ar', 'account_group', 'normal_balance']);
        }
        $parentGroup = $row->parent_group ?? $parent?->account_group;
        $parentNormal = $row->parent_normal_balance ?? $parent?->normal_balance;
        $categoryOverride = $parentGroup !== null && $row->account_group !== $parentGroup;
        $baseNormal = $categoryOverride
            ? (in_array($row->account_group, ['liabilities', 'equity', 'revenue'], true) ? 'credit' : 'debit')
            : $parentNormal;
        $isContra = $baseNormal !== null && $row->normal_balance !== $baseNormal;

        return ['id' => (int) $row->id, 'parentAccountId' => $row->parent_account_id ? (int) $row->parent_account_id : null, 'parentCode' => $row->parent_code ?? $parent?->code, 'parentNameAr' => $row->parent_name_ar ?? $parent?->name_ar, 'code' => $row->code, 'nameAr' => $row->name_ar, 'nameEn' => $row->name_en, 'accountGroup' => $row->account_group, 'normalBalance' => $row->normal_balance, 'isContra' => $isContra, 'categoryOverride' => $categoryOverride, 'isActive' => (bool) $row->is_active, 'isSystemProtected' => (bool) $row->is_system_protected, 'createdAt' => $row->created_at, 'updatedAt' => $row->updated_at, 'balance' => $balance['balance'] ?? '0.00', 'totalDebit' => $balance['totalDebit'] ?? '0.00', 'totalCredit' => $balance['totalCredit'] ?? '0.00', 'lastMovementDate' => $balance['lastMovementDate'] ?? null];
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
