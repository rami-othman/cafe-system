<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SupplierPayableQueryService;
use App\Services\SupplierService;
use App\Support\FinancialActor;
use App\Support\FinanceAccess;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupplierController extends Controller
{
    public function __construct(private readonly SupplierService $suppliers, private readonly SupplierPayableQueryService $payable) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $q = DB::table('suppliers')->where('tenant_id', $tenant)->whereNull('deleted_at');
        if ($request->filled('status')) {
            $q->where('is_active', $request->input('status') === 'active');
        }
        if ($request->filled('search')) {
            $like = '%'.strtolower($request->input('search')).'%';
            $q->where(fn ($x) => $x->whereRaw('LOWER(name) LIKE ?', [$like])->orWhereRaw('LOWER(supplier_number) LIKE ?', [$like]));
        }
        $paginator = $q->orderBy('name')->paginate($this->perPage($request));
        $outstanding = $this->payable->outstandingBySupplier($tenant);

        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        return response()->json(['data' => collect($paginator->items())->map(function (object $row) use ($outstanding, $tenant, $permissions) {
            $lastInvoiceDate = DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('supplier_id', $row->id)->whereNull('deleted_at')->max('invoice_date');

            return $this->serialize($row) + [
                'outstandingBalance' => $outstanding[(int) $row->id] ?? '0.00',
                'overdueBalance' => $this->payable->overdueOutstanding($tenant, (int) $row->id),
                'openInvoiceCount' => $this->payable->openInvoiceCount($tenant, (int) $row->id),
                'lastInvoiceDate' => $lastInvoiceDate,
                'allowedActions' => $this->actions($permissions),
            ];
        })->values(), 'meta' => $this->meta($paginator)]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $id = $this->suppliers->create($request, $tenant, $this->data($request), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->profile($tenant, $id) + ['allowedActions' => $this->actions(array_fill_keys(FinanceAccess::capabilities($request), true))]], 201);
    }

    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 100), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }

    public function update(Request $request, int $supplier): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->suppliers->update($request, $tenant, $supplier, $this->data($request), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->profile($tenant, $supplier) + ['allowedActions' => $this->actions(array_fill_keys(FinanceAccess::capabilities($request), true))]]);
    }

    public function status(Request $request, int $supplier): JsonResponse
    {
        $data = $request->validate(['isActive' => ['required', 'boolean']]);
        $tenant = TenantContext::id($request);
        $this->suppliers->status($request, $tenant, $supplier, $data['isActive'], FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->profile($tenant, $supplier) + ['allowedActions' => $this->actions(array_fill_keys(FinanceAccess::capabilities($request), true))]]);
    }

    public function show(Request $request, int $supplier): JsonResponse
    {
        $tenant = TenantContext::id($request);

        return response()->json(['data' => $this->profile($tenant, $supplier) + ['allowedActions' => $this->actions(array_fill_keys(FinanceAccess::capabilities($request), true))]]);
    }

    public function statement(Request $request, int $supplier): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->suppliers->find($tenant, $supplier);

        $invoices = DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('supplier_id', $supplier)
            ->whereIn('status', ['posted', 'partially_paid', 'paid'])->whereNull('deleted_at')
            ->get(['id', 'internal_reference', 'invoice_number', 'invoice_date as date', 'total_amount as amount']);
        $payments = DB::table('supplier_payments')->where('tenant_id', $tenant)->where('supplier_id', $supplier)
            ->where('status', 'posted')
            ->get(['id', 'payment_number', 'payment_date as date', 'amount']);

        $lines = $invoices->map(fn (object $row) => [
            'id' => (int) $row->id, 'date' => $row->date, 'type' => 'invoice', 'reference' => $row->internal_reference,
            'debit' => '0.00', 'credit' => Money::decimal(Money::cents($row->amount)), 'sortKey' => $row->date.'-1-'.$row->id,
        ])->concat($payments->map(fn (object $row) => [
            'id' => (int) $row->id, 'date' => $row->date, 'type' => 'payment', 'reference' => $row->payment_number,
            'debit' => Money::decimal(Money::cents($row->amount)), 'credit' => '0.00', 'sortKey' => $row->date.'-2-'.$row->id,
        ]))->sortBy('sortKey')->values();

        $running = 0;
        $statement = $lines->map(function (array $line) use (&$running) {
            $running += (float) $line['credit'] - (float) $line['debit'];

            return [...$line, 'runningBalance' => number_format($running, 2, '.', '')];
        })->map(fn (array $line) => collect($line)->except('sortKey')->all());

        return response()->json(['data' => [
            'supplier' => $this->profile($tenant, $supplier),
            'lines' => $statement->values(),
        ]]);
    }

    private function data(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:40'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:500'],
            'contactPerson' => ['nullable', 'string', 'max:255'],
            'taxNumber' => ['nullable', 'string', 'max:60'],
            'paymentTermsDays' => ['nullable', 'integer', 'min:0', 'max:365'],
            'notes' => ['nullable', 'string', 'max:5000'],
        ]);
    }

    private function profile(int $tenant, int $id): array
    {
        $supplier = $this->suppliers->find($tenant, $id);

        return $this->serialize($supplier) + [
            'outstandingBalance' => $this->payable->outstanding($tenant, $id),
            'overdueBalance' => $this->payable->overdueOutstanding($tenant, $id),
            'openInvoiceCount' => $this->payable->openInvoiceCount($tenant, $id),
            'totalInvoiced' => Money::decimal(Money::cents(DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('supplier_id', $id)->whereIn('status', ['posted', 'partially_paid', 'paid'])->sum('total_amount') ?: '0')),
            'totalPaid' => Money::decimal(Money::cents(DB::table('supplier_payments')->where('tenant_id', $tenant)->where('supplier_id', $id)->where('status', 'posted')->sum('amount') ?: '0')),
        ];
    }

    private function serialize(object $row): array
    {
        return [
            'id' => (int) $row->id,
            'supplierNumber' => $row->supplier_number,
            'name' => $row->name,
            'phone' => $row->phone,
            'email' => $row->email,
            'address' => $row->address,
            'contactPerson' => $row->contact_person,
            'taxNumber' => $row->tax_number,
            'paymentTermsDays' => (int) $row->payment_terms_days,
            'notes' => $row->notes,
            'isActive' => (bool) $row->is_active,
        ];
    }
    private function actions(array $permissions): array { return array_values(array_filter(['edit' => isset($permissions['finance.suppliers.manage']) ? 'edit' : null, 'changeStatus' => isset($permissions['finance.suppliers.manage']) ? 'changeStatus' : null])); }
}
