<?php

namespace App\Http\Controllers\Api;

use App\Domain\Discount\DiscountAccess;
use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** Owner-only role configuration; UI work is intentionally outside this phase. */
final class DiscountRolePermissionController extends Controller
{
    public function __construct(private readonly DiscountAccess $access) {}

    public function show(Request $request, string $role): JsonResponse
    {
        $this->access->assertOwner($request);

        return response()->json(['data' => $this->serialize(TenantContext::id($request), $role)]);
    }

    public function replace(Request $request, string $role): JsonResponse
    {
        $actor = $this->access->assertOwner($request);
        $data = $request->validate([
            'permissions' => ['required', 'array'],
            'permissions.*' => ['string', Rule::in(DiscountAccess::CATALOG)],
        ]);
        abort_unless(in_array($role, ['manager', 'employee'], true), 422, 'Only manager and employee Discount permissions can be configured.');

        $tenantId = (int) $actor->tenant_id;
        $permissions = array_values(array_unique($data['permissions']));
        DB::transaction(function () use ($tenantId, $role, $permissions): void {
            DB::table('discount_role_permissions')->where('tenant_id', $tenantId)->where('role', $role)->delete();
            $now = now();
            foreach ($permissions as $permission) {
                DB::table('discount_role_permissions')->insert([
                    'tenant_id' => $tenantId, 'role' => $role, 'permission' => $permission,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
            }
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
