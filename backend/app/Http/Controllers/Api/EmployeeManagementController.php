<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\EmployeeAdministrationPolicy;
use App\Services\TenantEmployeeService;
use App\Services\UserLifecycleService;
use App\Support\TenantContext;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class EmployeeManagementController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'search' => ['nullable', 'string', 'max:120'],
            'status' => ['nullable', Rule::in(['active', 'deactivated', 'archived'])],
            'role' => ['nullable', Rule::in(['owner', 'manager', 'employee'])],
            'branchId' => ['nullable', 'integer'],
            'page' => ['nullable', 'integer', 'min:1'],
            'perPage' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);
        $tenantId = TenantContext::id($request);
        $query = User::with(['tenantRole', 'branches'])->where('tenant_id', $tenantId);
        match ($data['status'] ?? null) {
            'archived' => $query->onlyTrashed(),
            'deactivated' => $query->whereNull('deleted_at')->where('is_active', false),
            default => $query->whereNull('deleted_at')->when(($data['status'] ?? null) === 'active', fn (Builder $query) => $query->where('is_active', true)),
        };
        if ($data['search'] ?? null) {
            $search = '%'.mb_strtolower($data['search']).'%';
            $query->where(fn (Builder $query) => $query
                ->whereRaw('LOWER(name) LIKE ?', [$search])
                ->orWhereRaw('LOWER(email) LIKE ?', [$search])
                ->orWhereRaw('LOWER(username) LIKE ?', [$search]));
        }
        if ($data['role'] ?? null) {
            $query->whereHas('tenantRole', fn (Builder $query) => $query->where('code', $data['role']));
        }
        if ($data['branchId'] ?? null) {
            $query->whereHas('branches', fn (Builder $query) => $query->where('branches.id', $data['branchId'])->where('branches.tenant_id', $tenantId));
        }
        $page = $query->orderBy('id')->paginate($data['perPage'] ?? 20, ['*'], 'page', $data['page'] ?? 1);

        return response()->json(['data' => collect($page->items())->map(fn (User $user) => $this->resource($user))->values(), 'meta' => [
            'currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total(),
        ]]);
    }

    public function store(Request $request, TenantEmployeeService $employees): JsonResponse
    {
        $user = $employees->create(TenantContext::id($request), $this->creationData($request));

        return response()->json(['data' => $this->resource($user)], 201);
    }

    public function show(Request $request, int $employee): JsonResponse
    {
        return response()->json(['data' => $this->resource($this->findEmployee(TenantContext::id($request), $employee))]);
    }

    public function update(Request $request, int $employee, TenantEmployeeService $employees, EmployeeAdministrationPolicy $policy): JsonResponse
    {
        $target = $this->findEmployee(TenantContext::id($request), $employee);
        $policy->assertCanManageTarget($request->attributes->get('auth_user'), $target);
        $user = $employees->update($target, $this->updateData($request, $target));

        return response()->json(['data' => $this->resource($user)]);
    }

    public function activate(Request $request, int $employee, TenantEmployeeService $employees, EmployeeAdministrationPolicy $policy, UserLifecycleService $lifecycle): JsonResponse
    {
        $target = $this->findEmployee(TenantContext::id($request), $employee);
        $policy->assertCanManageTarget($request->attributes->get('auth_user'), $target);
        $employees->assertCanReactivate($target);
        $lifecycle->reactivate($target);

        return response()->json(['data' => $this->resource($target->fresh(['tenantRole', 'branches']))]);
    }

    public function deactivate(Request $request, int $employee, EmployeeAdministrationPolicy $policy, UserLifecycleService $lifecycle): JsonResponse
    {
        $target = $this->findEmployee(TenantContext::id($request), $employee);
        $policy->assertCanManageTarget($request->attributes->get('auth_user'), $target);
        $lifecycle->deactivate($target);

        return response()->json(['data' => $this->resource($target->fresh(['tenantRole', 'branches']))]);
    }

    public function archive(Request $request, int $employee, EmployeeAdministrationPolicy $policy, UserLifecycleService $lifecycle): JsonResponse
    {
        $target = $this->findEmployee(TenantContext::id($request), $employee);
        $policy->assertCanManageTarget($request->attributes->get('auth_user'), $target);
        $lifecycle->archive($target);

        return response()->json(['data' => $this->resource($target->load(['tenantRole', 'branches']))]);
    }

    public function resetPassword(Request $request, int $employee, TenantEmployeeService $employees, EmployeeAdministrationPolicy $policy): JsonResponse
    {
        $data = $request->validate(['temporaryPassword' => ['required', 'string', 'confirmed']]);
        $target = $this->findEmployee(TenantContext::id($request), $employee);
        $policy->assertCanManageTarget($request->attributes->get('auth_user'), $target);
        $user = $employees->resetPassword($target, $data['temporaryPassword']);

        return response()->json(['data' => $this->resource($user->fresh(['tenantRole', 'branches']))]);
    }

    /** @return array<string, mixed> */
    private function creationData(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            // The current users schema is globally email-unique and non-null.
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')],
            'username' => ['nullable', 'string', 'max:100'],
            'roleId' => ['required', 'integer'],
            'branchIds' => ['required', 'array', 'min:1'],
            'branchIds.*' => ['integer'],
            'temporaryPassword' => ['required', 'string', 'confirmed'],
        ]);
    }

    /** @return array<string, mixed> */
    private function updateData(Request $request, User $target): array
    {
        return $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => ['sometimes', 'required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($target->id)],
            'username' => ['sometimes', 'nullable', 'string', 'max:100'],
            'roleId' => ['sometimes', 'integer'],
            'branchIds' => ['sometimes', 'required', 'array', 'min:1'],
            'branchIds.*' => ['integer'],
            'temporaryPassword' => ['sometimes', 'required', 'string', 'confirmed'],
        ]);
    }

    private function findEmployee(int $tenantId, int $id): User
    {
        $user = User::withTrashed()->with(['tenantRole', 'branches'])->where('tenant_id', $tenantId)->find($id);
        abort_if(! $user, 404, 'Employee not found.');

        return $user;
    }

    /** @return array<string, mixed> */
    private function resource(User $user): array
    {
        $role = $user->tenantRole;

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'username' => $user->username,
            'role' => ['id' => $role?->id, 'code' => $user->effectiveRoleCode(), 'name' => $role?->name ?? ucfirst($user->effectiveRoleCode())],
            'status' => $user->trashed() ? 'archived' : ($user->is_active ? 'active' : 'deactivated'),
            'mustChangePassword' => $user->must_change_password,
            'allBranches' => $user->isOwner(),
            'isProtectedOwner' => $user->isOwner(),
            'assignedBranches' => $user->isOwner() ? [] : $user->branches->map(fn ($branch) => ['id' => $branch->id, 'name' => $branch->name])->values(),
            'createdAt' => $user->created_at?->toIso8601String(),
            'updatedAt' => $user->updated_at?->toIso8601String(),
        ];
    }
}
