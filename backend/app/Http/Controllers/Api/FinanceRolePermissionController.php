<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\OperationalAuditService;
use App\Support\FinanceAccess;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class FinanceRolePermissionController extends Controller
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $roles = DB::table('users')->where('tenant_id', $tenant)->whereNotNull('role')->distinct()->orderBy('role')->pluck('role');
        return response()->json(['data' => $roles->map(fn (string $role) => $this->out($tenant, $role))->values()]);
    }

    public function show(Request $request, string $role): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->assertTenantRole($tenant, $role);
        return response()->json(['data' => $this->out($tenant, $role)]);
    }

    public function replace(Request $request, string $role): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinanceAccess::actor($request);
        if ($actor->effectiveRoleCode() !== 'owner') throw new HttpException(403, 'Only an owner can modify Finance role permissions.');
        $this->assertTenantRole($tenant, $role);
        if ($role === 'owner') throw ValidationException::withMessages(['role' => ['Owner Finance permissions are implicit and cannot be changed.']]);
        $data = $request->validate(['permissions' => ['required', 'array'], 'permissions.*' => ['string']]);
        $permissions = array_values($data['permissions']);
        if (count($permissions) !== count(array_unique($permissions))) throw ValidationException::withMessages(['permissions' => ['Duplicate Finance permissions are not allowed.']]);
        $unknown = array_values(array_diff($permissions, FinanceAccess::CATALOG));
        if ($unknown !== []) throw ValidationException::withMessages(['permissions' => ['Unknown Finance permission: '.$unknown[0]]]);
        $before = $this->permissions($tenant, $role);
        DB::transaction(function () use ($tenant, $role, $permissions): void {
            DB::table('finance_role_permissions')->where('tenant_id', $tenant)->where('role', $role)->delete();
            $now = now(); foreach ($permissions as $permission) DB::table('finance_role_permissions')->insert(['tenant_id' => $tenant, 'role' => $role, 'permission' => $permission, 'created_at' => $now, 'updated_at' => $now]);
        });
        $after = $this->permissions($tenant, $role);
        $this->audit->record($request, $tenant, 'finance_role_permissions.replaced', 'finance_role', 0, ['role' => $role, 'permissions' => $before], ['role' => $role, 'permissions' => $after], null, (int) $actor->id);
        return response()->json(['data' => $this->out($tenant, $role)]);
    }

    private function assertTenantRole(int $tenant, string $role): void { abort_unless(DB::table('users')->where('tenant_id', $tenant)->where('role', $role)->exists(), 404); }
    private function permissions(int $tenant, string $role): array { return DB::table('finance_role_permissions')->where('tenant_id', $tenant)->where('role', $role)->orderBy('permission')->pluck('permission')->values()->all(); }
    private function out(int $tenant, string $role): array { return ['role' => $role, 'permissions' => $role === 'owner' ? FinanceAccess::CATALOG : $this->permissions($tenant, $role)]; }
}
