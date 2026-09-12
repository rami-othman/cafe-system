<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CustomerManagementService;
use App\Services\OperationalAuditService;
use App\Support\FinanceAccess;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class FinanceCustomerController extends Controller
{
    public function __construct(private readonly CustomerManagementService $customers, private readonly OperationalAuditService $audit) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = DB::table('customers')->where('tenant_id', $tenant)->whereNull('deleted_at');
        if ($request->filled('status')) $query->where('is_active', $request->input('status') === 'active');
        if ($request->filled('search')) {
            $like = '%'.strtolower($request->input('search')).'%';
            $query->where(fn ($q) => $q->whereRaw('LOWER(name) LIKE ?', [$like])->orWhereRaw('LOWER(customer_number) LIKE ?', [$like])->orWhereRaw('LOWER(COALESCE(phone, \'\')) LIKE ?', [$like])->orWhereRaw('LOWER(COALESCE(email, \'\')) LIKE ?', [$like]));
        }
        $paginator = $query->orderBy('name')->paginate($this->perPage($request));
        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        return response()->json(['data' => collect($paginator->items())->map(fn (object $customer) => $this->serialize($customer) + ['allowedActions' => $this->actions($permissions)])->values(), 'meta' => $this->meta($paginator)]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant);
        $customer = $this->customers->create($tenant, $actor, $this->data($request, true));
        $this->audit->record($request, $tenant, 'sales.customer.created', 'customer', $customer->id, [], ['name' => $customer->name], null, $actor);
        return response()->json(['data' => $this->serialize($customer) + ['allowedActions' => $this->actions(array_fill_keys(FinanceAccess::capabilities($request), true))]], 201);
    }

    public function show(Request $request, int $customer): JsonResponse { return response()->json(['data' => $this->serialize($this->customers->find(TenantContext::id($request), $customer)) + ['allowedActions' => $this->actions(array_fill_keys(FinanceAccess::capabilities($request), true))]]); }

    public function update(Request $request, int $customer): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant); $before = $this->customers->find($tenant, $customer);
        $after = $this->customers->update($tenant, $customer, $actor, $this->data($request, false));
        $this->audit->record($request, $tenant, 'sales.customer.updated', 'customer', $customer, ['name' => $before->name, 'isActive' => (bool) $before->is_active], ['name' => $after->name, 'isActive' => (bool) $after->is_active], null, $actor);
        return response()->json(['data' => $this->serialize($after) + ['allowedActions' => $this->actions(array_fill_keys(FinanceAccess::capabilities($request), true))]]);
    }

    private function data(Request $request, bool $creating): array
    {
        return $request->validate([
            'name' => [$creating ? 'required' : 'sometimes', 'string', 'max:255'], 'phone' => ['nullable', 'string', 'max:40'], 'email' => ['nullable', 'email', 'max:255'],
            'taxNumber' => ['nullable', 'string', 'max:128'], 'defaultCreditTermsDays' => ['nullable', 'integer', 'min:0', 'max:365'], 'notes' => ['nullable', 'string', 'max:5000'], 'isActive' => ['sometimes', 'boolean'],
        ]);
    }
    private function serialize(object $c): array { return ['id' => (int) $c->id, 'customerNumber' => $c->customer_number, 'name' => $c->name, 'customerType' => $c->customer_type, 'phone' => $c->phone, 'email' => $c->email, 'taxNumber' => $c->tax_number, 'defaultCreditTermsDays' => (int) $c->default_credit_terms_days, 'notes' => $c->notes, 'isActive' => (bool) $c->is_active, 'isWalkIn' => (bool) $c->is_walk_in, 'isSystemProtected' => (bool) $c->is_system_protected]; }
    private function actions(array $p): array { return array_values(array_filter(['edit' => isset($p['finance.customers.edit']) ? 'edit' : null])); }
    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 50), 1), 100); }
    private function meta($p): array { return ['currentPage' => $p->currentPage(), 'perPage' => $p->perPage(), 'total' => $p->total(), 'lastPage' => $p->lastPage()]; }
}
