<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ExpenseService;
use App\Services\FinanceDashboardContext;
use App\Support\FinanceAccess;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ExpenseController extends Controller
{
    public function __construct(private readonly ExpenseService $expenses, private readonly FinanceDashboardContext $context) {}

    /** The actor's authorized branches for the Expenses global branch selector — never the tenant's full branch list. */
    public function branches(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant);
        $context = $this->context->resolve($tenant, $actor, []);

        return response()->json(['data' => ['branches' => $context['authorizedBranches']]]);
    }

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant); $context = $this->actionContext($request, $tenant, $actor);
        $paginator = $this->filtered($request, $tenant, $actor, $context)->orderByDesc('e.expense_date')->orderByDesc('e.id')->paginate($this->perPage($request));
        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row) + ['allowedActions' => $this->actions($context, $actor, $row)])->values(), 'meta' => $this->meta($paginator)]);
    }

    /** Same visibility + filters as index(), aggregated instead of paginated — the KPI band above the Expenses list. */
    public function summary(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant); $context = $this->actionContext($request, $tenant, $actor);
        $rows = $this->filtered($request, $tenant, $actor, $context)->get(['e.total_amount', 'e.status']);
        $totalCents = $rows->sum(fn (object $row) => Money::cents($row->total_amount));
        $pendingCents = $rows->where('status', 'pending_approval')->sum(fn (object $row) => Money::cents($row->total_amount));
        $rejectedCents = $rows->where('status', 'rejected')->sum(fn (object $row) => Money::cents($row->total_amount));
        $count = $rows->count();
        $averageCents = $count > 0 ? intdiv($totalCents, $count) : 0;

        return response()->json(['data' => [
            'count' => $count,
            'totalAmount' => Money::decimal($totalCents),
            'pendingApprovalAmount' => Money::decimal($pendingCents),
            'rejectedAmount' => Money::decimal($rejectedCents),
            'averageAmount' => Money::decimal($averageCents),
        ]]);
    }

    public function show(Request $request, int $expense): JsonResponse { $tenant = TenantContext::id($request); return response()->json(['data' => $this->one($tenant, $expense, $request)]); }
    public function store(Request $request): JsonResponse { $tenant = TenantContext::id($request); $id = $this->expenses->create($request, $tenant, $this->draftData($request), FinancialActor::id($request, $tenant))->id; return response()->json(['data' => $this->one($tenant, $id, $request)], 201); }
    public function update(Request $request, int $expense): JsonResponse { $tenant = TenantContext::id($request); $this->expenses->update($request, $tenant, $expense, $this->draftData($request), FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->one($tenant, $expense, $request)]); }
    public function action(Request $request, int $expense, string $action): JsonResponse { abort_unless(in_array($action, ['submit', 'approve', 'reject'], true), 404); $tenant = TenantContext::id($request); $this->expenses->transition($request, $tenant, $expense, $action, $request->validate(['rejectionReason' => ['nullable', 'string', 'max:1000']]), FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->one($tenant, $expense, $request)]); }
    public function pay(Request $request, int $expense): JsonResponse { $tenant = TenantContext::id($request); $data = $request->validate(['paymentMethodId' => ['required', 'integer'], 'financialLocationId' => ['required', 'integer'], 'paymentDate' => ['required', 'date'], 'description' => ['nullable', 'string', 'max:1000'], 'idempotencyKey' => ['required', 'string', 'max:120']]); $this->expenses->pay($request, $tenant, $expense, $data, FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->one($tenant, $expense, $request)]); }
    public function reverse(Request $request, int $expense): JsonResponse { $tenant = TenantContext::id($request); $this->expenses->reverse($request, $tenant, $expense, FinancialActor::id($request, $tenant)); return response()->json(['data' => $this->one($tenant, $expense, $request)]); }

    private function filtered(Request $request, int $tenant, int $actor, array $context)
    {
        $query = $this->rows($tenant);
        if ($context['role'] !== 'owner') $query->where(fn ($q) => $q->whereIn('e.branch_id', DB::table('user_branches')->where('tenant_id', $tenant)->where('user_id', $actor)->select('branch_id'))->orWhereNull('e.branch_id'));
        foreach (['branchId' => 'e.branch_id', 'expenseCategoryId' => 'e.expense_category_id', 'status' => 'e.status', 'paymentStatus' => 'e.payment_status', 'paymentMethodId' => 'e.payment_method_id'] as $input => $column) if ($request->filled($input)) $query->where($column, $request->input($input));
        if ($request->filled('from')) $query->whereDate('e.expense_date', '>=', $request->input('from')); if ($request->filled('to')) $query->whereDate('e.expense_date', '<=', $request->input('to'));
        if ($request->filled('search')) { $like = '%'.strtolower($request->input('search')).'%'; $query->where(fn ($q) => $q->whereRaw('LOWER(e.expense_number) LIKE ?', [$like])->orWhereRaw('LOWER(e.description) LIKE ?', [$like])); }

        return $query;
    }

    private function draftData(Request $request): array { return $request->validate(['branchId' => ['nullable', 'integer'], 'expenseCategoryId' => ['required', 'integer'], 'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'], 'taxAmount' => ['nullable', 'regex:/^\d+(\.\d{1,2})?$/'], 'expenseDate' => ['required', 'date'], 'description' => ['required', 'string', 'max:1000'], 'notes' => ['nullable', 'string', 'max:5000'], 'idempotencyKey' => ['nullable', 'string', 'max:120']]); }
    private function rows(int $tenant) { return DB::table('expenses as e')->join('expense_categories as c', 'c.id', '=', 'e.expense_category_id')->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')->leftJoin('payment_methods as pm', 'pm.id', '=', 'e.payment_method_id')->leftJoin('financial_locations as l', 'l.id', '=', 'e.paid_from_financial_location_id')->leftJoin('users as u', 'u.id', '=', 'e.created_by')->where('e.tenant_id', $tenant)->whereNull('e.deleted_at')->select('e.*', 'c.code as category_code', 'c.name as category_name', 'b.name as branch_name', 'pm.name as payment_method_name', 'l.name as financial_location_name', 'u.name as created_by_name'); }
    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 100), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }
    private function one(int $tenant, int $id, Request $request): array { $row = $this->rows($tenant)->where('e.id', $id)->first(); abort_unless($row, 404); $actor = FinancialActor::id($request, $tenant); FinancialActor::assertBranchAccess($actor, $tenant, $row->branch_id ? (int) $row->branch_id : null); return $this->serialize($row) + ['allowedActions' => $this->actions($this->actionContext($request, $tenant, $actor), $actor, $row)]; }
    private function actionContext(Request $request, int $tenant, int $actor): array { $role = (string) DB::table('users')->where('tenant_id', $tenant)->where('id', $actor)->value('role'); $rules = $role === 'owner' ? [] : DB::table('finance_approval_rules')->where('tenant_id', $tenant)->where('action_type', 'expense_approve')->where('role', $role)->where('is_active', true)->get(['branch_id', 'max_amount'])->keyBy(fn (object $rule) => $rule->branch_id === null ? 'global' : (string) $rule->branch_id)->all(); return ['role' => $role, 'permissions' => array_fill_keys(FinanceAccess::capabilities($request), true), 'rules' => $rules]; }
    private function actions(array $context, int $actor, object $row): array { $can = fn (string $permission): bool => isset($context['permissions'][$permission]); $actions = []; if ($row->status === 'draft') { if ($can('finance.expenses.edit')) $actions[] = 'edit'; if ($can('finance.expenses.submit')) $actions[] = 'submit'; } if ($row->status === 'pending_approval') { $rule = $context['rules'][(string) $row->branch_id] ?? $context['rules']['global'] ?? null; $approvable = $context['role'] === 'owner' || ((int) $row->created_by !== $actor && $rule && ($rule->max_amount === null || Money::cents($row->total_amount) <= Money::cents($rule->max_amount))); if ($can('finance.expenses.approve') && $approvable) $actions[] = 'approve'; if ($can('finance.expenses.reject')) $actions[] = 'reject'; } if ($row->status === 'approved' && $can('finance.expenses.pay')) $actions[] = 'pay'; if ($row->status === 'paid' && $can('finance.expenses.reverse')) $actions[] = 'reverse'; return $actions; }
    private function serialize(object $row): array { return ['id' => (int) $row->id, 'expenseNumber' => $row->expense_number, 'branchId' => $row->branch_id ? (int) $row->branch_id : null, 'branchName' => $row->branch_name, 'expenseCategoryId' => (int) $row->expense_category_id, 'expenseCategoryCode' => $row->category_code, 'expenseCategoryName' => $row->category_name, 'amount' => Money::decimal(Money::cents($row->amount)), 'taxAmount' => Money::decimal(Money::cents($row->tax_amount)), 'totalAmount' => Money::decimal(Money::cents($row->total_amount)), 'expenseDate' => $row->expense_date, 'description' => $row->description, 'notes' => $row->notes, 'status' => $row->status, 'paymentStatus' => $row->payment_status, 'paymentMethodId' => $row->payment_method_id ? (int) $row->payment_method_id : null, 'paymentMethodName' => $row->payment_method_name, 'financialLocationId' => $row->paid_from_financial_location_id ? (int) $row->paid_from_financial_location_id : null, 'financialLocationName' => $row->financial_location_name, 'paidAt' => $row->paid_at, 'journalEntryId' => $row->journal_entry_id ? (int) $row->journal_entry_id : null, 'reversalJournalEntryId' => $row->reversal_journal_entry_id ? (int) $row->reversal_journal_entry_id : null, 'createdByName' => $row->created_by_name, 'approvedAt' => $row->approved_at, 'rejectedAt' => $row->rejected_at, 'rejectionReason' => $row->rejection_reason, 'createdAt' => $row->created_at, 'updatedAt' => $row->updated_at]; }
}
