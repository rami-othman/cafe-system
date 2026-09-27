<?php
namespace App\Services;

use App\Support\FactoryWarehouseScope;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class FactoryInventoryWarehouseResolver
{
    public function forBranch(int $tenant, int $branch): object
    {
        $row = DB::table('branches')->where('tenant_id', $tenant)->where('id', $branch)->first();
        FactoryWarehouseScope::assertFactoryBranch($tenant, $branch);
        $id = $row->default_warehouse_id ?? $row->pos_inventory_warehouse_id;
        FactoryWarehouseScope::assertWarehouseForBranch($tenant, $branch, $id ? (int) $id : null);
        $warehouse = DB::table('warehouses')->where('tenant_id', $tenant)->where('id', $id)->first();
        if (! $warehouse) throw ValidationException::withMessages(['warehouseId' => 'مخزن المعمل الافتراضي غير مضبوط.']);
        return $warehouse;
    }
}
