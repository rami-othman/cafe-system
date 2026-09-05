<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\OperationalAuditService;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

final class FinanceApprovalRuleController extends Controller
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        return response()->json(['data' => DB::table('finance_approval_rules')->where('tenant_id', $tenant)->orderBy('action_type')->orderBy('role')->orderByRaw('branch_id IS NULL')->get()->map(fn (object $rule) => $this->out($rule))->values()]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant); $data = $this->data($request);
        $this->assertBranch($tenant, $data['branchId'] ?? null);
        $this->assertNoActiveConflict($tenant, $data['actionType'], $data['role'], $data['branchId'] ?? null, (bool) ($data['isActive'] ?? true));
        $id = (int) DB::table('finance_approval_rules')->insertGetId($this->values($tenant, $data) + ['created_at' => now(), 'updated_at' => now()]);
        $row = DB::table('finance_approval_rules')->where('tenant_id', $tenant)->where('id', $id)->first();
        $this->audit->record($request, $tenant, 'finance_approval_rule.created', 'finance_approval_rule', $id, [], (array) $row, $row->branch_id, $actor);
        return response()->json(['data' => $this->out($row)], 201);
    }

    public function update(Request $request, int $rule): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant);
        $old = DB::table('finance_approval_rules')->where('tenant_id', $tenant)->where('id', $rule)->first(); abort_unless($old, 404);
        $data = $this->data($request, true);
        $effective = ['actionType' => $data['actionType'] ?? $old->action_type, 'role' => $data['role'] ?? $old->role, 'branchId' => array_key_exists('branchId', $data) ? $data['branchId'] : $old->branch_id, 'maxAmount' => array_key_exists('maxAmount', $data) ? $data['maxAmount'] : $old->max_amount, 'isActive' => $data['isActive'] ?? (bool) $old->is_active];
        $this->assertBranch($tenant, $effective['branchId']);
        $this->assertNoActiveConflict($tenant, $effective['actionType'], $effective['role'], $effective['branchId'], (bool) $effective['isActive'], $rule);
        DB::table('finance_approval_rules')->where('tenant_id', $tenant)->where('id', $rule)->update($this->values($tenant, $effective) + ['updated_at' => now()]);
        $row = DB::table('finance_approval_rules')->where('tenant_id', $tenant)->where('id', $rule)->first();
        $this->audit->record($request, $tenant, 'finance_approval_rule.updated', 'finance_approval_rule', $rule, (array) $old, (array) $row, $row->branch_id, $actor);
        return response()->json(['data' => $this->out($row)]);
    }

    private function data(Request $request, bool $partial = false): array { return $request->validate(['actionType' => [$partial ? 'sometimes' : 'required', Rule::in(['expense_approve'])], 'role' => [$partial ? 'sometimes' : 'required', 'string', 'max:40'], 'branchId' => ['sometimes', 'nullable', 'integer'], 'maxAmount' => ['sometimes', 'nullable', 'regex:/^\d+(\.\d{1,2})?$/'], 'isActive' => ['sometimes', 'boolean']]); }
    private function assertBranch(int $tenant, mixed $branch): void { if ($branch !== null) abort_unless(DB::table('branches')->where('tenant_id', $tenant)->where('id', $branch)->exists(), 422, 'Invalid branch.'); }
    private function assertNoActiveConflict(int $tenant, string $actionType, string $role, mixed $branch, bool $active, ?int $except = null): void { if (! $active) return; $query = DB::table('finance_approval_rules')->where('tenant_id', $tenant)->where('action_type', $actionType)->where('role', $role)->where('is_active', true); $branch === null ? $query->whereNull('branch_id') : $query->where('branch_id', $branch); if ($except) $query->where('id', '<>', $except); if ($query->exists()) throw ValidationException::withMessages(['approvalRule' => ['An active rule already exists for this action, role, and branch scope.']]); }
    private function values(int $tenant, array $data): array { return ['tenant_id' => $tenant, 'action_type' => $data['actionType'], 'role' => $data['role'], 'branch_id' => $data['branchId'] ?? null, 'max_amount' => array_key_exists('maxAmount', $data) && $data['maxAmount'] !== null ? Money::decimal(Money::cents($data['maxAmount'])) : null, 'is_active' => $data['isActive'] ?? true]; }
    private function out(object $rule): array { return ['id' => (int) $rule->id, 'actionType' => $rule->action_type, 'role' => $rule->role, 'branchId' => $rule->branch_id ? (int) $rule->branch_id : null, 'maxAmount' => $rule->max_amount, 'isActive' => (bool) $rule->is_active]; }
}
