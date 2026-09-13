<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CustomerCreditQueryService;
use App\Services\CustomerRefundService;
use App\Support\FinanceAccess;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class CustomerRefundController extends Controller
{
    public function __construct(private readonly CustomerRefundService $refunds, private readonly CustomerCreditQueryService $credit) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $q = $this->rows($tenant)->whereIn('r.branch_id', FinancialActor::operationalBranchIds($actor, $tenant));
        foreach (['customerId' => 'r.customer_id', 'branchId' => 'r.branch_id', 'status' => 'r.status'] as $input => $column) {
            if ($request->filled($input)) $q->where($column, $request->input($input));
        }
        $p = $q->orderByDesc('r.refund_date')->orderByDesc('r.id')->paginate($this->perPage($request));

        return response()->json(['data' => collect($p->items())->map(fn (object $row) => $this->serialize($row))->values(), 'meta' => $this->meta($p)]);
    }

    public function show(Request $request, int $refund): JsonResponse
    {
        return response()->json(['data' => $this->one($request, TenantContext::id($request), $refund)]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->data($request);
        $tenant = TenantContext::id($request);
        $id = $this->refunds->pay($request, $tenant, $data, FinancialActor::id($request, $tenant))->id;

        return response()->json(['data' => $this->one($request, $tenant, $id)], 201);
    }

    public function preview(Request $request): JsonResponse
    {
        $data = $request->validate([
            'customerId' => ['required', 'integer'],
            'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'paymentMethodId' => ['required', 'integer'],
            'financialLocationId' => ['required', 'integer'],
        ]);
        $tenant = TenantContext::id($request);

        return response()->json(['data' => $this->refunds->preview($tenant, $data)]);
    }

    /** Available customer credit — feeds the "+ رد مبلغ للعميل" entry point (§35). */
    public function customerCredit(Request $request, int $customer): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $row = DB::table('customers')->where('tenant_id', $tenant)->where('id', $customer)->whereNull('deleted_at')->first();
        abort_unless($row, 404, 'Customer not found.');

        return response()->json(['data' => ['customer' => ['id' => (int) $row->id, 'name' => $row->name], 'availableCredit' => $this->credit->balance($tenant, $customer)]]);
    }

    private function data(Request $request): array
    {
        return $request->validate([
            'branchId' => ['required', 'integer'],
            'customerId' => ['required', 'integer'],
            'refundDate' => ['required', 'date'],
            'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'paymentMethodId' => ['required', 'integer'],
            'financialLocationId' => ['required', 'integer'],
            'reference' => ['nullable', 'string', 'max:120'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'idempotencyKey' => ['required', 'string', 'max:120'],
        ]);
    }

    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 100), 1), 100); }
    private function meta($p): array { return ['currentPage' => $p->currentPage(), 'perPage' => $p->perPage(), 'total' => $p->total(), 'lastPage' => $p->lastPage()]; }

    private function rows(int $tenant)
    {
        return DB::table('customer_refunds as r')
            ->join('customers as c', 'c.id', '=', 'r.customer_id')
            ->join('payment_methods as pm', 'pm.id', '=', 'r.payment_method_id')
            ->join('financial_locations as l', 'l.id', '=', 'r.financial_location_id')
            ->join('branches as b', 'b.id', '=', 'r.branch_id')
            ->where('r.tenant_id', $tenant)
            ->select('r.*', 'c.name as customer_name', 'c.customer_number', 'pm.name as payment_method_name', 'l.name as financial_location_name', 'b.name as branch_name');
    }

    private function one(Request $request, int $tenant, int $id): array
    {
        $row = $this->rows($tenant)->where('r.id', $id)->first();
        abort_unless($row, 404);
        FinancialActor::assertBranchAccess(FinancialActor::id($request, $tenant), $tenant, (int) $row->branch_id);

        return $this->serialize($row);
    }

    private function serialize(object $row): array
    {
        return [
            'id' => (int) $row->id, 'refundNumber' => $row->refund_number, 'customerId' => (int) $row->customer_id, 'customerName' => $row->customer_name,
            'customerNumber' => $row->customer_number, 'branchId' => (int) $row->branch_id, 'branchName' => $row->branch_name,
            'refundDate' => $row->refund_date, 'amount' => Money::decimal(Money::cents($row->amount)),
            'paymentMethodId' => (int) $row->payment_method_id, 'paymentMethodName' => $row->payment_method_name,
            'financialLocationId' => (int) $row->financial_location_id, 'financialLocationName' => $row->financial_location_name,
            'reference' => $row->external_reference, 'notes' => $row->notes, 'status' => $row->status,
            'journalEntryId' => $row->journal_entry_id ? (int) $row->journal_entry_id : null, 'createdAt' => $row->created_at,
        ];
    }
}
