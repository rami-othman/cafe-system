<?php

namespace App\Support;

use Illuminate\Database\Query\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Single authorization boundary for tenant inventory operations.
 *
 * Tenant users currently have the roles seeded by TenantAccessSeeder. Keep the
 * role-to-ability mapping here so controllers do not grow independent checks.
 */
final class InventoryAccess
{
    /** @var array<string, list<string>> */
    private const ROLE_PERMISSIONS = [
        'owner' => ['*'],
        'manager' => [
            'inventory.view',
            'inventory.items.manage',
            'inventory.locations.manage',
            'inventory.transfers.view',
            'inventory.transfers.create',
            'inventory.transfers.edit',
            'inventory.transfers.submit',
            'inventory.transfers.approve',
            'inventory.transfers.dispatch',
            'inventory.transfers.receive',
            'inventory.transfers.cancel',
            'inventory.counts.view',
            'inventory.counts.create',
            'inventory.counts.post',
            'inventory.adjustments.create',
        ],
        // Cashiers can inspect the inventory information relevant to their
        // assigned branch but cannot change stock or its approval workflow.
        'cashier' => [
            'inventory.view',
            'inventory.transfers.view',
            'inventory.counts.view',
        ],
    ];

    public static function authorize(Request $request, string $permission): void
    {
        $actor = self::actor($request);
        $permissions = self::ROLE_PERMISSIONS[$actor->role] ?? [];

        if (! in_array('*', $permissions, true) && ! in_array($permission, $permissions, true)) {
            throw new HttpException(403, 'You do not have permission to perform this inventory action.');
        }
    }

    /** Allows API resources to expose action availability without making the
     * client a security boundary. The middleware still authorizes every call. */
    public static function allows(Request $request, string $permission): bool
    {
        $actor = self::actor($request);
        $permissions = self::ROLE_PERMISSIONS[$actor->role] ?? [];

        return in_array('*', $permissions, true) || in_array($permission, $permissions, true);
    }

    public static function actor(Request $request): object
    {
        $tenantId = (int) $request->attributes->get('tenant_id', 0);
        $authenticated = $request->attributes->get('auth_user');
        $userId = is_array($authenticated) ? (int) ($authenticated['id'] ?? 0) : 0;

        if ($tenantId <= 0 || $userId <= 0) {
            throw new HttpException(401, 'Unauthenticated.');
        }

        $user = DB::table('users')
            ->where('tenant_id', $tenantId)
            ->where('id', $userId)
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->first(['id', 'tenant_id', 'role']);

        if (! $user) {
            throw new HttpException(401, 'Unauthenticated.');
        }

        return $user;
    }

    /**
     * Null means the actor has tenant-wide branch access. An empty array means
     * the actor is not assigned to any branch and must see no branch warehouse.
     * Central (branch-less) warehouses remain accessible to tenant managers.
     *
     * @return list<int>|null
     */
    public static function allowedBranchIds(Request $request): ?array
    {
        $actor = self::actor($request);
        if ($actor->role === 'owner') {
            return null;
        }

        return DB::table('user_branches')
            ->where('tenant_id', $actor->tenant_id)
            ->where('user_id', $actor->id)
            ->pluck('branch_id')
            ->map(fn ($id) => (int) $id)
            ->all();
    }

    public static function scopeWarehouseBranches(Builder $query, Request $request, string $branchColumn): void
    {
        $branchIds = self::allowedBranchIds($request);
        if ($branchIds === null) {
            return;
        }

        $query->where(function (Builder $warehouses) use ($branchColumn, $branchIds): void {
            $warehouses->whereNull($branchColumn);
            if ($branchIds !== []) {
                $warehouses->orWhereIn($branchColumn, $branchIds);
            }
        });
    }

    public static function assertBranchAccess(Request $request, ?int $branchId): void
    {
        $branchIds = self::allowedBranchIds($request);
        if ($branchIds === null || $branchId === null) {
            return;
        }

        if (! in_array($branchId, $branchIds, true)) {
            throw new HttpException(403, 'The selected branch is not assigned to this user.');
        }
    }
}
