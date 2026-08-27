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
            'movement_type' => ['nullable', 'in:purchase_receive,recipe_consumption,transfer_in,transfer_out,waste,adjustment,opening_balance,return'],
            'trend_days' => ['nullable', 'integer', 'in:7,30,90'],
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
        $movementType = $filters['movement_type'] ?? null;
        $trendDays = (int) ($filters['trend_days'] ?? 30);
        $movementTypes = $this->dashboardMovementTypes($movementType);
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
        $rows = $base->get(['balances.*', 'items.name_en', 'items.name_ar', 'items.sku', 'items.unit', 'items.minimum_stock', 'items.reorder_level', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name']);
        $movementScope = function (Builder $query) use ($tenant, $branchId, $warehouseId, $filters): void {
            $query->where('movements.tenant_id', $tenant)->where('items.is_active', true)->whereNull('items.deleted_at')->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%');
            if ($branchId) $query->where('warehouses.branch_id', $branchId);
            if ($warehouseId) $query->where('movements.warehouse_id', $warehouseId);
            if (! empty($filters['search'])) {
                $like = '%'.strtolower($filters['search']).'%';
                $query->where(fn (Builder $search) => $search->whereRaw('LOWER(items.name_en) LIKE ?', [$like])->orWhereRaw('LOWER(items.name_ar) LIKE ?', [$like])->orWhereRaw('LOWER(items.sku) LIKE ?', [$like]));
            }
        };
        $movementQuery = fn () => DB::table('stock_movements as movements')->join('inventory_items as items', 'items.id', '=', 'movements.inventory_item_id')->join('warehouses as warehouses', 'warehouses.id', '=', 'movements.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->leftJoin('users', 'users.id', '=', 'movements.created_by');
        $movementValue = function (array $types, string $start, string $end) use ($movementQuery, $movementScope): float {
            $query = $movementQuery(); $movementScope($query);
            return round((float) $query->whereIn('movements.type', $types)->whereBetween(DB::raw('DATE(movements.occurred_at)'), [$start, $end])->sum('movements.total_cost'), 2);
        };
        $waste = $movementValue(['waste'], $from, $to);
        $previousWaste = (bool) ($filters['compare_previous'] ?? true) ? $movementValue(['waste'], $previousFrom, $previousTo) : null;
        $today = now()->toDateString();
        $yesterday = now()->subDay()->toDateString();
        $todayWaste = $movementValue(['waste'], $today, $today);
        $previousTodayWaste = (bool) ($filters['compare_previous'] ?? true) ? $movementValue(['waste'], $yesterday, $yesterday) : null;
        // Phase 3 writes sale_consumption through the same immutable ledger.
        // Until then this is correctly zero rather than a Flutter-side estimate.
        $todayConsumption = $movementValue(['sale_consumption'], $today, $today);
        $previousTodayConsumption = (bool) ($filters['compare_previous'] ?? true) ? $movementValue(['sale_consumption'], $yesterday, $yesterday) : null;
        $weekStart = now()->startOfWeek()->toDateString();
        $weekWaste = $movementValue(['waste'], $weekStart, $today);
        $weekWasteMovements = $movementQuery();
        $movementScope($weekWasteMovements);
        $weekWasteMovementCount = $weekWasteMovements
            ->where('movements.type', 'waste')
            ->whereBetween(DB::raw('DATE(movements.occurred_at)'), [$weekStart, $today])
            ->count();
        $topItemsForType = function (string $type, string $start, string $end) use ($movementQuery, $movementScope): array {
            $query = $movementQuery();
            $movementScope($query);

            return $query
                ->where('movements.type', $type)
                ->whereBetween(DB::raw('DATE(movements.occurred_at)'), [$start, $end])
                ->groupBy('movements.inventory_item_id', 'items.name_en', 'items.sku', 'items.unit')
                ->orderByDesc('cost')
                ->limit(3)
                ->get([
                    'movements.inventory_item_id as item_id',
                    'items.name_en',
                    'items.sku',
                    'items.unit',
                    DB::raw('SUM(movements.quantity_out) as quantity'),
                    DB::raw('SUM(movements.total_cost) as cost'),
                ])
                ->map(fn (object $row) => [
                    'itemId' => (int) $row->item_id,
                    'itemName' => $row->name_en ?: $row->sku,
                    'quantity' => number_format((float) $row->quantity, 3, '.', ''),
                    'unit' => $row->unit,
                    'cost' => number_format((float) $row->cost, 2, '.', ''),
                ])
                ->values()
                ->all();
        };
        $wasteSummary = [
            'todayCost' => number_format($todayWaste, 2, '.', ''),
            'weekCost' => number_format($weekWaste, 2, '.', ''),
            'movementCount' => $weekWasteMovementCount,
            'topItems' => $topItemsForType('waste', $weekStart, $today),
        ];
        $consumptionTotal = $movementValue(['sale_consumption'], $from, $to);
        $consumptionSummary = [
            'totalCost' => number_format($consumptionTotal, 2, '.', ''),
            'topItems' => $topItemsForType('sale_consumption', $from, $to),
        ];

        $warehousesQuery = DB::table('warehouses as warehouses')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('warehouses.tenant_id', $tenant)->where('warehouses.is_active', true)->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%');
        if ($branchId) $warehousesQuery->where('warehouses.branch_id', $branchId);
        if ($warehouseId) $warehousesQuery->where('warehouses.id', $warehouseId);
        $lowStockRows = $rows->filter(fn (object $row) => (float) $row->quantity_on_hand <= (float) $row->reorder_level);
        $isCriticalAlert = fn (object $row): bool => (float) $row->quantity_on_hand <= 0 || ((float) $row->minimum_stock > 0 && (float) $row->quantity_on_hand <= (float) $row->minimum_stock);
        $alertSummary = [
            'critical' => $lowStockRows->filter($isCriticalAlert)->count(),
            'low' => $lowStockRows->reject($isCriticalAlert)->count(),
            'total' => $lowStockRows->count(),
        ];
        $warehouseValues = $warehousesQuery->orderBy('warehouses.name')->get(['warehouses.id', 'warehouses.type', 'branches.name as branch_name'])->map(function (object $warehouse) use ($rows, $isCriticalAlert): array {
            $group = $rows->where('warehouse_id', $warehouse->id);
            $itemCount = $group->pluck('inventory_item_id')->unique()->count();
            $alertsCount = $group->filter(fn (object $row) => (float) $row->quantity_on_hand <= (float) $row->reorder_level)->pluck('inventory_item_id')->unique()->count();
            $healthPercentage = $itemCount === 0 ? 0 : (int) round($group->filter(fn (object $row) => (float) $row->quantity_on_hand > (float) $row->minimum_stock)->pluck('inventory_item_id')->unique()->count() / $itemCount * 100);
            $status = $group->contains($isCriticalAlert) ? 'critical' : ($alertsCount > 0 ? 'attention' : 'healthy');
            return ['warehouseId' => (int) $warehouse->id, 'warehouseName' => WarehousePresentation::displayName($warehouse->branch_name, $warehouse->type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($warehouse->type), 'value' => number_format($group->sum(fn (object $row) => (float) $row->quantity_on_hand * (float) $row->average_unit_cost), 2, '.', ''), 'itemCount' => $itemCount, 'alertsCount' => $alertsCount, 'lastMovementAt' => $group->max('last_movement_at'), 'healthPercentage' => $healthPercentage, 'status' => $status];
        })->sort(function (array $left, array $right): int {
            $leftKey = [$left['alertsCount'] > 0 ? 0 : 1, $left['itemCount'] === 0 ? 1 : 0, -(float) $left['value']];
            $rightKey = [$right['alertsCount'] > 0 ? 0 : 1, $right['itemCount'] === 0 ? 1 : 0, -(float) $right['value']];
            return $leftKey <=> $rightKey;
        })->values();
        $alerts = $lowStockRows->sortBy(fn (object $row) => $isCriticalAlert($row) ? -1000000 : ((float) $row->quantity_on_hand / max((float) $row->reorder_level, 0.001)))->take(8)->map(fn (object $row) => ['itemId' => (int) $row->inventory_item_id, 'itemName' => $row->name_en ?: $row->sku, 'warehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'quantity' => number_format((float) $row->quantity_on_hand, 3, '.', ''), 'minimumLevel' => number_format((float) $row->minimum_stock, 3, '.', ''), 'missingQuantity' => number_format(max((float) $row->minimum_stock - (float) $row->quantity_on_hand, 0), 3, '.', ''), 'suggestedReorderQuantity' => number_format(max((float) $row->reorder_level - (float) $row->quantity_on_hand, 0), 3, '.', ''), 'severity' => (float) $row->quantity_on_hand <= 0 ? 'out_of_stock' : ($isCriticalAlert($row) ? 'critical' : 'low'), 'unit' => $row->unit, 'outOfStock' => (float) $row->quantity_on_hand <= 0])->values();
        $recentQuery = $movementQuery(); $movementScope($recentQuery);
        if ($movementTypes !== []) $recentQuery->whereIn('movements.type', $movementTypes);
        $recent = $recentQuery->whereBetween(DB::raw('DATE(movements.occurred_at)'), [$from, $to])->orderByDesc('movements.occurred_at')->orderByDesc('movements.id')->limit(8)->get(['movements.*', 'items.name_en', 'items.sku', 'items.unit', 'warehouses.type as warehouse_type', 'branches.name as branch_name', 'users.name as user_name'])->map(fn (object $row) => ['id' => (int) $row->id, 'itemId' => (int) $row->inventory_item_id, 'itemNameEn' => $row->name_en ?: $row->sku, 'warehouseId' => (int) $row->warehouse_id, 'warehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($row->warehouse_type), 'unit' => $row->unit, 'type' => $row->type, 'dashboardType' => $this->dashboardMovementType($row->type), 'quantityIn' => $row->quantity_in, 'quantityOut' => $row->quantity_out, 'unitCost' => $row->unit_cost, 'totalCost' => $row->total_cost, 'referenceType' => $row->reference_type, 'referenceId' => $row->reference_id, 'reference' => $row->reference_type ? $row->reference_type.($row->reference_id ? ' #'.$row->reference_id : '') : null, 'userName' => $row->user_name, 'occurredAt' => $row->occurred_at, 'createdAt' => $row->created_at])->values();

        $totalValue = (float) $rows->sum(fn (object $row) => (float) $row->quantity_on_hand * (float) $row->average_unit_cost);
        $trendTo = now()->toDateString();
        $trendFrom = now()->subDays($trendDays - 1)->toDateString();
        $trend = $this->stockValueTrend($movementQuery, $movementScope, $trendFrom, $trendTo, $totalValue);
        $itemsQuery = DB::table('inventory_items as items')
            ->where('items.tenant_id', $tenant)
            ->where('items.is_active', true)
            ->whereNull('items.deleted_at');
        if (! empty($filters['search'])) {
            $like = '%'.strtolower($filters['search']).'%';
            $itemsQuery->where(fn (Builder $query) => $query
                ->whereRaw('LOWER(items.name_en) LIKE ?', [$like])
                ->orWhereRaw('LOWER(items.name_ar) LIKE ?', [$like])
                ->orWhereRaw('LOWER(items.sku) LIKE ?', [$like]));
        }
        if ($branchId || $warehouseId) {
            $itemsQuery->whereExists(function (Builder $query) use ($tenant, $branchId, $warehouseId): void {
                $query->selectRaw('1')
                    ->from('stock_balances as scoped_balances')
                    ->join('warehouses as scoped_warehouses', 'scoped_warehouses.id', '=', 'scoped_balances.warehouse_id')
                    ->whereColumn('scoped_balances.inventory_item_id', 'items.id')
                    ->where('scoped_balances.tenant_id', $tenant)
                    ->where('scoped_warehouses.tenant_id', $tenant)
                    ->where('scoped_warehouses.is_active', true)
                    ->whereNull('scoped_warehouses.deleted_at')
                    ->where('scoped_warehouses.code', 'not like', 'LEGACY-%');
                if ($branchId) $query->where('scoped_warehouses.branch_id', $branchId);
                if ($warehouseId) $query->where('scoped_balances.warehouse_id', $warehouseId);
            });
        }
        $totalItems = $itemsQuery->count();
        $lowStockItems = $rows->filter(fn (object $row) => (float) $row->quantity_on_hand > 0 && (float) $row->quantity_on_hand <= (float) $row->reorder_level)->pluck('inventory_item_id')->unique()->count();
        $outOfStockItems = $rows->filter(fn (object $row) => (float) $row->quantity_on_hand <= 0)->pluck('inventory_item_id')->unique()->count();

        return response()->json(['data' => ['period' => ['from' => $from, 'to' => $to], 'branches' => DB::table('branches')->where('tenant_id', $tenant)->where('is_active', true)->whereNull('deleted_at')->orderBy('name')->get(['id', 'name'])->map(fn (object $branch) => ['id' => (int) $branch->id, 'name' => $branch->name]), 'kpis' => ['totalInventoryValue' => ['value' => number_format($totalValue, 2, '.', ''), 'previousValue' => null], 'totalItems' => ['value' => (string) $totalItems, 'previousValue' => null], 'lowStockItems' => ['value' => (string) $lowStockItems, 'previousValue' => null], 'outOfStockItems' => ['value' => (string) $outOfStockItems, 'previousValue' => null], 'todayConsumptionCost' => ['value' => number_format($todayConsumption, 2, '.', ''), 'previousValue' => $previousTodayConsumption === null ? null : number_format($previousTodayConsumption, 2, '.', '')], 'todayWasteCost' => ['value' => number_format($todayWaste, 2, '.', ''), 'previousValue' => $previousTodayWaste === null ? null : number_format($previousTodayWaste, 2, '.', '')], 'wasteValue' => ['value' => number_format($waste, 2, '.', ''), 'previousValue' => $previousWaste === null ? null : number_format($previousWaste, 2, '.', '')]], 'totalInventoryValue' => number_format($totalValue, 2, '.', ''), 'lowStockItemCount' => $lowStockItems, 'outOfStockItemCount' => $outOfStockItems, 'wasteValue' => number_format($waste, 2, '.', ''), 'stockValueByWarehouse' => $warehouseValues, 'inventoryAlertsSummary' => $alertSummary, 'lowStockAlerts' => $alerts, 'recentMovements' => $recent, 'stockValueTrend' => $trend, 'wasteSummary' => $wasteSummary, 'consumptionSummary' => $consumptionSummary, 'stock_value_trend' => $trend['points'], 'waste_summary' => $wasteSummary, 'consumption_summary' => $consumptionSummary]]);
    }

    /** @param callable(): Builder $movementQuery @param callable(Builder): void $movementScope */
    private function stockValueTrend(callable $movementQuery, callable $movementScope, string $from, string $to, float $currentValue): array
    {
        $query = $movementQuery();
        $movementScope($query);
        $dailyChanges = $query->whereBetween(DB::raw('DATE(movements.occurred_at)'), [$from, $to])->selectRaw("DATE(movements.occurred_at) as date, SUM(CASE WHEN movements.quantity_in > 0 THEN movements.total_cost ELSE -movements.total_cost END) as value_change")->groupBy(DB::raw('DATE(movements.occurred_at)'))->pluck('value_change', 'date');
        $afterSelectedRange = $movementQuery();
        $movementScope($afterSelectedRange);
        $valueAfterRange = (float) $afterSelectedRange->whereDate('movements.occurred_at', '>', $to)->selectRaw('COALESCE(SUM(CASE WHEN movements.quantity_in > 0 THEN movements.total_cost ELSE -movements.total_cost END), 0) as value_change')->value('value_change');
        $runningValue = $currentValue - $valueAfterRange - $dailyChanges->sum(fn ($value) => (float) $value);
        $points = [];
        for ($date = Carbon::parse($from); $date->lte(Carbon::parse($to)); $date->addDay()) {
            $runningValue += (float) ($dailyChanges[$date->toDateString()] ?? 0);
            $points[] = ['date' => $date->toDateString(), 'value' => number_format($runningValue, 2, '.', '')];
        }

        return ['available' => true, 'points' => $points];
    }

    private function dashboardMovementType(string $type): string
    {
        return match ($type) {
            'stock_in' => 'purchase_receive',
            'sale_consumption' => 'recipe_consumption',
            'transfer_in' => 'transfer_in',
            'transfer_out' => 'transfer_out',
            'waste' => 'waste',
            'adjustment_in', 'adjustment_out', 'stock_count_variance' => 'adjustment',
            'opening_balance' => 'opening_balance',
            'return_in', 'return_out' => 'return',
            default => 'adjustment',
        };
    }

    private function dashboardMovementTypes(?string $type): array
    {
        return match ($type) {
            'purchase_receive' => ['stock_in'],
            'recipe_consumption' => ['sale_consumption'],
            'transfer_in' => ['transfer_in'],
            'transfer_out' => ['transfer_out'],
            'waste' => ['waste'],
            'adjustment' => ['adjustment_in', 'adjustment_out', 'stock_count_variance'],
            'opening_balance' => ['opening_balance'],
            'return' => ['return_in', 'return_out'],
            default => [],
        };
    }

    private function serialize(object $row): array
    {
        return ['id' => (int) $row->id, 'warehouseId' => (int) $row->warehouse_id, 'warehouseName' => $row->warehouse_name, 'displayWarehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($row->warehouse_type), 'itemId' => (int) $row->inventory_item_id, 'itemNameAr' => $row->name_ar, 'itemNameEn' => $row->name_en ?: $row->sku, 'sku' => $row->sku, 'unit' => $row->unit, 'quantityOnHand' => $row->quantity_on_hand, 'reservedQuantity' => $row->reserved_quantity, 'availableQuantity' => number_format((float) $row->quantity_on_hand - (float) $row->reserved_quantity, 3, '.', ''), 'averageUnitCost' => $row->average_unit_cost, 'totalValue' => number_format((float) $row->quantity_on_hand * (float) $row->average_unit_cost, 2, '.', ''), 'isLowStock' => (float) $row->quantity_on_hand <= (float) $row->reorder_level, 'lastMovementAt' => $row->last_movement_at];
    }
}
