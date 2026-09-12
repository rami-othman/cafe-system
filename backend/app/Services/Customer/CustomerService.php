<?php

namespace App\Services\Customer;

use App\Domain\Customer\CustomerAccess;
use App\Domain\Customer\CustomerDomainException;
use App\Domain\Customer\CustomerNameNormalizer;
use App\Domain\Customer\CustomerNumberGenerator;
use App\Domain\Customer\CustomerPhoneNormalizer;
use App\Models\Customer;
use App\Models\CustomerGroup;
use App\Services\OperationalAuditService;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CustomerService
{
    public function __construct(private readonly CustomerAccess $access, private readonly CustomerNumberGenerator $numbers, private readonly OperationalAuditService $audit) {}

    public function create(Request $request, array $data): Customer
    {
        $this->access->assertCanAdminister($request);
        if (array_key_exists('groupIds', $data)) {
            $this->access->assertCanManageMemberships($request);
        }
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $data): Customer {
            $name = CustomerNameNormalizer::normalize($data['name']);
            $customer = Customer::query()->create([
                'tenant_id' => $tenantId,
                'name' => $name['displayName'],
                'normalized_name' => $name['normalizedName'],
                'customer_number' => $this->numbers->next($tenantId),
                'email' => $data['email'] ?? null,
                'birth_date' => $data['birthDate'] ?? null,
                'notes' => $data['notes'] ?? null,
                'is_active' => (bool) ($data['isActive'] ?? true),
            ]);
            if (array_key_exists('phones', $data)) {
                $this->replacePhones($tenantId, $customer->id, $data['phones']);
            }
            if (array_key_exists('groupIds', $data)) {
                $this->replaceGroups($request, $tenantId, $customer->id, $data['groupIds']);
            }
            $this->audit->record($request, $tenantId, 'customer.created', 'customer', $customer->id, [], $this->auditState($customer), actorId: $this->access->actor($request)->id);

            return $this->fresh($tenantId, $customer->id);
        });
    }

    public function update(Request $request, int $id, array $data): Customer
    {
        $this->access->assertCanAdminister($request);
        if (array_key_exists('groupIds', $data)) {
            $this->access->assertCanManageMemberships($request);
        }
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $id, $data): Customer {
            $customer = Customer::withTrashed()->where('tenant_id', $tenantId)->whereKey($id)->lockForUpdate()->firstOrFail();
            $before = $this->auditState($customer);
            $updates = [];
            if (array_key_exists('name', $data)) {
                $name = CustomerNameNormalizer::normalize($data['name']);
                $updates['name'] = $name['displayName'];
                $updates['normalized_name'] = $name['normalizedName'];
            }
            foreach (['email' => 'email', 'birthDate' => 'birth_date', 'notes' => 'notes', 'isActive' => 'is_active'] as $input => $column) {
                if (array_key_exists($input, $data)) {
                    $updates[$column] = $data[$input];
                }
            }
            if ($updates !== []) {
                $customer->fill($updates);
                $customer->save();
            }
            if (array_key_exists('phones', $data)) {
                $this->replacePhones($tenantId, $customer->id, $data['phones']);
            }
            if (array_key_exists('groupIds', $data)) {
                $this->replaceGroups($request, $tenantId, $customer->id, $data['groupIds']);
            }
            $this->audit->record($request, $tenantId, 'customer.updated', 'customer', $customer->id, $before, $this->auditState($customer), actorId: $this->access->actor($request)->id);

            return $this->fresh($tenantId, $customer->id);
        });
    }

    public function quickCreate(Request $request, array $data): Customer
    {
        $this->access->assertCanQuickCreate($request);
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $data): Customer {
            $name = CustomerNameNormalizer::normalize($data['name']);
            $phone = CustomerPhoneNormalizer::normalize($data['phone']);
            $customer = Customer::query()->create(['tenant_id' => $tenantId, 'name' => $name['displayName'], 'normalized_name' => $name['normalizedName'], 'customer_number' => $this->numbers->next($tenantId), 'phone' => $phone['rawNumber'], 'is_active' => true]);
            DB::table('customer_phones')->insert(['tenant_id' => $tenantId, 'customer_id' => $customer->id, 'raw_number' => $phone['rawNumber'], 'normalized_number' => $phone['normalizedNumber'], 'type' => 'mobile', 'is_primary' => true, 'validation_status' => $phone['validationStatus'], 'created_at' => now(), 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'customer.quick_create', 'customer', $customer->id, [], $this->auditState($customer), actorId: $this->access->actor($request)->id);

            return $this->fresh($tenantId, $customer->id);
        });
    }

    public function syncGroups(Request $request, int $customerId, array $groupIds): Customer
    {
        $this->access->assertCanManageMemberships($request);
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $customerId, $groupIds): Customer {
            $customer = Customer::withTrashed()->where('tenant_id', $tenantId)->whereKey($customerId)->lockForUpdate()->firstOrFail();
            $this->replaceGroups($request, $tenantId, $customer->id, $groupIds);

            return $this->fresh($tenantId, $customerId);
        });
    }

    public function activate(Request $request, int $id): Customer
    {
        return $this->transition($request, $id, 'activate');
    }

    public function deactivate(Request $request, int $id): Customer
    {
        return $this->transition($request, $id, 'deactivate');
    }

    public function archive(Request $request, int $id): Customer
    {
        return $this->transition($request, $id, 'archive');
    }

    public function restore(Request $request, int $id): Customer
    {
        return $this->transition($request, $id, 'restore');
    }

    private function transition(Request $request, int $id, string $action): Customer
    {
        $this->access->assertCanAdminister($request);
        $tenantId = TenantContext::id($request);

        return DB::transaction(function () use ($request, $tenantId, $id, $action): Customer {
            $customer = Customer::withTrashed()->where('tenant_id', $tenantId)->whereKey($id)->lockForUpdate()->firstOrFail();
            $archived = $customer->trashed();
            $state = $customer->lifecycleState();
            if ($action === 'activate') {
                if ($state === 'active') {
                    return $this->fresh($tenantId, $id);
                }
                if ($archived) {
                    throw CustomerDomainException::invalidTransition();
                }
                $customer->is_active = true;
            } elseif ($action === 'deactivate') {
                if ($state === 'inactive') {
                    return $this->fresh($tenantId, $id);
                }
                if ($archived) {
                    throw CustomerDomainException::invalidTransition();
                }
                $customer->is_active = false;
            } elseif ($action === 'archive') {
                if ($archived) {
                    return $this->fresh($tenantId, $id);
                }
                $customer->is_active = false;
                $customer->save();
                $customer->delete();
            } elseif ($action === 'restore') {
                if (! $archived) {
                    if ($state === 'inactive') {
                        return $this->fresh($tenantId, $id);
                    }
                    throw CustomerDomainException::invalidTransition();
                }
                $customer->restore();
                $customer->is_active = false;
            }
            $customer->save();
            $this->audit->record($request, $tenantId, 'customer.'.$action, 'customer', $id, ['status' => $state], ['status' => $customer->lifecycleState()], actorId: $this->access->actor($request)->id);

            return $this->fresh($tenantId, $id);
        });
    }

    public function findForAdmin(Request $request, int $id): Customer
    {
        $this->access->assertCanAdminister($request);

        return Customer::withTrashed()->where('tenant_id', TenantContext::id($request))->whereKey($id)->with(['phones', 'groups'])->firstOrFail();
    }

    private function fresh(int $tenantId, int $id): Customer
    {
        return Customer::withTrashed()->where('tenant_id', $tenantId)->whereKey($id)->with(['phones', 'groups'])->firstOrFail();
    }

    private function auditState(Customer $customer): array
    {
        return ['customerId' => $customer->id, 'customerNumber' => $customer->customer_number, 'status' => $customer->lifecycleState()];
    }

    private function replaceGroups(Request $request, int $tenantId, int $customerId, array $groupIds): void
    {
        $groupIds = array_values(array_unique(array_map('intval', $groupIds)));
        $groups = CustomerGroup::query()->forTenant($tenantId)->whereIn('id', $groupIds)->where('is_active', true)->whereNull('deleted_at')->lockForUpdate()->get();
        if ($groups->count() !== count($groupIds)) {
            throw ValidationException::withMessages(['groupIds' => 'Every group must be active and belong to the authenticated tenant.']);
        }
        $before = DB::table('customer_group_memberships')->where('tenant_id', $tenantId)->where('customer_id', $customerId)->pluck('customer_group_id')->map(fn ($id) => (int) $id)->sort()->values()->all();
        $activeGroupIds = DB::table('customer_groups')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->pluck('id');
        DB::table('customer_group_memberships')->where('tenant_id', $tenantId)->where('customer_id', $customerId)->whereIn('customer_group_id', $activeGroupIds)->delete();
        foreach ($groupIds as $groupId) {
            DB::table('customer_group_memberships')->insert(['tenant_id' => $tenantId, 'customer_id' => $customerId, 'customer_group_id' => $groupId, 'created_at' => now(), 'updated_at' => now()]);
        }
        $this->audit->record($request, $tenantId, 'customer.memberships.replaced', 'customer', $customerId, ['groupIds' => $before], ['groupIds' => $groupIds], actorId: $this->access->actor($request)->id);
    }

    private function replacePhones(int $tenantId, int $customerId, array $phones): void
    {
        $normalized = [];
        $primaryCount = 0;
        foreach ($phones as $phone) {
            if (trim((string) ($phone['rawNumber'] ?? '')) === '') {
                throw ValidationException::withMessages(['phones' => 'Phone numbers must be non-blank.']);
            }
            $result = CustomerPhoneNormalizer::normalize((string) $phone['rawNumber']);
            if ($result['normalizedNumber'] !== null && in_array($result['normalizedNumber'], $normalized, true)) {
                throw ValidationException::withMessages(['phones' => 'Duplicate normalized phone numbers are not allowed for one customer.']);
            }
            if ($result['normalizedNumber'] !== null) {
                $normalized[] = $result['normalizedNumber'];
            }
            $primaryCount += ! empty($phone['isPrimary']) ? 1 : 0;
        }
        if ($phones !== [] && $primaryCount !== 1) {
            throw ValidationException::withMessages(['phones' => 'Exactly one phone must be primary.']);
        }

        DB::table('customer_phones')->where('tenant_id', $tenantId)->where('customer_id', $customerId)->delete();
        $primaryRaw = null;
        foreach (array_values($phones) as $phone) {
            $result = CustomerPhoneNormalizer::normalize((string) $phone['rawNumber']);
            $isPrimary = ! empty($phone['isPrimary']);
            if ($isPrimary) {
                $primaryRaw = $result['rawNumber'];
            }
            DB::table('customer_phones')->insert(['tenant_id' => $tenantId, 'customer_id' => $customerId, 'raw_number' => $result['rawNumber'], 'normalized_number' => $result['normalizedNumber'], 'type' => $phone['type'] ?? 'mobile', 'is_primary' => $isPrimary, 'validation_status' => $result['validationStatus'], 'created_at' => now(), 'updated_at' => now()]);
        }
        DB::table('customers')->where('tenant_id', $tenantId)->where('id', $customerId)->update(['phone' => $primaryRaw, 'updated_at' => now()]);
    }
}
