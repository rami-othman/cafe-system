<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CustomerPaymentService;
use App\Services\CustomerReceivableQueryService;
use App\Services\OperationalAuditService;
use App\Services\SalesInvoicePostAndCollectService;
use App\Support\FinanceAccess;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class CustomerPaymentController extends Controller
{
    public function __construct(
        private readonly CustomerPaymentService $payments,
        private readonly CustomerReceivableQueryService $receivables,
        private readonly SalesInvoicePostAndCollectService $postAndCollect,
        private readonly OperationalAuditService $audit,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $q = $this->rows($tenant)->whereIn('p.branch_id', FinancialActor::operationalBranchIds($actor, $tenant));
        foreach (['customerId' => 'p.customer_id', 'branchId' => 'p.branch_id', 'status' => 'p.status'] as $input => $column) {
            if ($request->filled($input)) {
                $q->where($column, $request->input($input));
            }
        }
        if ($request->filled('from')) $q->whereDate('p.payment_date', '>=', $request->input('from'));
        if ($request->filled('to')) $q->whereDate('p.payment_date', '<=', $request->input('to'));

        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        $paginator = $q->orderByDesc('p.payment_date')->orderByDesc('p.id')->paginate($this->perPage($request));

        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row) + ['allowedActions' => $row->status === 'posted' && isset($permissions['finance.customer_payments.reverse']) ? ['reverse'] : []])->values(), 'meta' => $this->meta($paginator)]);
    }

    public function show(Request $request, int $payment): JsonResponse
    {
        return response()->json(['data' => $this->one(TenantContext::id($request), $payment, $request)]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->data($request);
        $tenant = TenantContext::id($request);
        $id = $this->payments->pay($request, $tenant, $data, FinancialActor::id($request, $tenant))->id;

        return response()->json(['data' => $this->one($tenant, $id, $request)], 201);
    }

    public function preview(Request $request): JsonResponse
    {
        $data = $request->validate([
            'customerId' => ['required', 'integer'],
            'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'paymentMethodId' => ['required', 'integer'],
            'financialLocationId' => ['required', 'integer'],
            'allocations' => ['required', 'array', 'min:1'],
            'allocations.*.invoiceId' => ['required', 'integer'],
            'allocations.*.amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
        ]);
        $tenant = TenantContext::id($request);

        return response()->json(['data' => $this->payments->preview($tenant, $data)]);
    }

    public function reverse(Request $request, int $payment): JsonResponse
    {
        $reason = $request->validate(['reason' => ['nullable', 'string', 'max:500']])['reason'] ?? null;
        $tenant = TenantContext::id($request);
        $this->payments->reverse($request, $tenant, $payment, FinancialActor::id($request, $tenant), $reason);

        return response()->json(['data' => $this->one($tenant, $payment, $request)]);
    }

    /** Immediate-payment UX (§31): one outer request, two separate accounting events. */
    public function postAndCollect(Request $request, int $invoice): JsonResponse
    {
        $data = $request->validate([
            'postIdempotencyKey' => ['required', 'string', 'max:128'],
            'paymentDate' => ['required', 'date'],
            'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'paymentMethodId' => ['required', 'integer'],
            'financialLocationId' => ['required', 'integer'],
            'reference' => ['nullable', 'string', 'max:120'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'paymentIdempotencyKey' => ['required', 'string', 'max:120'],
            'allocations' => ['required', 'array', 'min:1'],
            'allocations.*.invoiceId' => ['required', 'integer'],
            'allocations.*.amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
        ]);
        FinanceAccess::authorize($request, 'finance.customer_payments.create');
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $invoiceRow = DB::table('sales_invoices')->where('tenant_id', $tenant)->where('id', $invoice)->first();
        abort_unless($invoiceRow, 404, 'Sales invoice not found.');
        FinancialActor::assertBranchAccess($actor, $tenant, (int) $invoiceRow->branch_id);

        $result = $this->postAndCollect->postAndCollect($request, $tenant, $invoice, $actor, ['idempotencyKey' => $data['postIdempotencyKey']], [
            'branchId' => (int) $invoiceRow->branch_id, 'customerId' => (int) $invoiceRow->customer_id, 'paymentDate' => $data['paymentDate'], 'amount' => $data['amount'],
            'paymentMethodId' => $data['paymentMethodId'], 'financialLocationId' => $data['financialLocationId'], 'reference' => $data['reference'] ?? null, 'notes' => $data['notes'] ?? null,
            'idempotencyKey' => $data['paymentIdempotencyKey'], 'allocations' => $data['allocations'],
        ]);

        return response()->json(['data' => ['invoiceId' => (int) $result['invoice']->id, 'paymentId' => (int) $result['payment']->id]]);
    }

    /** §33 — minimal customer/AR overview: totalInvoiced, totalPaid, outstanding, no aging suite. Scoped to the actor's accessible branches (§37), never tenant-wide for a branch-limited actor. */
    public function receivablesOverview(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);

        return response()->json(['data' => $this->receivables->customerOverview($tenant, FinancialActor::operationalBranchIds($actor, $tenant))]);
    }

    /** Outstanding posted invoices for one customer — feeds "Register Payment from Customer" (§30) and the invoice-preselected flow (§29). */
    public function customerReceivables(Request $request, int $customer): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $row = DB::table('customers')->where('tenant_id', $tenant)->where('id', $customer)->whereNull('deleted_at')->first();
        abort_unless($row, 404, 'Customer not found.');
        $branchIds = FinancialActor::operationalBranchIds($actor, $tenant);
        $invoices = $this->receivables->openInvoices($tenant, $customer, $branchIds);
        $outstandingCents = array_sum(array_column($invoices, 'remainingCents'));

        return response()->json(['data' => [
            'customer' => ['id' => (int) $row->id, 'name' => $row->name, 'customerNumber' => $row->customer_number],
            'outstanding' => Money::decimal($outstandingCents),
            'openInvoices' => collect($invoices)->map(fn (array $i) => collect($i)->except('remainingCents')->all())->values(),
        ]]);
    }

    private function data(Request $request): array
    {
        return $request->validate([
            'branchId' => ['required', 'integer'],
            'customerId' => ['required', 'integer'],
            'paymentDate' => ['required', 'date'],
            'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'paymentMethodId' => ['required', 'integer'],
            'financialLocationId' => ['required', 'integer'],
            'reference' => ['nullable', 'string', 'max:120'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'idempotencyKey' => ['required', 'string', 'max:120'],
            'allocations' => ['required', 'array', 'min:1'],
            'allocations.*.invoiceId' => ['required', 'integer'],
            'allocations.*.amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
        ]);
    }

    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 100), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }

    private function rows(int $tenant)
    {
        return DB::table('customer_payments as p')
            ->join('customers as c', 'c.id', '=', 'p.customer_id')
            ->join('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->join('financial_locations as l', 'l.id', '=', 'p.financial_location_id')
            ->join('branches as b', 'b.id', '=', 'p.branch_id')
            ->where('p.tenant_id', $tenant)
            ->select('p.*', 'c.name as customer_name', 'c.customer_number', 'pm.name as payment_method_name', 'l.name as financial_location_name', 'b.name as branch_name');
    }

    private function one(int $tenant, int $id, Request $request): array
    {
        $row = $this->rows($tenant)->where('p.id', $id)->first();
        abort_unless($row, 404);
        $actor = FinancialActor::id($request, $tenant);
        FinancialActor::assertBranchAccess($actor, $tenant, (int) $row->branch_id);

        $allocations = DB::table('customer_payment_allocations as a')
            ->join('sales_invoices as i', 'i.id', '=', 'a.sales_invoice_id')
            ->where('a.tenant_id', $tenant)->where('a.customer_payment_id', $id)
            ->select('a.*', 'i.invoice_number')
            ->get()->map(fn (object $a) => [
                'invoiceId' => (int) $a->sales_invoice_id,
                'invoiceNumber' => $a->invoice_number,
                'amount' => Money::decimal(Money::cents($a->amount)),
            ]);

        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);

        return $this->serialize($row) + ['allocations' => $allocations->values(), 'allowedActions' => $row->status === 'posted' && isset($permissions['finance.customer_payments.reverse']) ? ['reverse'] : []];
    }

    private function serialize(object $row): array
    {
        return [
            'id' => (int) $row->id,
            'paymentNumber' => $row->payment_number,
            'customerId' => (int) $row->customer_id,
            'customerName' => $row->customer_name,
            'customerNumber' => $row->customer_number,
            'branchId' => (int) $row->branch_id,
            'branchName' => $row->branch_name,
            'paymentDate' => $row->payment_date,
            'amount' => Money::decimal(Money::cents($row->amount)),
            'paymentMethodId' => (int) $row->payment_method_id,
            'paymentMethodName' => $row->payment_method_name,
            'financialLocationId' => (int) $row->financial_location_id,
            'financialLocationName' => $row->financial_location_name,
            'reference' => $row->external_reference,
            'notes' => $row->notes,
            'status' => $row->status,
            'journalEntryId' => $row->journal_entry_id ? (int) $row->journal_entry_id : null,
            'reversalJournalEntryId' => $row->reversal_journal_entry_id ? (int) $row->reversal_journal_entry_id : null,
            'createdAt' => $row->created_at,
        ];
    }
}
