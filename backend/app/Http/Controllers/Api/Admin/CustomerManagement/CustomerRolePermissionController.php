<?php

namespace App\Http\Controllers\Api\Admin\CustomerManagement;

use App\Domain\Customer\CustomerAccess;
use App\Http\Controllers\Controller;
use App\Services\OperationalAuditService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CustomerRolePermissionController extends Controller
{
    public function __construct(private readonly CustomerAccess $access, private readonly OperationalAuditService $audit) {}

    public function show(Request $request): JsonResponse
    {
        $this->access->assertOwnerCanConfigureManagerPermission($request);
        $tenantId = TenantContext::id($request);

        return response()->json(['data' => $this->payload($tenantId)]);
    }

    public function replace(Request $request): JsonResponse
    {
        $this->access->assertOwnerCanConfigureManagerPermission($request);
        $data = $request->validate(['enabled' => ['required', 'boolean']]);
        $tenantId = TenantContext::id($request);
        $actor = $this->access->actor($request);

        DB::transaction(function () use ($request, $tenantId, $actor, $data): void {
            $before = ['enabled' => DB::table('customer_role_permissions')->where('tenant_id', $tenantId)->where('role', 'manager')->where('permission', 'customer.manage')->exists()];
            DB::table('customer_role_permissions')->where('tenant_id', $tenantId)->where('role', 'manager')->where('permission', 'customer.manage')->delete();
            if ($data['enabled']) {
                DB::table('customer_role_permissions')->insert(['tenant_id' => $tenantId, 'role' => 'manager', 'permission' => 'customer.manage', 'created_at' => now(), 'updated_at' => now()]);
            }
            $this->audit->record($request, $tenantId, 'customer.role_permission.replaced', 'customer_role_permission', $actor->id, $before, ['enabled' => (bool) $data['enabled']], actorId: $actor->id);
        });

        return response()->json(['data' => $this->payload($tenantId)]);
    }

    private function payload(int $tenantId): array
    {
        return ['role' => 'manager', 'permission' => 'customer.manage', 'enabled' => DB::table('customer_role_permissions')->where('tenant_id', $tenantId)->where('role', 'manager')->where('permission', 'customer.manage')->exists()];
    }
}
