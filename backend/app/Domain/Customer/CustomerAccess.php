<?php

namespace App\Domain\Customer;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class CustomerAccess
{
    public function actor(Request $request): User
    {
        $tenantId = (int) $request->attributes->get('tenant_id', 0);
        $authenticated = $request->attributes->get('auth_user');
        if ($tenantId < 1 || ! $authenticated instanceof User) {
            throw CustomerDomainException::permissionDenied();
        }

        $actor = User::query()->with('tenantRole')
            ->where('tenant_id', $tenantId)
            ->whereKey($authenticated->id)
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->first();
        if (! $actor) {
            throw CustomerDomainException::permissionDenied();
        }

        return $actor;
    }

    public function assertCanAdminister(Request $request): void
    {
        $actor = $this->actor($request);
        if ($this->allowsUser($actor, 'customer.manage')) {
            return;
        }
        throw CustomerDomainException::permissionDenied();
    }

    public function allowsUser(User $actor, string $permission): bool
    {
        return match ($permission) {
            'customer.manage' => $actor->isOwner() ||
                ($actor->effectiveRoleCode() === 'manager' && $this->managerHasPermission($actor)),
            default => false,
        };
    }

    public function assertCanQuickCreate(Request $request): void
    {
        $this->assertOperationalRole($request);
    }

    public function assertCanManageMemberships(Request $request): void
    {
        $this->assertOperationalRole($request);
    }

    public function assertCanUseOperationalLookup(Request $request): void
    {
        $this->assertOperationalRole($request);
    }

    public function assertOwnerCanConfigureManagerPermission(Request $request): void
    {
        if (! $this->actor($request)->isOwner()) {
            throw CustomerDomainException::permissionDenied();
        }
    }

    public function allows(Request $request, string $permission): bool
    {
        try {
            match ($permission) {
                'customer.manage' => $this->assertCanAdminister($request),
                'customer.quick_create' => $this->assertCanQuickCreate($request),
                'customer.memberships' => $this->assertCanManageMemberships($request),
                'customer.lookup' => $this->assertCanUseOperationalLookup($request),
                'customer.permission' => $this->assertOwnerCanConfigureManagerPermission($request),
                default => throw CustomerDomainException::permissionDenied(),
            };

            return true;
        } catch (CustomerDomainException) {
            return false;
        }
    }

    private function assertOperationalRole(Request $request): void
    {
        $role = $this->actor($request)->effectiveRoleCode();
        if (! in_array($role, ['owner', 'manager', 'employee'], true)) {
            throw CustomerDomainException::permissionDenied();
        }
    }

    private function managerHasPermission(User $actor): bool
    {
        return DB::table('customer_role_permissions')
            ->where('tenant_id', $actor->tenant_id)
            ->where('role', 'manager')
            ->where('permission', 'customer.manage')
            ->exists();
    }
}
