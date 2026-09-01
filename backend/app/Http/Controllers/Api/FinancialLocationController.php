<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CashTransferService;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\FinancialLocationService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class FinancialLocationController extends Controller
{
    public function __construct(private readonly FinancialLocationService $locations, private readonly FinancialAccountBalanceQuery $balances, private readonly CashTransferService $transfers) {}

    public function index(Request $request, string $kind): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $query = DB::table('financial_locations as locations')->join('financial_accounts as accounts', 'accounts.id', '=', 'locations.financial_account_id')->leftJoin('branches', 'branches.id', '=', 'locations.branch_id')->where('locations.tenant_id', $tenantId)->where('locations.kind', $kind)->select('locations.*', 'accounts.code as account_code', 'accounts.name_ar as account_name_ar', 'accounts.normal_balance', 'branches.name as branch_name');
        if ($request->filled('status')) $query->where('locations.is_active', $request->query('status') === 'active');
        $paginator = $query->orderBy('locations.code')->paginate($this->perPage($request));
        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($tenantId, $row))->values(), 'meta' => $this->meta($paginator)]);
    }

    public function store(Request $request, string $kind): JsonResponse { $data = $this->validateLocation($request, $kind); $tenantId = TenantContext::id($request); $id = $this->locations->save($request, $tenantId, $data, null, FinancialActor::id($request, $tenantId)); return response()->json(['data' => $this->showRow($tenantId, $id)], 201); }
    public function update(Request $request, string $kind, int $location): JsonResponse { $data = $this->validateLocation($request, $kind, $location); $tenantId = TenantContext::id($request); $this->locations->save($request, $tenantId, $data, $location, FinancialActor::id($request, $tenantId)); return response()->json(['data' => $this->showRow($tenantId, $location)]); }
    public function status(Request $request, string $kind, int $location): JsonResponse { $data = $request->validate(['isActive' => ['required', 'boolean']]); $tenantId = TenantContext::id($request); $row = $this->locations->find($tenantId, $location); abort_unless($row->kind === $kind, 404); $this->locations->setStatus($request, $tenantId, $location, $data['isActive'], FinancialActor::id($request, $tenantId)); return response()->json(['data' => $this->showRow($tenantId, $location)]); }
    public function show(Request $request, string $kind, int $location): JsonResponse { $tenantId = TenantContext::id($request); $row = $this->locations->find($tenantId, $location); abort_unless($row->kind === $kind, 404); return response()->json(['data' => $this->showRow($tenantId, $location)]); }
    public function transactions(Request $request, int $location): JsonResponse { $tenantId = TenantContext::id($request); $row = $this->locations->find($tenantId, $location); $data = $request->validate(['from' => ['nullable', 'date'], 'to' => ['nullable', 'date'], 'search' => ['nullable', 'string', 'max:100']]); return response()->json(['data' => ['location' => $this->showRow($tenantId, $location), 'transactions' => $this->balances->transactions($tenantId, $row->financial_account_id, $data['from'] ?? null, $data['to'] ?? null, $data['search'] ?? null)]]); }
    public function transfer(Request $request): JsonResponse { $data = $request->validate(['fromFinancialLocationId' => ['required', 'integer'], 'toFinancialLocationId' => ['required', 'integer', 'different:fromFinancialLocationId'], 'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'], 'transferDate' => ['required', 'date'], 'description' => ['nullable', 'string', 'max:1000'], 'branchId' => ['nullable', 'integer'], 'idempotencyKey' => ['nullable', 'string', 'max:120']]); $tenantId = TenantContext::id($request); $row = $this->transfers->create($request, $tenantId, $data, FinancialActor::id($request, $tenantId)); return response()->json(['data' => $this->serializeTransfer($row)], 201); }
    public function reverseTransfer(Request $request, int $transfer): JsonResponse { $tenantId = TenantContext::id($request); $row = $this->transfers->reverse($request, $tenantId, $transfer, FinancialActor::id($request, $tenantId)); return response()->json(['data' => $this->serializeTransfer($row)]); }

    private function validateLocation(Request $request, string $kind, ?int $id = null): array { abort_unless(in_array($kind, ['cash', 'bank'], true), 404); $tenantId = TenantContext::id($request); $code = Rule::unique('financial_locations', 'code')->where(fn ($query) => $query->where('tenant_id', $tenantId)); if ($id) $code->ignore($id); return $request->validate(['code' => ['required', 'string', 'max:40', 'regex:/^[A-Za-z0-9_-]+$/', $code], 'name' => ['required', 'string', 'max:255'], 'type' => ['required', Rule::in($kind === 'cash' ? ['cash_drawer', 'main_safe', 'petty_cash'] : ['bank'])], 'branchId' => ['nullable', 'integer'], 'financialAccountId' => ['required', 'integer'], 'bankName' => [$kind === 'bank' ? 'required' : 'nullable', 'nullable', 'string', 'max:255'], 'maskedReference' => ['nullable', 'string', 'max:80'], 'isActive' => ['required', 'boolean']]) + ['kind' => $kind]; }
    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 100), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }
    private function showRow(int $tenantId, int $id): array { $row = DB::table('financial_locations as locations')->join('financial_accounts as accounts', 'accounts.id', '=', 'locations.financial_account_id')->leftJoin('branches', 'branches.id', '=', 'locations.branch_id')->where('locations.tenant_id', $tenantId)->where('locations.id', $id)->select('locations.*', 'accounts.code as account_code', 'accounts.name_ar as account_name_ar', 'accounts.normal_balance', 'branches.name as branch_name')->first(); abort_unless($row, 404); return $this->serialize($tenantId, $row); }
    private function serialize(int $tenantId, object $row): array { $today = now()->toDateString(); $summary = $this->balances->summary($tenantId, (int) $row->financial_account_id); $todaySummary = $this->balances->summary($tenantId, (int) $row->financial_account_id, $today, $today); return ['id' => (int) $row->id, 'branchId' => $row->branch_id ? (int) $row->branch_id : null, 'branchName' => $row->branch_name, 'financialAccountId' => (int) $row->financial_account_id, 'financialAccountCode' => $row->account_code, 'financialAccountNameAr' => $row->account_name_ar, 'code' => $row->code, 'name' => $row->name, 'kind' => $row->kind, 'type' => $row->type, 'bankName' => $row->bank_name, 'maskedReference' => $row->masked_reference, 'isActive' => (bool) $row->is_active, 'balance' => $summary['balance'], 'todayIncoming' => $todaySummary['incoming'], 'todayOutgoing' => $todaySummary['outgoing']]; }
    private function serializeTransfer(object $row): array { return ['id' => (int) $row->id, 'fromFinancialLocationId' => (int) $row->from_financial_location_id, 'toFinancialLocationId' => (int) $row->to_financial_location_id, 'amount' => $row->amount, 'transferDate' => $row->transfer_date, 'description' => $row->description, 'status' => $row->status, 'journalEntryId' => $row->journal_entry_id ? (int) $row->journal_entry_id : null, 'reversalJournalEntryId' => $row->reversal_journal_entry_id ? (int) $row->reversal_journal_entry_id : null]; }
}
