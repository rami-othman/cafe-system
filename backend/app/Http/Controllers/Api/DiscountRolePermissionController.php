<?php

namespace App\Http\Controllers\Api;

use App\Domain\Discount\DiscountAccess;
use App\Http\Controllers\Controller;
use App\Services\OperationalAuditService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** Owner-only role configuration; UI work is intentionally outside this phase. */
final class DiscountRolePermissionController extends Controller
{
    public function __construct(private readonly DiscountAccess $access, private readonly OperationalAuditService $audit) {}

    public function show(Request $request, string $role): JsonResponse
    {
        $this->access->assertOwner($request);

        return response()->json(['data' => $this->serialize(TenantContext::id($request), $role)]);
    }

    public function replace(Request $request, string $role): JsonResponse
    {
        $actor = $this->access->assertOwner($request);
        abort_unless(in_array($role, ['manager', 'employee'], true), 422, 'Only manager and employee Discount permissions can be configured.');
        // Employees can use Discounts in POS but never administer them.
        $assignable = $role === 'manager' ? DiscountAccess::ALL_PERMISSIONS : DiscountAccess::EMPLOYEE_ASSIGNABLE;
        $data = $request->validate([
            'permissions' => ['required', 'array'],
            'permissions.*' => ['string', Rule::in($assignable)],
        ]);

        $tenantId = (int) $actor->tenant_id;
        $permissions = array_values(array_unique($data['permissions']));
        $before = $this->serialize($tenantId, $role)['permissions']->all();
        DB::transaction(function () use ($request, $actor, $tenantId, $role, $permissions, $before): void {
            DB::table('discount_role_permissions')->where('tenant_id', $tenantId)->where('role', $role)->delete();
            $now = now();
            foreach ($permissions as $permission) {
                DB::table('discount_role_permissions')->insert([
                    'tenant_id' => $tenantId, 'role' => $role, 'permission' => $permission,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
            }
            $after = $permissions;
            sort($after);
            $this->audit->record($request, $tenantId, 'discount.role_permissions.replaced', 'discount_role', 0,
                ['role' => $role, 'permissions' => $before],
                ['role' => $role, 'permissions' => $after, 'added' => array_values(array_diff($after, $before)), 'removed' => array_values(array_diff($before, $after))],
                actorId: (int) $actor->id);
        });

        return response()->json(['data' => $this->serialize($tenantId, $role)]);
    }

    private function serialize(int $tenantId, string $role): array
    {
        abort_unless(in_array($role, ['manager', 'employee'], true), 422, 'Unknown Discount role.');

        return [
            'role' => $role,
            'permissions' => DB::table('discount_role_permissions')->where('tenant_id', $tenantId)->where('role', $role)->orderBy('permission')->pluck('permission')->values(),
        ];
    }
}
