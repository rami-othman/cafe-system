<?php

namespace App\Services\Inventory;

use App\Services\FinancialSetupService;
use Illuminate\Support\Facades\DB;

/**
 * There is no "primary"/"main"/"bar" precedence between a branch's
 * warehouses — a branch is simply a flat set of stock locations. This
 * service only ever flags two operational faults, both mirroring exactly
 * what PosInventoryWarehouseResolver itself requires to resolve a sale:
 * a branch with zero warehouses (POS has nowhere to sell from), and a
 * branch with more than one warehouse but no explicit
 * `pos_inventory_warehouse_id` (POS cannot guess which one to use).
 */
final class WarehouseConfigurationRepairService
{
    public function __construct(private readonly FinancialSetupService $setup) {}

    /** @return array{findings:list<array<string,mixed>>,fixed:int} */
    public function run(bool $apply = false, ?int $tenantId = null): array
    {
        $findings = [];
        $fixed = 0;
        $branches = DB::table('branches')
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->when($tenantId, fn ($query) => $query->where('tenant_id', $tenantId))
            ->orderBy('tenant_id')->orderBy('id')->get(['id', 'tenant_id', 'name', 'pos_inventory_warehouse_id']);

        foreach ($branches as $branch) {
            $warehouses = DB::table('warehouses')
                ->where('tenant_id', $branch->tenant_id)
                ->where('branch_id', $branch->id)
                ->where('is_active', true)
                ->whereNull('deleted_at')
                ->orderBy('id')->get(['id', 'code']);

            if ($warehouses->isEmpty()) {
                $findings[] = $this->finding($branch, 'MISSING_WAREHOUSE', 'create');
                if ($apply) {
                    $this->setup->ensureBranchWarehouse((int) $branch->tenant_id, (int) $branch->id, null);
                    $fixed++;
                }

                continue;
            }

            $configured = $branch->pos_inventory_warehouse_id === null
                ? null
                : $warehouses->firstWhere('id', (int) $branch->pos_inventory_warehouse_id);

            if ($configured === null && $branch->pos_inventory_warehouse_id !== null) {
                $findings[] = $this->finding($branch, 'INVALID_POS_WAREHOUSE_CONFIGURATION', 'manual_review', ['warehouseId' => (int) $branch->pos_inventory_warehouse_id]);
            } elseif ($configured === null && $warehouses->count() > 1) {
                $findings[] = $this->finding($branch, 'AMBIGUOUS_POS_WAREHOUSE', 'manual_review', ['warehouseIds' => $warehouses->pluck('id')->map(fn ($id) => (int) $id)->all()]);
            }
        }

        $invalidLinks = DB::table('warehouses as w')
            ->join('branches as b', 'b.id', '=', 'w.branch_id')
            ->whereColumn('w.tenant_id', '<>', 'b.tenant_id')
            ->when($tenantId, fn ($query) => $query->where('w.tenant_id', $tenantId))
            ->get(['w.id', 'w.tenant_id', 'w.branch_id']);
        foreach ($invalidLinks as $warehouse) {
            $findings[] = ['tenantId' => (int) $warehouse->tenant_id, 'branchId' => (int) $warehouse->branch_id, 'warehouseId' => (int) $warehouse->id, 'code' => 'CROSS_TENANT_BRANCH_LINK', 'action' => 'manual_review'];
        }

        return ['findings' => $findings, 'fixed' => $fixed];
    }

    private function finding(object $branch, string $code, string $action, array $extra = []): array
    {
        return ['tenantId' => (int) $branch->tenant_id, 'branchId' => (int) $branch->id, 'branchName' => $branch->name, 'code' => $code, 'action' => $action] + $extra;
    }
}
