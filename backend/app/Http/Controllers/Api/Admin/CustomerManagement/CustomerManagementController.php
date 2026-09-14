<?php

namespace App\Http\Controllers\Api\Admin\CustomerManagement;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\ListCustomersRequest;
use App\Http\Requests\Customer\ListCustomerOrdersRequest;
use App\Http\Requests\Customer\StoreCustomerRequest;
use App\Http\Requests\Customer\UpdateCustomerRequest;
use App\Http\Resources\Customer\CustomerManagementResource;
use App\Services\Customer\CustomerQueryService;
use App\Services\Customer\CustomerOrderHistoryQueryService;
use App\Services\Customer\CustomerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerManagementController extends Controller
{
    public function __construct(private readonly CustomerService $customers, private readonly CustomerQueryService $queryService, private readonly CustomerOrderHistoryQueryService $orders) {}

    public function index(ListCustomersRequest $request): JsonResponse
    {
        $page = $this->queryService->paginate($request, $request->validated());

        return response()->json(['data' => $page->getCollection()->map(fn ($customer) => (new CustomerManagementResource($customer))->toArray($request))->values(), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }

    public function store(StoreCustomerRequest $request): JsonResponse
    {
        return (new CustomerManagementResource($this->customers->create($request, $request->validated())))->response()->setStatusCode(201);
    }

    public function show(Request $request, int $customer): CustomerManagementResource
    {
        return new CustomerManagementResource($this->customers->findForAdmin($request, $customer));
    }

    public function overview(Request $request, int $customer): JsonResponse
    {
        $record = $this->customers->findForAdmin($request, $customer);
        $overview = $this->orders->overview($request, $record->id);

        return response()->json(['data' => [
            'customer' => (new CustomerManagementResource($record))->resolve($request),
            ...$overview,
        ]]);
    }

    public function orders(ListCustomerOrdersRequest $request, int $customer): JsonResponse
    {
        $page = $this->orders->paginate($request, $customer, $request->validated());
        return response()->json(['data' => $page->getCollection()->map(fn ($order) => $this->orders->serialize($order))->values(), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }

    public function update(UpdateCustomerRequest $request, int $customer): CustomerManagementResource
    {
        return new CustomerManagementResource($this->customers->update($request, $customer, $request->validated()));
    }

    public function activate(Request $request, int $customer): CustomerManagementResource
    {
        return new CustomerManagementResource($this->customers->activate($request, $customer));
    }

    public function deactivate(Request $request, int $customer): CustomerManagementResource
    {
        return new CustomerManagementResource($this->customers->deactivate($request, $customer));
    }

    public function archive(Request $request, int $customer): CustomerManagementResource
    {
        return new CustomerManagementResource($this->customers->archive($request, $customer));
    }

    public function restore(Request $request, int $customer): CustomerManagementResource
    {
        return new CustomerManagementResource($this->customers->restore($request, $customer));
    }
}
