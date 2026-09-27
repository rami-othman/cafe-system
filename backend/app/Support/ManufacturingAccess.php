<?php

namespace App\Support;

use App\Models\Branch;
use App\Models\User;
use App\Services\BranchAccessService;
use App\Services\DefaultTenantRoleService;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Single authorization boundary for tenant Manufacturing operations, mirroring
 * InventoryAccess. Keep the role-to-ability mapping here so controllers do not
 * grow independent checks.
 */
final class ManufacturingAccess
{
    /** The full manufacturing permission catalog, granted to the Factory role. */
    public const ALL_PERMISSIONS = [
        'manufacturing.view',
        'manufacturing.recipe.view',
        'manufacturing.recipe.create',
        'manufacturing.recipe.edit',
        'manufacturing.production.create',
        'manufacturing.production.complete',
        'manufacturing.production.reverse',
        'manufacturing.cost.view',
        'manufacturing.reports.view',
        'manufacturing.conversion.create',
    ];

    /**
     * Decision 1 (26/09/2026): production happens in factory branches only.
     * Cafe roles (manager, employee) no longer carry any manufacturing
     * ability — that moved entirely to the independent factory_manager role.
     *
     * @var array<string, list<string>>
     */
    private const ROLE_PERMISSIONS = [
        'owner' => ['*'],
        DefaultTenantRoleService::FACTORY_MANAGER => self::ALL_PERMISSIONS,
        'manager' => [],
        'employee' => [],
    ];

    public static function authorize(Request $request, string $permission): void
    {
        $actor = self::actor($request);
        $permissions = self::ROLE_PERMISSIONS[$actor->effectiveRoleCode()] ?? [];

        if ($permissions === [] || (! in_array('*', $permissions, true) && ! in_array($permission, $permissions, true))) {
            throw new HttpException(403, 'You do not have permission to perform this manufacturing action.');
        }

        // Owner keeps implicit, branch-unrestricted access. Every other role
        // that may reach manufacturing at all (today, only factory_manager)
        // must actually be assigned to a factory branch — otherwise a role
        // grant alone would let an unassigned account reach an endpoint with
        // no branch to operate against.
        if (! $actor->isOwner() && ! self::hasFactoryBranch($actor)) {
            throw new HttpException(403, 'لا يوجد معمل مرتبط بحسابك.');
        }
    }

    public static function allows(Request $request, string $permission): bool
    {
        $actor = self::actor($request);
        $permissions = self::ROLE_PERMISSIONS[$actor->effectiveRoleCode()] ?? [];

        if ($permissions === [] || (! in_array('*', $permissions, true) && ! in_array($permission, $permissions, true))) {
            return false;
        }

        return $actor->isOwner() || self::hasFactoryBranch($actor);
    }

    /** @return list<string> The effective manufacturing permissions for the session payload. */
    public static function capabilities(Request|User $subject): array
    {
        $user = $subject instanceof User ? $subject : self::actor($subject);

        if (! self::hasManufacturingRole($user)) {
            return [];
        }

        if (! $user->isOwner() && ! self::hasFactoryBranch($user)) {
            return [];
        }

        return self::ALL_PERMISSIONS;
    }

    public static function actor(Request $request): User
    {
        $tenantId = (int) $request->attributes->get('tenant_id', 0);
        $authenticated = $request->attributes->get('auth_user');
        $userId = $authenticated instanceof User ? (int) $authenticated->id : 0;

        if ($tenantId <= 0 || $userId <= 0) {
            throw new HttpException(401, 'Unauthenticated.');
        }

        $user = User::query()->with('tenantRole')
            ->where('tenant_id', $tenantId)->where('id', $userId)->where('is_active', true)->first();

        if (! $user) {
            throw new HttpException(401, 'Unauthenticated.');
        }

        return $user;
    }

    private static function hasManufacturingRole(User $user): bool
    {
        $permissions = self::ROLE_PERMISSIONS[$user->effectiveRoleCode()] ?? [];

        return $permissions !== [];
    }

    private static function hasFactoryBranch(User $user): bool
    {
        $branchIds = app(BranchAccessService::class)->accessibleBranchIds($user);
        if ($branchIds === []) {
            return false;
        }

        return Branch::query()->whereIn('id', $branchIds)->where('branch_type', 'factory')->exists();
    }
}
