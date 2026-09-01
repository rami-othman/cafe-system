<?php

namespace App\Services;

use App\Support\FinancialActor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class FinancialLocationService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function save(Request $request, int $tenantId, array $data, ?int $id, ?int $actorId): int
    {
        $this->assertReferences($tenantId, $data, $actorId);
        return DB::transaction(function () use ($request, $tenantId, $data, $id, $actorId): int {
            $before = $id ? $this->find($tenantId, $id) : null;
            $payload = ['branch_id' => $data['branchId'] ?? null, 'financial_account_id' => (int) $data['financialAccountId'], 'code' => strtoupper($data['code']), 'name' => $data['name'], 'kind' => $data['kind'], 'type' => $data['type'], 'bank_name' => $data['bankName'] ?? null, 'masked_reference' => $data['maskedReference'] ?? null, 'is_active' => (bool) $data['isActive'], 'updated_by' => $actorId, 'updated_at' => now()];
            if ($id) {
                DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $id)->update($payload);
                $this->audit->record($request, $tenantId, 'financial_location.updated', 'financial_location', $id, (array) $before, (array) $this->find($tenantId, $id), $data['branchId'] ?? null, $actorId);
                return $id;
            }
            $id = (int) DB::table('financial_locations')->insertGetId($payload + ['tenant_id' => $tenantId, 'created_by' => $actorId, 'created_at' => now()]);
            $this->audit->record($request, $tenantId, 'financial_location.created', 'financial_location', $id, [], (array) $this->find($tenantId, $id), $data['branchId'] ?? null, $actorId);
            return $id;
        });
    }

    public function setStatus(Request $request, int $tenantId, int $id, bool $active, ?int $actorId): void
    {
        $before = $this->find($tenantId, $id);
        DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $id)->update(['is_active' => $active, 'updated_by' => $actorId, 'updated_at' => now()]);
        $this->audit->record($request, $tenantId, $active ? 'financial_location.activated' : 'financial_location.deactivated', 'financial_location', $id, (array) $before, (array) $this->find($tenantId, $id), $before->branch_id, $actorId);
    }

    public function find(int $tenantId, int $id): object
    {
        $row = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $id)->first();
        abort_unless($row, 404, 'Cash or bank account not found.');
        return $row;
    }

    private function assertReferences(int $tenantId, array $data, ?int $actorId): void
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $data['financialAccountId'])->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $account) throw ValidationException::withMessages(['financialAccountId' => 'Select an active financial account from this tenant.']);
        if (! empty($data['branchId'])) {
            if (! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $data['branchId'])->where('is_active', true)->whereNull('deleted_at')->exists()) throw ValidationException::withMessages(['branchId' => 'The branch does not belong to this tenant.']);
            FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $data['branchId']);
        }
        if ($data['kind'] === 'cash' && ! in_array($data['type'], ['cash_drawer', 'main_safe', 'petty_cash'], true)) throw ValidationException::withMessages(['type' => 'Invalid cash account type.']);
        if ($data['kind'] === 'bank' && $data['type'] !== 'bank') throw ValidationException::withMessages(['type' => 'Bank locations must use the bank type.']);
    }
}
