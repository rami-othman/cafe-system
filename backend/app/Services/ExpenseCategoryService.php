<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ExpenseCategoryService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function save(Request $request, int $tenantId, array $data, ?int $id, ?int $actorId): int
    {
        $this->assertAccount($tenantId, (int) $data['financialAccountId']);
        return DB::transaction(function () use ($request, $tenantId, $data, $id, $actorId): int {
            $before = $id ? $this->find($tenantId, $id) : null;
            $payload = ['code' => strtoupper($data['code']), 'name' => $data['name'], 'financial_account_id' => (int) $data['financialAccountId'], 'is_active' => (bool) $data['isActive'], 'sort_order' => (int) ($data['sortOrder'] ?? 0), 'updated_by' => $actorId, 'updated_at' => now()];
            if ($id) { DB::table('expense_categories')->where('tenant_id', $tenantId)->where('id', $id)->update($payload); $this->audit->record($request, $tenantId, 'expense_category.updated', 'expense_category', $id, (array) $before, (array) $this->find($tenantId, $id), null, $actorId); return $id; }
            $id = (int) DB::table('expense_categories')->insertGetId($payload + ['tenant_id' => $tenantId, 'created_by' => $actorId, 'created_at' => now()]);
            $this->audit->record($request, $tenantId, 'expense_category.created', 'expense_category', $id, [], (array) $this->find($tenantId, $id), null, $actorId);
            return $id;
        });
    }

    public function status(Request $request, int $tenantId, int $id, bool $active, ?int $actorId): void
    {
        $before = $this->find($tenantId, $id);
        DB::table('expense_categories')->where('tenant_id', $tenantId)->where('id', $id)->update(['is_active' => $active, 'updated_by' => $actorId, 'updated_at' => now()]);
        $this->audit->record($request, $tenantId, $active ? 'expense_category.activated' : 'expense_category.deactivated', 'expense_category', $id, (array) $before, (array) $this->find($tenantId, $id), null, $actorId);
    }

    public function find(int $tenantId, int $id): object
    {
        $row = DB::table('expense_categories')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at')->first();
        abort_unless($row, 404, 'Expense category not found.'); return $row;
    }

    private function assertAccount(int $tenantId, int $id): void
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $id)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $account || ! in_array($account->account_group, ['expense', 'expenses'], true)) throw ValidationException::withMessages(['financialAccountId' => 'Select an active expense financial account from this tenant.']);
    }
}
