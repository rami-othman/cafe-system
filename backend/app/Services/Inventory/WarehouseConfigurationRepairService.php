<?php

namespace App\Services\Inventory;

use App\Services\FinancialSetupService;
use Illuminate\Support\Facades\DB;

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
            ->orderBy('tenant_id')->orderBy('id')->get(['id', 'tenant_id', 'name']);

        foreach ($branches as $branch) {
            $main = DB::table('warehouses')
                ->where('tenant_id', $branch->tenant_id)
                ->where('branch_id', $branch->id)
                ->where('type', 'branch_main')
                ->whereNull('deleted_at')
                ->orderBy('id')->get(['id', 'code', 'is_active']);

            if ($main->isEmpty()) {
                $findings[] = $this->finding($branch, 'MISSING_BRANCH_MAIN', 'create');
                if ($apply) {
                    $this->setup->ensureBranchMainWarehouse((int) $branch->tenant_id, (int) $branch->id);
                    $fixed++;
                }
                continue;
            }
            if ($main->count() > 1) {
                $findings[] = $this->finding($branch, 'DUPLICATE_BRANCH_MAIN', 'manual_review', ['warehouseIds' => $main->pluck('id')->map(fn ($id) => (int) $id)->all()]);
            }
            if (! (bool) $main->first()->is_active) {
                $findings[] = $this->finding($branch, 'INACTIVE_BRANCH_MAIN', 'activate');
                if ($apply && $main->count() === 1) {
                    DB::table('warehouses')->where('id', $main->first()->id)->update(['is_active' => true, 'updated_at' => now()]);
                    $fixed++;
                }
            }
            $expectedCode = 'BR-'.$branch->id.'-MAIN';
            if ((string) $main->first()->code !== $expectedCode) {
                $findings[] = $this->finding($branch, 'NON_CANONICAL_BRANCH_MAIN_CODE', 'none_required', ['warehouseId' => (int) $main->first()->id, 'actualCode' => $main->first()->code, 'expectedCode' => $expectedCode]);
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
