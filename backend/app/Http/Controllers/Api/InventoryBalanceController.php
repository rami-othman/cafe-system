<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use App\Support\WarehousePresentation;
use Carbon\Carbon;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryBalanceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = DB::table('stock_balances as balances')->join('inventory_items as items', 'items.id', '=', 'balances.inventory_item_id')->join('warehouses as warehouses', 'warehouses.id', '=', 'balances.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('balances.tenant_id', $tenant)->where('items.is_active', true)->whereNull('items.deleted_at')->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%')->select('balances.*', 'items.name_ar', 'items.name_en', 'items.sku', 'items.unit', 'items.minimum_stock', 'items.reorder_level', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name');
        if ($request->filled('warehouseId')) {
            $query->where('balances.warehouse_id', $request->query('warehouseId'));
        }
        if ($request->filled('search')) {
            $like = '%'.strtolower($request->query('search')).'%';
            $query->where(fn (Builder $q) => $q->whereRaw('LOWER(items.name_ar) LIKE ?', [$like])->orWhereRaw('LOWER(items.name_en) LIKE ?', [$like])->orWhereRaw('LOWER(items.sku) LIKE ?', [$like]));
        }
        if ($request->query('lowStock') === 'true') {
            $query->whereRaw('balances.quantity_on_hand <= items.reorder_level');
        }
        if ($request->query('outOfStock') === 'true') {
            $query->where('balances.quantity_on_hand', '<=', 0);
        }
        $paginator = $query->orderBy('items.name_ar')->paginate(min(max((int) $request->query('perPage', 50), 1), 100));

        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row))->values(), 'meta' => ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]]);
    }

    public function dashboard(Request $request): JsonResponse
    {
        if (in_array($request->query('compare_previous'), ['true', 'false'], true)) {
            $request->merge(['compare_previous' => $request->query('compare_previous') === 'true']);
        }

        $tenant = TenantContext::id($request);
        $filters = $request->validate([
            'branch_id' => ['nullable', 'integer'],
            'warehouse_id' => ['nullable', 'integer'],
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:from'],
            'search' => ['nullable', 'string', 'max:120'],
            'compare_previous' => ['nullable', 'boolean'],
            // Existing clients use these names. Keep them while the dashboard
            // moves to the documented snake_case contract.
            'warehouseId' => ['nullable', 'integer'],
        ]);
        $branchId = isset($filters['branch_id']) ? (int) $filters['branch_id'] : null;
        $warehouseId = isset($filters['warehouse_id']) ? (int) $filters['warehouse_id'] : (isset($filters['warehouseId']) ? (int) $filters['warehouseId'] : null);
        if ($branchId && ! DB::table('branches')->where('tenant_id', $tenant)->where('id', $branchId)->whereNull('deleted_at')->exists()) {
            abort(422, 'The selected branch does not belong to this tenant.');
        }
        if ($warehouseId && ! DB::table('warehouses')->where('tenant_id', $tenant)->where('id', $warehouseId)->where('is_active', true)->whereNull('deleted_at')->where('code', 'not like', 'LEGACY-%')->exists()) {
            abort(422, 'The selected warehouse is not available.');
        }
        if ($warehouseId && $branchId && ! DB::table('warehouses')->where('tenant_id', $tenant)->where('id', $warehouseId)->where('branch_id', $branchId)->exists()) {
            abort(422, 'The selected warehouse does not belong to the selected branch.');
        }
        $from = $filters['from'] ?? now()->startOfMonth()->toDateString();
        $to = $filters['to'] ?? now()->toDateString();
        $periodDays = max(1, Carbon::parse($from)->diffInDays(Carbon::parse($to)) + 1);
        $previousTo = Carbon::parse($from)->subDay()->toDateString();
        $previousFrom = Carbon::parse($previousTo)->subDays($periodDays - 1)->toDateString();
        $base = DB::table('stock_balances as balances')->join('inventory_items as items', 'items.id', '=', 'balances.inventory_item_id')->join('warehouses as warehouses', 'warehouses.id', '=', 'balances.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('balances.tenant_id', $tenant)->where('items.is_active', true)->whereNull('items.deleted_at')->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%');
        if ($branchId) {
            $base->where('warehouses.branch_id', $branchId);
        }
        if ($warehouseId) {
            $base->where('balances.warehouse_id', $warehouseId);
        }
        if (! empty($filters['search'])) {
            $like = '%'.strtolower($filters['search']).'%';
            $base->where(fn (Builder $query) => $query->whereRaw('LOWER(items.name_en) LIKE ?', [$like])->orWhereRaw('LOWER(items.name_ar) LIKE ?', [$like])->orWhereRaw('LOWER(items.sku) LIKE ?', [$like]));
        }
        $rows = $base->get(['balances.*', 'items.name_en', 'items.name_ar', 'items.sku', 'items.unit', 'items.reorder_level', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name']);
        $movementScope = function (Builder $query) use ($tenant, $branchId, $warehouseId, $filters): void {
            $query->where('movements.tenant_id', $tenant)->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%');
            if ($branchId) $query->where('warehouses.branch_id', $branchId);
            if ($warehouseId) $query->where('movements.warehouse_id', $warehouseId);
            if (! empty($filters['search'])) {
                $like = '%'.strtolower($filters['search']).'%';
                $query->where(fn (Builder $search) => $search->whereRaw('LOWER(items.name_en) LIKE ?', [$like])->orWhereRaw('LOWER(items.name_ar) LIKE ?', [$like])->orWhereRaw('LOWER(items.sku) LIKE ?', [$like]));
            }
        };
        $movementQuery = fn () => DB::table('stock_movements as movements')->join('inventory_items as items', 'items.id', '=', 'movements.inventory_item_id')->join('warehouses as warehouses', 'warehouses.id', '=', 'movements.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id');
        $wasteValue = function (string $start, string $end) use ($movementQuery, $movementScope): float {
            $query = $movementQuery(); $movementScope($query);
            return round((float) $query->where('movements.type', 'waste')->whereBetween(DB::raw('DATE(movements.occurred_at)'), [$start, $end])->sum('movements.total_cost'), 2);
        };
        $waste = $wasteValue($from, $to);
        $previousWaste = (bool) ($filters['compare_previous'] ?? true) ? $wasteValue($previousFrom, $previousTo) : null;

        $warehouseValues = $rows->groupBy('warehouse_id')->map(fn ($group, $id) => ['warehouseId' => (int) $id, 'warehouseName' => WarehousePresentation::displayName($group->first()->branch_name, $group->first()->warehouse_type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($group->first()->warehouse_type), 'value' => number_format($group->sum(fn (object $row) => (float) $row->quantity_on_hand * (float) $row->average_unit_cost), 2, '.', '')])->sortByDesc('value')->values();
        $alerts = $rows->filter(fn (object $row) => (float) $row->quantity_on_hand <= (float) $row->reorder_level)->sortBy(fn (object $row) => (float) $row->quantity_on_hand <= 0 ? -1000000 : ((float) $row->quantity_on_hand / max((float) $row->reorder_level, 0.001)))->unique('inventory_item_id')->take(4)->map(fn (object $row) => ['itemId' => (int) $row->inventory_item_id, 'itemName' => $row->name_en ?: $row->sku, 'warehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'quantity' => number_format((float) $row->quantity_on_hand, 3, '.', ''), 'unit' => $row->unit, 'outOfStock' => (float) $row->quantity_on_hand <= 0])->values();
        $recentQuery = $movementQuery(); $movementScope($recentQuery);
        $recent = $recentQuery->whereBetween(DB::raw('DATE(movements.occurred_at)'), [$from, $to])->orderByDesc('movements.occurred_at')->orderByDesc('movements.id')->limit(10)->get(['movements.*', 'items.name_en', 'items.sku', 'items.unit', 'warehouses.type as warehouse_type', 'branches.name as branch_name'])->map(fn (object $row) => ['id' => (int) $row->id, 'itemId' => (int) $row->inventory_item_id, 'itemNameEn' => $row->name_en ?: $row->sku, 'warehouseId' => (int) $row->warehouse_id, 'warehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($row->warehouse_type), 'unit' => $row->unit, 'type' => $row->type, 'quantityIn' => $row->quantity_in, 'quantityOut' => $row->quantity_out, 'unitCost' => $row->unit_cost, 'totalCost' => $row->total_cost, 'occurredAt' => $row->occurred_at])->values();

        return response()->json(['data' => ['period' => ['from' => $from, 'to' => $to], 'branches' => DB::table('branches')->where('tenant_id', $tenant)->where('is_active', true)->whereNull('deleted_at')->orderBy('name')->get(['id', 'name'])->map(fn (object $branch) => ['id' => (int) $branch->id, 'name' => $branch->name]), 'kpis' => ['totalInventoryValue' => ['value' => number_format($rows->sum(fn (object $row) => (float) $row->quantity_on_hand * (float) $row->average_unit_cost), 2, '.', ''), 'previousValue' => null], 'lowStockItems' => ['value' => $rows->filter(fn (object $row) => (float) $row->quantity_on_hand > 0 && (float) $row->quantity_on_hand <= (float) $row->reorder_level)->unique('inventory_item_id')->count(), 'previousValue' => null], 'outOfStockItems' => ['value' => $rows->filter(fn (object $row) => (float) $row->quantity_on_hand <= 0)->unique('inventory_item_id')->count(), 'previousValue' => null], 'wasteValue' => ['value' => number_format($waste, 2, '.', ''), 'previousValue' => $previousWaste === null ? null : number_format($previousWaste, 2, '.', '')]], 'totalInventoryValue' => number_format($rows->sum(fn (object $row) => (float) $row->quantity_on_hand * (float) $row->average_unit_cost), 2, '.', ''), 'lowStockItemCount' => $rows->filter(fn (object $row) => (float) $row->quantity_on_hand > 0 && (float) $row->quantity_on_hand <= (float) $row->reorder_level)->unique('inventory_item_id')->count(), 'outOfStockItemCount' => $rows->filter(fn (object $row) => (float) $row->quantity_on_hand <= 0)->unique('inventory_item_id')->count(), 'wasteValue' => number_format($waste, 2, '.', ''), 'stockValueByWarehouse' => $warehouseValues, 'lowStockAlerts' => $alerts, 'recentMovements' => $recent]]);
    }

    private function serialize(object $row): array
    {
        return ['id' => (int) $row->id, 'warehouseId' => (int) $row->warehouse_id, 'warehouseName' => $row->warehouse_name, 'displayWarehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($row->warehouse_type), 'itemId' => (int) $row->inventory_item_id, 'itemNameAr' => $row->name_ar, 'itemNameEn' => $row->name_en ?: $row->sku, 'sku' => $row->sku, 'unit' => $row->unit, 'quantityOnHand' => $row->quantity_on_hand, 'reservedQuantity' => $row->reserved_quantity, 'availableQuantity' => number_format((float) $row->quantity_on_hand - (float) $row->reserved_quantity, 3, '.', ''), 'averageUnitCost' => $row->average_unit_cost, 'totalValue' => number_format((float) $row->quantity_on_hand * (float) $row->average_unit_cost, 2, '.', ''), 'isLowStock' => (float) $row->quantity_on_hand <= (float) $row->reorder_level, 'lastMovementAt' => $row->last_movement_at];
    }
}
