<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SupplierInvoiceService;
use App\Services\SupplierPayableQueryService;
use App\Support\FinancialActor;
use App\Support\FinanceAccess;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupplierInvoiceController extends Controller
{
    public function __construct(private readonly SupplierInvoiceService $invoices, private readonly SupplierPayableQueryService $payable) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $q = $this->rows($tenant);
        if (DB::table('users')->where('tenant_id', $tenant)->where('id', $actor)->value('role') !== 'owner') {
            $q->where(fn ($scope) => $scope->whereIn('i.branch_id', DB::table('user_branches')->where('tenant_id', $tenant)->where('user_id', $actor)->select('branch_id'))->orWhereNull('i.branch_id'));
        }
        foreach (['supplierId' => 'i.supplier_id', 'branchId' => 'i.branch_id', 'status' => 'i.status', 'invoiceType' => 'i.invoice_type'] as $input => $column) {
            if ($request->filled($input)) {
                $q->where($column, $request->input($input));
            }
        }
        if ($request->boolean('overdueOnly')) {
            $q->whereIn('i.status', ['posted', 'partially_paid'])->where('i.due_date', '<', now()->toDateString());
        }
        if ($request->filled('from')) {
            $q->whereDate('i.invoice_date', '>=', $request->input('from'));
        }
        if ($request->filled('to')) {
            $q->whereDate('i.invoice_date', '<=', $request->input('to'));
        }

        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        $paginator = $q->orderByDesc('i.invoice_date')->orderByDesc('i.id')->paginate($this->perPage($request));
        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row) + ['allowedActions' => $this->actions($row, $permissions)])->values(), 'meta' => $this->meta($paginator)]);
    }

    public function show(Request $request, int $invoice): JsonResponse
    {
        $tenant = TenantContext::id($request);

        return response()->json(['data' => $this->one($tenant, $invoice, $request)]);
    }

    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 100), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $id = $this->invoices->create($request, $tenant, $this->draftData($request), FinancialActor::id($request, $tenant))->id;

        return response()->json(['data' => $this->one($tenant, $id, $request)], 201);
    }

    public function update(Request $request, int $invoice): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->invoices->update($request, $tenant, $invoice, $this->draftData($request), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->one($tenant, $invoice, $request)]);
    }

    public function post(Request $request, int $invoice): JsonResponse
    {
        $data = $request->validate(['idempotencyKey' => ['required', 'string', 'max:120']]);
        $tenant = TenantContext::id($request);
        $this->invoices->post($request, $tenant, $invoice, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->one($tenant, $invoice, $request)]);
    }

    public function reverse(Request $request, int $invoice): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->invoices->reverse($request, $tenant, $invoice, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->one($tenant, $invoice, $request)]);
    }

    private function draftData(Request $request): array
    {
        return $request->validate([
            'branchId' => ['nullable', 'integer'],
            'supplierId' => ['required', 'integer'],
            'invoiceNumber' => ['required', 'string', 'max:80'],
            'invoiceDate' => ['required', 'date'],
            'dueDate' => ['required', 'date'],
            'invoiceType' => ['required', 'in:expense,inventory,other'],
            'expenseCategoryId' => ['nullable', 'integer', 'required_if:invoiceType,expense'],
            'debitAccountId' => ['nullable', 'integer', 'required_if:invoiceType,other'],
            'subtotal' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'taxAmount' => ['nullable', 'regex:/^\d+(\.\d{1,2})?$/'],
            'description' => ['nullable', 'string', 'max:1000'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'idempotencyKey' => ['nullable', 'string', 'max:120'],
        ]);
    }

    private function rows(int $tenant)
    {
        return DB::table('supplier_invoices as i')
            ->join('suppliers as s', 's.id', '=', 'i.supplier_id')
            ->join('financial_accounts as a', 'a.id', '=', 'i.debit_account_id')
            ->leftJoin('branches as b', 'b.id', '=', 'i.branch_id')
            ->leftJoin('expense_categories as c', 'c.id', '=', 'i.expense_category_id')
            ->where('i.tenant_id', $tenant)->whereNull('i.deleted_at')
            ->select('i.*', 's.name as supplier_name', 's.supplier_number', 'a.code as debit_account_code', 'a.name_ar as debit_account_name', 'b.name as branch_name', 'c.name as expense_category_name');
    }

    private function one(int $tenant, int $id, Request $request): array
    {
        $row = $this->rows($tenant)->where('i.id', $id)->first();
        abort_unless($row, 404);
        $actor = FinancialActor::id($request, $tenant);
        FinancialActor::assertBranchAccess($actor, $tenant, $row->branch_id ? (int) $row->branch_id : null);

        return $this->serialize($row) + ['allowedActions' => $this->actions($row, array_fill_keys(FinanceAccess::capabilities($request), true))];
    }

    private function actions(object $row, array $permissions): array
    {
        $can = fn (string $permission): bool => isset($permissions[$permission]);
        $actions = [];
        if ($row->status === 'draft' && $can('finance.supplier_invoices.edit')) $actions[] = 'edit';
        if ($row->status === 'draft' && $can('finance.supplier_invoices.post')) $actions[] = 'post';
        if (in_array($row->status, ['posted', 'partially_paid'], true) && $can('finance.supplier_invoices.reverse')) $actions[] = 'reverse';
        return $actions;
    }

    private function serialize(object $row): array
    {
        $remaining = $this->payable->invoiceRemainingCents((int) $row->tenant_id, (int) $row->id);
        $isOverdue = in_array($row->status, ['posted', 'partially_paid'], true) && $remaining > 0 && $row->due_date < now()->toDateString();

        return [
            'id' => (int) $row->id,
            'internalReference' => $row->internal_reference,
            'invoiceNumber' => $row->invoice_number,
            'supplierId' => (int) $row->supplier_id,
            'supplierName' => $row->supplier_name,
            'supplierNumber' => $row->supplier_number,
            'branchId' => $row->branch_id ? (int) $row->branch_id : null,
            'branchName' => $row->branch_name,
            'invoiceDate' => $row->invoice_date,
            'dueDate' => $row->due_date,
            'invoiceType' => $row->invoice_type,
            'expenseCategoryId' => $row->expense_category_id ? (int) $row->expense_category_id : null,
            'expenseCategoryName' => $row->expense_category_name,
            'debitAccountId' => (int) $row->debit_account_id,
            'debitAccountCode' => $row->debit_account_code,
            'debitAccountName' => $row->debit_account_name,
            'subtotal' => Money::decimal(Money::cents($row->subtotal)),
            'taxAmount' => Money::decimal(Money::cents($row->tax_amount)),
            'totalAmount' => Money::decimal(Money::cents($row->total_amount)),
            'remainingAmount' => number_format($remaining / 100, 2, '.', ''),
            'status' => $row->status,
            'isOverdue' => $isOverdue,
            'description' => $row->description,
            'notes' => $row->notes,
            'journalEntryId' => $row->journal_entry_id ? (int) $row->journal_entry_id : null,
            'reversalJournalEntryId' => $row->reversal_journal_entry_id ? (int) $row->reversal_journal_entry_id : null,
            'postedAt' => $row->posted_at,
            'createdAt' => $row->created_at,
        ];
    }
}
