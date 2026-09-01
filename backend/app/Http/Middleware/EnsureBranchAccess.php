<?php

namespace App\Http\Middleware;

use App\Models\Branch;
use App\Services\BranchAccessService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Applies the centralized branch policy whenever a protected request names a
 * branch explicitly. Controllers additionally authorize branch-derived
 * resources (orders, shifts, receipts, and published versions).
 */
class EnsureBranchAccess
{
    public function __construct(private readonly BranchAccessService $branches) {}

    public function handle(Request $request, Closure $next): Response
    {
        foreach (['branchId', 'branch_id'] as $key) {
            $value = $request->input($key, $request->route($key));
            if ($value !== null && $value !== '' && filter_var($value, FILTER_VALIDATE_INT) !== false) {
                $this->authorizeSameTenantBranch($request, (int) $value);
            }
        }

        foreach (['branchIds', 'branch_ids'] as $key) {
            foreach ((array) $request->input($key, []) as $branchId) {
                if (filter_var($branchId, FILTER_VALIDATE_INT) !== false) {
                    $this->authorizeSameTenantBranch($request, (int) $branchId);
                }
            }
        }

        // Administrative requests can carry branch scopes inside assignment,
        // availability, or publication arrays. Inspect every nested branch
        // field so a caller cannot evade the centralized policy by nesting it.
        foreach (array_unique($this->nestedBranchIds($request->all())) as $branchId) {
            $this->authorizeSameTenantBranch($request, $branchId);
        }

        return $next($request);
    }

    /** @return list<int> */
    private function nestedBranchIds(array $input): array
    {
        $ids = [];
        foreach ($input as $key => $value) {
            if (in_array($key, ['branchId', 'branch_id'], true) && filter_var($value, FILTER_VALIDATE_INT) !== false) {
                $ids[] = (int) $value;
            }
            if (in_array($key, ['branchIds', 'branch_ids'], true) && is_array($value)) {
                foreach ($value as $branchId) {
                    if (filter_var($branchId, FILTER_VALIDATE_INT) !== false) {
                        $ids[] = (int) $branchId;
                    }
                }
            }
            if (is_array($value)) {
                array_push($ids, ...$this->nestedBranchIds($value));
            }
        }

        return $ids;
    }

    private function authorizeSameTenantBranch(Request $request, int $branchId): void
    {
        $user = $request->attributes->get('auth_user');
        $branch = Branch::query()->find($branchId);

        // Let the route's tenant-scoped validation report foreign, archived,
        // or absent IDs uniformly. For a same-tenant branch, this middleware
        // is authoritative: an unassigned user receives 403.
        if ($branch && $user && (int) $branch->tenant_id === (int) $user->tenant_id) {
            $this->branches->authorizeRequestBranch($request, $branchId);
        }
    }
}
