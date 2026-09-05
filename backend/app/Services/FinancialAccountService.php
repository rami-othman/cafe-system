<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class FinancialAccountService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        $this->assertParent($tenantId, $data['parentAccountId'] ?? null);

        return DB::transaction(function () use ($request, $tenantId, $data, $actorId): int {
            $now = now();
            $id = (int) DB::table('financial_accounts')->insertGetId($this->payload($data, $actorId) + [
                'tenant_id' => $tenantId,
                'is_system_protected' => false,
                'created_by' => $actorId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $this->audit->record($request, $tenantId, 'financial_account.created', 'financial_account', $id, [], (array) $this->find($tenantId, $id), null, $actorId);

            return $id;
        });
    }

    public function update(Request $request, int $tenantId, int $accountId, array $data, ?int $actorId): void
    {
        $before = $this->find($tenantId, $accountId);
        if ($before->is_system_protected && (strtoupper($data['code']) !== $before->code || $data['accountGroup'] !== $before->account_group || $data['normalBalance'] !== $before->normal_balance)) {
            throw ValidationException::withMessages(['account' => 'System-protected accounts cannot change code, group, or normal balance.']);
        }
        $this->assertParent($tenantId, $data['parentAccountId'] ?? null, $accountId);
        DB::transaction(function () use ($request, $tenantId, $accountId, $data, $actorId, $before): void {
            DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->update($this->payload($data, $actorId) + ['updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'financial_account.updated', 'financial_account', $accountId, (array) $before, (array) $this->find($tenantId, $accountId), null, $actorId);
        });
    }

    public function setStatus(Request $request, int $tenantId, int $accountId, bool $isActive, ?int $actorId): void
    {
        $before = $this->find($tenantId, $accountId);
        if ($before->is_system_protected && ! $isActive) {
            throw ValidationException::withMessages(['isActive' => 'System-protected accounts cannot be deactivated.']);
        }
        DB::transaction(function () use ($request, $tenantId, $accountId, $isActive, $actorId, $before): void {
            DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->update(['is_active' => $isActive, 'updated_by' => $actorId, 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, $isActive ? 'financial_account.activated' : 'financial_account.deactivated', 'financial_account', $accountId, (array) $before, (array) $this->find($tenantId, $accountId), null, $actorId);
        });
    }

    public function find(int $tenantId, int $accountId): object
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->whereNull('deleted_at')->first();
        abort_unless($account, 404, 'Financial account not found.');

        return $account;
    }

    private function assertParent(int $tenantId, mixed $parentId, ?int $accountId = null): void
    {
        if (! $parentId) {
            return;
        }
        if ($accountId && (int) $parentId === $accountId) {
            throw ValidationException::withMessages(['parentAccountId' => 'An account cannot be its own parent.']);
        }
        $parent = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $parentId)->whereNull('deleted_at')->first();
        if (! $parent) {
            throw ValidationException::withMessages(['parentAccountId' => 'The parent account does not belong to this tenant.']);
        }
        if (! $parent->is_active) {
            throw ValidationException::withMessages(['parentAccountId' => 'The parent account must be active.']);
        }

        // Parent links are tenant-local and may be nested. Walk the existing
        // chain before writing so an update cannot create A -> B -> A (or a
        // longer cycle) that would make the chart hierarchy unusable.
        $visited = [];
        $cursor = (int) $parent->id;
        while ($cursor) {
            if (isset($visited[$cursor]) || ($accountId && $cursor === $accountId)) {
                throw ValidationException::withMessages(['parentAccountId' => 'The selected parent would create a circular account hierarchy.']);
            }
            $visited[$cursor] = true;
            $cursor = (int) (DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $cursor)->value('parent_account_id') ?? 0);
        }
    }

    private function payload(array $data, ?int $actorId): array
    {
        return [
            'parent_account_id' => $data['parentAccountId'] ?? null,
            'code' => strtoupper($data['code']),
            'name_ar' => $data['nameAr'],
            'name_en' => $data['nameEn'],
            'account_group' => $data['accountGroup'],
            'normal_balance' => $data['normalBalance'],
            'is_active' => $data['isActive'],
            'updated_by' => $actorId,
        ];
    }
}
