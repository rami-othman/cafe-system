<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SupplierPaymentService;
use App\Support\FinancialActor;
use App\Support\FinanceAccess;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupplierPaymentController extends Controller
{
    public function __construct(private readonly SupplierPaymentService $payments) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $q = $this->rows($tenant);
        if (DB::table('users')->where('tenant_id', $tenant)->where('id', $actor)->value('role') !== 'owner') $q->where(fn ($scope) => $scope->whereIn('p.branch_id', DB::table('user_branches')->where('tenant_id', $tenant)->where('user_id', $actor)->select('branch_id'))->orWhereNull('p.branch_id'));
        foreach (['supplierId' => 'p.supplier_id', 'branchId' => 'p.branch_id', 'status' => 'p.status'] as $input => $column) {
            if ($request->filled($input)) {
                $q->where($column, $request->input($input));
            }
        }

        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        $paginator = $q->orderByDesc('p.payment_date')->orderByDesc('p.id')->paginate($this->perPage($request));
        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row) + ['allowedActions' => $row->status === 'posted' && isset($permissions['finance.supplier_payments.reverse']) ? ['reverse'] : []])->values(), 'meta' => $this->meta($paginator)]);
    }

    public function show(Request $request, int $payment): JsonResponse
    {
        $tenant = TenantContext::id($request);

        return response()->json(['data' => $this->one($tenant, $payment, $request)]);
    }

    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 100), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'branchId' => ['nullable', 'integer'],
            'supplierId' => ['required', 'integer'],
            'paymentDate' => ['required', 'date'],
            'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'paymentMethodId' => ['required', 'integer'],
            'financialLocationId' => ['required', 'integer'],
            'externalReference' => ['nullable', 'string', 'max:120'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'idempotencyKey' => ['required', 'string', 'max:120'],
            'allocations' => ['required', 'array', 'min:1'],
            'allocations.*.invoiceId' => ['required', 'integer'],
            'allocations.*.amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
        ]);
        $tenant = TenantContext::id($request);
        $id = $this->payments->pay($request, $tenant, $data, FinancialActor::id($request, $tenant))->id;

        return response()->json(['data' => $this->one($tenant, $id, $request)], 201);
    }

    public function reverse(Request $request, int $payment): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->payments->reverse($request, $tenant, $payment, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->one($tenant, $payment, $request)]);
    }

    private function rows(int $tenant)
    {
        return DB::table('supplier_payments as p')
            ->join('suppliers as s', 's.id', '=', 'p.supplier_id')
            ->join('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->join('financial_locations as l', 'l.id', '=', 'p.financial_location_id')
            ->leftJoin('branches as b', 'b.id', '=', 'p.branch_id')
            ->where('p.tenant_id', $tenant)
            ->select('p.*', 's.name as supplier_name', 's.supplier_number', 'pm.name as payment_method_name', 'l.name as financial_location_name', 'b.name as branch_name');
    }

    private function one(int $tenant, int $id, Request $request): array
    {
        $row = $this->rows($tenant)->where('p.id', $id)->first();
        abort_unless($row, 404);
        $actor = FinancialActor::id($request, $tenant);
        FinancialActor::assertBranchAccess($actor, $tenant, $row->branch_id ? (int) $row->branch_id : null);

        $allocations = DB::table('payment_allocations as a')
            ->join('supplier_invoices as i', 'i.id', '=', 'a.supplier_invoice_id')
            ->where('a.tenant_id', $tenant)->where('a.supplier_payment_id', $id)
            ->select('a.*', 'i.internal_reference')
            ->get()->map(fn (object $a) => [
                'invoiceId' => (int) $a->supplier_invoice_id,
                'invoiceReference' => $a->internal_reference,
                'amount' => Money::decimal(Money::cents($a->amount)),
            ]);

        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        return $this->serialize($row) + ['allocations' => $allocations->values(), 'allowedActions' => $row->status === 'posted' && isset($permissions['finance.supplier_payments.reverse']) ? ['reverse'] : []];
    }

    private function serialize(object $row): array
    {
        return [
            'id' => (int) $row->id,
            'paymentNumber' => $row->payment_number,
            'supplierId' => (int) $row->supplier_id,
            'supplierName' => $row->supplier_name,
            'supplierNumber' => $row->supplier_number,
            'branchId' => $row->branch_id ? (int) $row->branch_id : null,
            'branchName' => $row->branch_name,
            'paymentDate' => $row->payment_date,
            'amount' => Money::decimal(Money::cents($row->amount)),
            'paymentMethodId' => (int) $row->payment_method_id,
            'paymentMethodName' => $row->payment_method_name,
            'financialLocationId' => (int) $row->financial_location_id,
            'financialLocationName' => $row->financial_location_name,
            'externalReference' => $row->external_reference,
            'notes' => $row->notes,
            'status' => $row->status,
            'journalEntryId' => $row->journal_entry_id ? (int) $row->journal_entry_id : null,
            'reversalJournalEntryId' => $row->reversal_journal_entry_id ? (int) $row->reversal_journal_entry_id : null,
            'createdAt' => $row->created_at,
        ];
    }
}
