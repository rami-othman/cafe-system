<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PaymentMethodService
{
    public function __construct(private readonly OperationalAuditService $audit) {}
    public function save(Request $request, int $tenantId, array $data, ?int $id, ?int $actorId): int
    {
        $this->assertReferences($tenantId, $data);
        return DB::transaction(function () use ($request, $tenantId, $data, $id, $actorId): int {
            $before = $id ? $this->find($tenantId, $id) : null;
            $payload = ['code' => strtoupper($data['code']), 'name' => $data['name'], 'type' => $data['type'], 'financial_account_id' => (int) $data['financialAccountId'], 'financial_location_id' => $data['financialLocationId'] ?? null, 'is_active' => (bool) $data['isActive'], 'sort_order' => (int) ($data['sortOrder'] ?? 0), 'updated_by' => $actorId, 'updated_at' => now()];
            if ($id) { DB::table('payment_methods')->where('tenant_id', $tenantId)->where('id', $id)->update($payload); $this->audit->record($request, $tenantId, 'payment_method.updated', 'payment_method', $id, (array) $before, (array) $this->find($tenantId, $id), null, $actorId); return $id; }
            $id = (int) DB::table('payment_methods')->insertGetId($payload + ['tenant_id' => $tenantId, 'created_by' => $actorId, 'created_at' => now()]);
            $this->audit->record($request, $tenantId, 'payment_method.created', 'payment_method', $id, [], (array) $this->find($tenantId, $id), null, $actorId); return $id;
        });
    }
    public function status(Request $request, int $tenantId, int $id, bool $active, ?int $actorId): void { $before = $this->find($tenantId, $id); DB::table('payment_methods')->where('tenant_id', $tenantId)->where('id', $id)->update(['is_active' => $active, 'updated_by' => $actorId, 'updated_at' => now()]); $this->audit->record($request, $tenantId, $active ? 'payment_method.activated' : 'payment_method.deactivated', 'payment_method', $id, (array) $before, (array) $this->find($tenantId, $id), null, $actorId); }
    public function find(int $tenantId, int $id): object { $row = DB::table('payment_methods')->where('tenant_id', $tenantId)->where('id', $id)->first(); abort_unless($row, 404, 'Payment method not found.'); return $row; }
    private function assertReferences(int $tenantId, array $data): void { if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $data['financialAccountId'])->where('is_active', true)->whereNull('deleted_at')->exists()) throw ValidationException::withMessages(['financialAccountId' => 'Select an active financial account from this tenant.']); if (! empty($data['financialLocationId'])) { $location = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $data['financialLocationId'])->where('is_active', true)->first(); if (! $location || (int) $location->financial_account_id !== (int) $data['financialAccountId']) throw ValidationException::withMessages(['financialLocationId' => 'The selected active cash or bank account must map to the same ledger account.']); } }
}
