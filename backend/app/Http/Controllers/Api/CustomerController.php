<?php

namespace App\Http\Controllers\Api;

use App\Domain\Customer\CustomerAccess;
use App\Domain\Customer\CustomerOperationalEligibility;
use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\QuickCreateCustomerRequest;
use App\Http\Requests\Customer\SyncCustomerGroupsRequest;
use App\Http\Resources\Customer\CustomerManagementResource;
use App\Services\Customer\CustomerService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CustomerController extends Controller
{
    public function __construct(private readonly CustomerAccess $access, private readonly CustomerOperationalEligibility $eligibility, private readonly CustomerService $customers) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->access->assertCanUseOperationalLookup($request);

        $query = $this->eligibility->scope(DB::table('customers'), $tenantId);

        if ($request->filled('search')) {
            $search = '%'.addcslashes((string) $request->query('search'), '%_\\').'%';
            $query->where(fn ($q) => $q->where('name', 'like', $search)->orWhere('phone', 'like', $search));
        }

        $customers = $query->orderBy('name')->limit(30)->get()->map(fn ($customer) => $this->operationalPayload($customer));

        return response()->json(['data' => $customers]);
    }

    public function storeQuick(QuickCreateCustomerRequest $request): JsonResponse
    {
        return (new CustomerManagementResource($this->customers->quickCreate($request, $request->validated())))->response()->setStatusCode(201);
    }

    public function syncGroups(SyncCustomerGroupsRequest $request, int $customer): CustomerManagementResource
    {
        return new CustomerManagementResource($this->customers->syncGroups($request, $customer, $request->validated('groupIds')));
    }

    private function operationalPayload(object $customer): array
    {
        $totalSpent = (float) $customer->total_spent;

        return ['id' => (int) $customer->id, 'name' => $customer->name, 'phone' => $customer->phone, 'email' => $customer->email, 'totalSpent' => $totalSpent, 'visitsCount' => (int) $customer->visits_count, 'loyaltyPoints' => (int) round($totalSpent), 'tier' => match (true) {
            $totalSpent >= 1000 => 'vip', $totalSpent >= 250 => 'regular', default => 'new'
        }];
    }
}
