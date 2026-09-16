<?php

namespace App\Services\Customer;

use App\Domain\Customer\CustomerAccess;
use App\Domain\Customer\CustomerNameNormalizer;
use App\Models\Customer;
use App\Models\CustomerGroup;
use App\Services\OperationalAuditService;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CustomerGroupService
{
    public function __construct(private readonly CustomerAccess $access, private readonly OperationalAuditService $audit) {}

    public function list(Request $request, array $filters)
    {
        $this->access->assertCanAdminister($request);
        $tenantId = TenantContext::id($request);
        $query = CustomerGroup::withTrashed()->forTenant($tenantId)->withCount('customers');
        $status = $filters['status'] ?? 'active';
        if ($status === 'active') {
            $query->whereNull('deleted_at')->where('is_active', true);
        } elseif ($status === 'archived') {
            $query->whereNotNull('deleted_at');
        }
        if (filled($filters['search'] ?? null)) {
            $normalized = CustomerNameNormalizer::normalize((string) $filters['search'])['normalizedName'];
            $query->where('normalized_name', 'like', '%'.addcslashes($normalized, '%_\\').'%');
        }

        return $query->orderBy('normalized_name')->orderBy('id')->paginate($this->perPage($filters), ['*'], 'page', $this->page($filters));
    }

    public function create(Request $request, array $data): CustomerGroup
    {
        $this->access->assertCanAdminister($request);
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $data): CustomerGroup {
            $name = CustomerNameNormalizer::normalize($data['name']);
            if (CustomerGroup::withTrashed()->forTenant($tenantId)->where('normalized_name', $name['normalizedName'])->exists()) {
                throw ValidationException::withMessages(['name' => 'A group with this name already exists.']);
            }
            $group = CustomerGroup::create(['tenant_id' => $tenantId, 'name' => $name['displayName'], 'normalized_name' => $name['normalizedName'], 'is_active' => true]);
            $this->audit->record($request, $tenantId, 'customer.group.created', 'customer_group', $group->id, [], ['groupId' => $group->id, 'status' => 'active'], actorId: $this->access->actor($request)->id);

            return $group->fresh();
        });
    }

    public function find(Request $request, int $id): CustomerGroup
    {
        $this->access->assertCanAdminister($request);

        return CustomerGroup::withTrashed()->forTenant(TenantContext::id($request))->whereKey($id)->firstOrFail();
    }

    public function members(Request $request, int $groupId, array $filters)
    {
        $group = $this->find($request, $groupId);

        return $this->customerMembershipQuery($group, $filters)
            ->orderBy('customers.normalized_name')->orderBy('customers.id')
            ->paginate($this->perPage($filters), ['customers.*'], 'page', $this->page($filters));
    }

    public function eligibleMembers(Request $request, int $groupId, array $filters)
    {
        $group = $this->find($request, $groupId);
        if ($group->trashed() || ! $group->is_active) {
            throw ValidationException::withMessages(['group' => 'New members may only be added to an active group.']);
        }
        $tenantId = TenantContext::id($request);
        $query = Customer::query()->forTenant($tenantId)->with(['phones', 'groups'])
            ->where('is_active', true)->whereNull('deleted_at')
            ->whereNotExists(fn ($subquery) => $subquery->from('customer_group_memberships')
                ->whereColumn('customer_group_memberships.customer_id', 'customers.id')
                ->where('customer_group_memberships.tenant_id', $tenantId)
                ->where('customer_group_memberships.customer_group_id', $group->id));

        return $this->applyCustomerSearch($query, $filters['search'] ?? null)
            ->orderBy('customers.normalized_name')->orderBy('customers.id')
            ->paginate($this->perPage($filters), ['customers.*'], 'page', $this->page($filters));
    }

    public function addMembers(Request $request, int $groupId, array $customerIds): CustomerGroup
    {
        $this->access->assertCanAdminister($request);
        $tenantId = TenantContext::id($request);
        $ids = array_values(array_unique(array_map('intval', $customerIds)));

        return DB::transaction(function () use ($request, $tenantId, $groupId, $ids): CustomerGroup {
            $group = CustomerGroup::query()->forTenant($tenantId)->whereKey($groupId)->lockForUpdate()->firstOrFail();
            if (! $group->is_active) {
                throw ValidationException::withMessages(['group' => 'New members may only be added to an active group.']);
            }
            $customers = Customer::withTrashed()->forTenant($tenantId)->whereIn('id', $ids)->lockForUpdate()->get();
            if ($customers->count() !== count($ids) || $customers->contains(fn (Customer $customer): bool => $customer->trashed() || ! $customer->is_active)) {
                throw ValidationException::withMessages(['customerIds' => 'Every customer must be active and belong to the authenticated tenant.']);
            }
            if (DB::table('customer_group_memberships')->where('tenant_id', $tenantId)->where('customer_group_id', $group->id)->whereIn('customer_id', $ids)->exists()) {
                throw ValidationException::withMessages(['customerIds' => 'A submitted customer is already a member of this group.']);
            }
            $now = now();
            DB::table('customer_group_memberships')->insert(array_map(fn (int $id): array => ['tenant_id' => $tenantId, 'customer_id' => $id, 'customer_group_id' => $group->id, 'created_at' => $now, 'updated_at' => $now], $ids));
            $this->audit->record($request, $tenantId, 'customer.group.members_added', 'customer_group', $group->id, [], ['memberCount' => count($ids)], actorId: $this->access->actor($request)->id);

            return $group->fresh()->loadCount('customers');
        });
    }

    public function removeMember(Request $request, int $groupId, int $customerId): CustomerGroup
    {
        $this->access->assertCanAdminister($request);
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $groupId, $customerId): CustomerGroup {
            $group = CustomerGroup::withTrashed()->forTenant($tenantId)->whereKey($groupId)->lockForUpdate()->firstOrFail();
            Customer::withTrashed()->forTenant($tenantId)->whereKey($customerId)->lockForUpdate()->firstOrFail();
            $deleted = DB::table('customer_group_memberships')->where('tenant_id', $tenantId)->where('customer_group_id', $group->id)->where('customer_id', $customerId)->delete();
            if ($deleted !== 1) {
                abort(404);
            }
            $this->audit->record($request, $tenantId, 'customer.group.member_removed', 'customer_group', $group->id, [], ['memberCount' => 1], actorId: $this->access->actor($request)->id);

            return $group->fresh()->loadCount('customers');
        });
    }

    public function update(Request $request, int $id, array $data): CustomerGroup
    {
        $this->access->assertCanAdminister($request);
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $id, $data): CustomerGroup {
            $group = CustomerGroup::withTrashed()->forTenant($tenantId)->whereKey($id)->lockForUpdate()->firstOrFail();
            $name = CustomerNameNormalizer::normalize($data['name']);
            if (CustomerGroup::withTrashed()->forTenant($tenantId)->where('normalized_name', $name['normalizedName'])->where('id', '<>', $id)->exists()) {
                throw ValidationException::withMessages(['name' => 'A group with this name already exists.']);
            }
            $group->update(['name' => $name['displayName'], 'normalized_name' => $name['normalizedName']]);
            $this->audit->record($request, $tenantId, 'customer.group.updated', 'customer_group', $id, [], ['groupId' => $id], actorId: $this->access->actor($request)->id);

            return $group->fresh();
        });
    }

    public function archive(Request $request, int $id): CustomerGroup
    {
        return $this->transition($request, $id, 'archive');
    }

    public function restore(Request $request, int $id): CustomerGroup
    {
        return $this->transition($request, $id, 'restore');
    }

    private function transition(Request $request, int $id, string $action): CustomerGroup
    {
        $this->access->assertCanAdminister($request);
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $id, $action): CustomerGroup {
            $group = CustomerGroup::withTrashed()->forTenant($tenantId)->whereKey($id)->lockForUpdate()->firstOrFail();
            if ($action === 'archive' && $group->trashed()) {
                return $group->fresh();
            }
            if ($action === 'restore' && ! $group->trashed()) {
                return $group->fresh();
            }
            if ($action === 'archive') {
                $group->is_active = false;
                $group->save();
                $group->delete();
            }
            if ($action === 'restore') {
                $group->restore();
                $group->is_active = true;
                $group->save();
            }
            $this->audit->record($request, $tenantId, 'customer.group.'.$action, 'customer_group', $id, [], ['groupId' => $id, 'status' => $group->lifecycleState()], actorId: $this->access->actor($request)->id);

            return $group->fresh();
        });
    }

    private function customerMembershipQuery(CustomerGroup $group, array $filters)
    {
        $tenantId = (int) $group->tenant_id;
        $query = Customer::withTrashed()->forTenant($tenantId)->with(['phones', 'groups'])
            ->whereExists(fn ($subquery) => $subquery->from('customer_group_memberships')
                ->whereColumn('customer_group_memberships.customer_id', 'customers.id')
                ->where('customer_group_memberships.tenant_id', $tenantId)
                ->where('customer_group_memberships.customer_group_id', $group->id));

        return $this->applyCustomerSearch($query, $filters['search'] ?? null);
    }

    private function applyCustomerSearch($query, ?string $search)
    {
        if (! filled($search)) {
            return $query;
        }
        $raw = (string) $search;
        $like = '%'.addcslashes($raw, '%_\\').'%';
        $normalized = CustomerNameNormalizer::normalize($raw)['normalizedName'];
        $normalizedLike = '%'.addcslashes($normalized, '%_\\').'%';

        return $query->where(fn ($q) => $q->where('customers.customer_number', 'like', $like)
            ->orWhere('customers.name', 'like', $like)
            ->orWhere('customers.normalized_name', 'like', $normalizedLike)
            ->orWhere('customers.email', 'like', $like));
    }

    private function perPage(array $filters): int
    {
        return min(max((int) ($filters['perPage'] ?? 30), 1), 100);
    }

    private function page(array $filters): int
    {
        return max((int) ($filters['page'] ?? 1), 1);
    }
}
