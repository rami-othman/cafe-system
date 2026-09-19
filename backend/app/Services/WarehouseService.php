<?php

namespace App\Services;

use App\Support\FinancialActor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class WarehouseService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        $this->assertBranchRules($tenantId, $data, $actorId);

        return DB::transaction(function () use ($request, $tenantId, $data, $actorId): int {
            $now = now();
            $id = (int) DB::table('warehouses')->insertGetId($this->payload($data, $actorId) + [
                'tenant_id' => $tenantId,
                'created_by' => $actorId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $warehouse = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'warehouse.created', 'warehouse', $id, [], (array) $warehouse, $warehouse->branch_id, $actorId);

            return $id;
        });
    }

    public function update(Request $request, int $tenantId, int $warehouseId, array $data, ?int $actorId): void
    {
        $before = $this->find($tenantId, $warehouseId);
        $this->assertBranchRules($tenantId, $data, $actorId);
        DB::transaction(function () use ($request, $tenantId, $warehouseId, $data, $actorId, $before): void {
            DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->update($this->payload($data, $actorId) + ['updated_at' => now()]);
            $after = $this->find($tenantId, $warehouseId);
            $this->audit->record($request, $tenantId, 'warehouse.updated', 'warehouse', $warehouseId, (array) $before, (array) $after, $after->branch_id, $actorId);
        });
    }

    public function setStatus(Request $request, int $tenantId, int $warehouseId, bool $isActive, ?int $actorId): void
    {
        $before = $this->find($tenantId, $warehouseId);
        DB::transaction(function () use ($request, $tenantId, $warehouseId, $isActive, $actorId, $before): void {
            DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->update(['is_active' => $isActive, 'updated_by' => $actorId, 'updated_at' => now()]);
            $after = $this->find($tenantId, $warehouseId);
            $this->audit->record($request, $tenantId, $isActive ? 'warehouse.activated' : 'warehouse.deactivated', 'warehouse', $warehouseId, (array) $before, (array) $after, $after->branch_id, $actorId);
        });
    }

    public function find(int $tenantId, int $warehouseId): object
    {
        $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->whereNull('deleted_at')->first();
        abort_unless($warehouse, 404, 'Warehouse not found.');

        return $warehouse;
    }

    private function assertBranchRules(int $tenantId, array $data, ?int $actorId): void
    {
        $branchId = isset($data['branchId']) ? (int) $data['branchId'] : null;
        if (! $branchId) {
            throw ValidationException::withMessages(['branchId' => 'يجب تحديد فرع لهذا المخزن.']);
        }
        if (! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages(['branchId' => 'الفرع المحدد لا يتبع لهذه المنشأة.']);
        }
        FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId);
    }

    private function payload(array $data, ?int $actorId): array
    {
        return [
            'branch_id' => (int) $data['branchId'],
            'name' => $data['name'],
            'code' => strtoupper($data['code']),
            'type' => $data['type'],
            'is_active' => $data['isActive'],
            'notes' => $data['notes'] ?? null,
            'updated_by' => $actorId,
        ];
    }
}
