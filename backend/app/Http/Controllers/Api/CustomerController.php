<?php

namespace App\Http\Controllers\Api;

use App\Domain\Customer\CustomerAccess;
use App\Domain\Customer\CustomerOperationalEligibility;
use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\QuickCreateCustomerRequest;
use App\Http\Requests\Customer\SyncCustomerGroupsRequest;
use App\Http\Resources\Customer\CustomerManagementResource;
use App\Services\Customer\CustomerService;
use App\Support\Search\SmartSearch;
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

        $search = $request->query('search');
        $searchFields = [
            ['column' => 'name', 'weight' => 3],
            ['column' => 'phone', 'weight' => 2, 'type' => 'phone'],
        ];
        // Unfiltered load is a quick-pick default list (kept small); an active
        // search runs against the full authorized customer table before this
        // cap, ranked by relevance, so results beyond the default 30 are
        // still reachable by typing rather than only by scrolling.
        $limit = 30;
        if ($request->filled('search')) {
            SmartSearch::apply($query, $search, $searchFields);
            SmartSearch::withRelevance($query, $search, $searchFields);
            $query->orderByDesc('smart_rank');
            $limit = 50;
        }

        $customers = $query->orderBy('name')->limit($limit)->get()->map(fn ($customer) => $this->operationalPayload($customer));

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
