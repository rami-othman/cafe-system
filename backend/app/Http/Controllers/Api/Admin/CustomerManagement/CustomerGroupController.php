<?php

namespace App\Http\Controllers\Api\Admin\CustomerManagement;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\AddCustomerGroupMembersRequest;
use App\Http\Requests\Customer\CustomerGroupRequest;
use App\Http\Requests\Customer\ListCustomerGroupMembersRequest;
use App\Http\Requests\Customer\ListCustomerGroupsRequest;
use App\Http\Resources\Customer\CustomerGroupResource;
use App\Http\Resources\Customer\CustomerManagementResource;
use App\Services\Customer\CustomerGroupService;
use Illuminate\Http\Request;

class CustomerGroupController extends Controller
{
    public function __construct(private readonly CustomerGroupService $groups) {}

    public function index(ListCustomerGroupsRequest $request)
    {
        $page = $this->groups->list($request, $request->validated());

        return response()->json(['data' => CustomerGroupResource::collection($page->getCollection())->resolve(), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }

    public function store(CustomerGroupRequest $request)
    {
        return (new CustomerGroupResource($this->groups->create($request, $request->validated())))->response()->setStatusCode(201);
    }

    public function show(Request $request, int $group): CustomerGroupResource
    {
        return new CustomerGroupResource($this->groups->find($request, $group));
    }

    public function update(CustomerGroupRequest $request, int $group): CustomerGroupResource
    {
        return new CustomerGroupResource($this->groups->update($request, $group, $request->validated()));
    }

    public function archive(Request $request, int $group): CustomerGroupResource
    {
        return new CustomerGroupResource($this->groups->archive($request, $group));
    }

    public function restore(Request $request, int $group): CustomerGroupResource
    {
        return new CustomerGroupResource($this->groups->restore($request, $group));
    }

    public function members(ListCustomerGroupMembersRequest $request, int $group)
    {
        return $this->customerPage($this->groups->members($request, $group, $request->validated()), $request);
    }

    public function eligibleMembers(ListCustomerGroupMembersRequest $request, int $group)
    {
        return $this->customerPage($this->groups->eligibleMembers($request, $group, $request->validated()), $request);
    }

    public function addMembers(AddCustomerGroupMembersRequest $request, int $group): CustomerGroupResource
    {
        return new CustomerGroupResource($this->groups->addMembers($request, $group, $request->validated('customerIds')));
    }

    public function removeMember(Request $request, int $group, int $customer): CustomerGroupResource
    {
        return new CustomerGroupResource($this->groups->removeMember($request, $group, $customer));
    }

    private function customerPage($page, Request $request)
    {
        return response()->json(['data' => $page->getCollection()->map(fn ($customer) => (new CustomerManagementResource($customer))->toArray($request))->values(), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }
}
