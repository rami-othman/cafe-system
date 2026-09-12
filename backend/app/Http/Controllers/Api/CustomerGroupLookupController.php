<?php

namespace App\Http\Controllers\Api;

use App\Domain\Customer\CustomerAccess;
use App\Http\Controllers\Controller;
use App\Models\CustomerGroup;
use App\Support\TenantContext;
use Illuminate\Http\Request;

class CustomerGroupLookupController extends Controller
{
    public function __construct(private readonly CustomerAccess $access) {}

    public function index(Request $request)
    {
        $this->access->assertCanManageMemberships($request);
        $perPage = min(max((int) $request->query('perPage', 30), 1), 100);
        $groups = CustomerGroup::query()->forTenant(TenantContext::id($request))->where('is_active', true)->whereNull('deleted_at')->orderBy('normalized_name')->orderBy('id')->paginate($perPage);

        return response()->json(['data' => $groups->getCollection()->map(fn ($group) => ['id' => (int) $group->id, 'name' => $group->name])->values(), 'meta' => ['currentPage' => $groups->currentPage(), 'lastPage' => $groups->lastPage(), 'perPage' => $groups->perPage(), 'total' => $groups->total()]]);
    }
}
