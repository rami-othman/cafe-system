<?php

namespace App\Services\Customer;

use App\Domain\Customer\CustomerAccess;
use App\Domain\Customer\CustomerNameNormalizer;
use App\Domain\Customer\CustomerPhoneNormalizer;
use App\Models\Customer;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CustomerQueryService
{
    public function __construct(private readonly CustomerAccess $access) {}

    public function paginate(Request $request, array $filters)
    {
        $this->access->assertCanAdminister($request);
        $tenantId = TenantContext::id($request);
        $query = Customer::withTrashed()->forTenant($tenantId)->with(['phones', 'groups']);
        $status = $filters['status'] ?? null;
        if ($status === null) {
            $query->whereNull('deleted_at');
        } elseif ($status === 'active') {
            $query->where('is_active', true)->whereNull('deleted_at');
        } elseif ($status === 'inactive') {
            $query->where('is_active', false)->whereNull('deleted_at');
        } elseif ($status === 'archived') {
            $query->whereNotNull('deleted_at');
        }

        if (isset($filters['groupId'])) {
            $groupId = (int) $filters['groupId'];
            if (! DB::table('customer_groups')->where('tenant_id', $tenantId)->where('id', $groupId)->where('is_active', true)->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(['groupId' => 'The group must be active and belong to the authenticated tenant.']);
            }
            $query->whereExists(fn ($subquery) => $subquery->from('customer_group_memberships')->whereColumn('customer_group_memberships.customer_id', 'customers.id')->where('customer_group_memberships.tenant_id', $tenantId)->where('customer_group_memberships.customer_group_id', $groupId));
        }

        if (! empty($filters['search'])) {
            $raw = (string) $filters['search'];
            $escaped = addcslashes($raw, '%_\\');
            $like = '%'.$escaped.'%';
            $normalized = CustomerNameNormalizer::normalize($raw)['normalizedName'];
            $normalizedLike = '%'.addcslashes($normalized, '%_\\').'%';
            $normalizedPhone = CustomerPhoneNormalizer::normalize($raw)['normalizedNumber'];
            $normalizedPhoneLike = $normalizedPhone === null ? null : '%'.addcslashes($normalizedPhone, '%_\\').'%';
            $query->where(function ($searchQuery) use ($like, $normalizedLike, $normalizedPhoneLike, $tenantId): void {
                $searchQuery->where('customers.customer_number', 'like', $like)
                    ->orWhere('customers.name', 'like', $like)
                    ->orWhere('customers.normalized_name', 'like', $normalizedLike)
                    ->orWhere('customers.email', 'like', $like)
                    ->orWhereExists(function ($phoneQuery) use ($like, $normalizedPhoneLike, $tenantId): void {
                        $phoneQuery->from('customer_phones')->whereColumn('customer_phones.customer_id', 'customers.id')->where('customer_phones.tenant_id', $tenantId)->where(function ($q) use ($like, $normalizedPhoneLike): void {
                            $q->where('customer_phones.raw_number', 'like', $like);
                            if ($normalizedPhoneLike !== null) {
                                $q->orWhere('customer_phones.normalized_number', 'like', $normalizedPhoneLike);
                            }
                        });
                    })
                    ->orWhere(function ($legacyQuery) use ($like, $tenantId): void {
                        $legacyQuery->where('customers.phone', 'like', $like)->whereNotExists(fn ($q) => $q->from('customer_phones')->whereColumn('customer_phones.customer_id', 'customers.id')->where('customer_phones.tenant_id', $tenantId));
                    });
            });
        }

        return $query->orderBy('normalized_name')->orderBy('id')->paginate(min(max((int) ($filters['perPage'] ?? 30), 1), 100), ['*'], 'page', max((int) ($filters['page'] ?? 1), 1));
    }
}
