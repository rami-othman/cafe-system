<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\InventoryItemRequest;
use App\Services\InventoryItemService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use App\Support\InventoryUnitCatalog;
use App\Support\WarehousePresentation;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryItemController extends Controller
{
    public function __construct(private readonly InventoryItemService $items) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $stockTotals = DB::table('stock_balances')
            ->select(
                'inventory_item_id',
                DB::raw('COALESCE(SUM(quantity_on_hand), 0) as total_quantity'),
                DB::raw('COALESCE(SUM(quantity_on_hand - reserved_quantity), 0) as available_quantity'),
                DB::raw('COALESCE(SUM(quantity_on_hand * average_unit_cost), 0) as total_value'),
            )
            ->where('tenant_id', $tenant)
            ->groupBy('inventory_item_id');
        $query = DB::table('inventory_items as items')
            ->leftJoinSub($stockTotals, 'stock_totals', fn ($join) => $join->on('stock_totals.inventory_item_id', '=', 'items.id'))
            ->where('items.tenant_id', $tenant)
            ->whereNull('items.deleted_at')
            ->select('items.*', 'stock_totals.total_quantity', 'stock_totals.available_quantity', 'stock_totals.total_value');
        if ($request->filled('search')) {
            $like = '%'.strtolower($request->query('search')).'%';
            $query->where(fn (Builder $q) => $q->whereRaw('LOWER(items.name_ar) LIKE ?', [$like])->orWhereRaw('LOWER(items.name_en) LIKE ?', [$like])->orWhereRaw('LOWER(items.sku) LIKE ?', [$like])->orWhereRaw('LOWER(items.barcode) LIKE ?', [$like]));
        }
        foreach (['type' => 'item_type', 'category' => 'category'] as $key => $column) {
            if ($request->filled($key)) {
                $query->where('items.'.$column, $request->query($key));
            }
        }
        if ($request->filled('status')) {
            $query->where('items.is_active', $request->query('status') === 'active');
        }
        match ($request->query('stockStatus')) {
            'in' => $query->whereRaw('COALESCE(stock_totals.available_quantity, 0) > items.reorder_level'),
            'low' => $query->whereRaw('COALESCE(stock_totals.available_quantity, 0) > 0')->whereRaw('COALESCE(stock_totals.available_quantity, 0) <= items.reorder_level'),
            'out' => $query->whereRaw('COALESCE(stock_totals.available_quantity, 0) <= 0'),
            default => null,
        };
        $paginator = $query->orderBy('items.name_en')->orderBy('items.id')->paginate($this->perPage($request));

        return response()->json([
            'data' => [
                'items' => collect($paginator->items())->map(fn (object $row) => $this->serialize($tenant, $row))->values(),
                'meta' => $this->meta($paginator),
                'filters' => $this->filters($tenant),
            ],
        ]);
    }

    public function units(): JsonResponse
    {
        return response()->json(['data' => InventoryUnitCatalog::response()]);
    }

    public function conversionItems(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = DB::table('inventory_items')
            ->where('tenant_id', $tenant)
            ->where('is_active', true)
            ->whereNull('deleted_at');
        if ($request->filled('search')) {
            $like = '%'.strtolower($request->query('search')).'%';
            $query->where(fn (Builder $builder) => $builder
                ->whereRaw('LOWER(name_ar) LIKE ?', [$like])
                ->orWhereRaw('LOWER(name_en) LIKE ?', [$like])
                ->orWhereRaw('LOWER(sku) LIKE ?', [$like]));
        }

        return response()->json(['data' => $query
            ->orderBy('name_en')
            ->orderBy('id')
            ->limit(100)
            ->get(['id', 'name_en', 'name_ar', 'sku', 'unit'])
            ->map(fn (object $item) => [
                'id' => (int) $item->id,
                'displayName' => $item->name_en ?: $item->name_ar,
                'sku' => $item->sku,
                'unit' => $item->unit,
                'isActive' => true,
            ])
            ->values(),
        ]);
    }

    public function show(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);

        return response()->json(['data' => $this->serialize($tenant, $this->items->find($tenant, $item), true)]);
    }

    public function store(InventoryItemRequest $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $id = $this->items->save($request, $tenant, $request->validated(), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($tenant, $this->items->find($tenant, $id), true)], 201);
    }

    public function update(InventoryItemRequest $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->items->save($request, $tenant, $request->validated(), FinancialActor::id($request, $tenant), $item);

        return response()->json(['data' => $this->serialize($tenant, $this->items->find($tenant, $item), true)]);
    }

    public function status(Request $request, int $item): JsonResponse
    {
        $data = $request->validate(['isActive' => ['required', 'boolean']]);
        $tenant = TenantContext::id($request);
        $this->items->setStatus($request, $tenant, $item, (bool) $data['isActive'], FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($tenant, $this->items->find($tenant, $item), true)]);
    }

    public function stock(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->items->find($tenant, $item);
        $rows = DB::table('stock_balances as balances')->join('warehouses as warehouses', 'warehouses.id', '=', 'balances.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('balances.tenant_id', $tenant)->where('balances.inventory_item_id', $item)->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%')->orderBy('warehouses.name')->get(['balances.*', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name']);

        return response()->json(['data' => $rows->map(fn (object $row) => $this->balance($row))->values()]);
    }

    public function movements(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->items->find($tenant, $item);
        $rows = DB::table('stock_movements as movements')->join('warehouses', 'warehouses.id', '=', 'movements.warehouse_id')->where('movements.tenant_id', $tenant)->where('movements.inventory_item_id', $item)->orderByDesc('movements.occurred_at')->get(['movements.*', 'warehouses.name as warehouse_name']);

        return response()->json(['data' => $rows->map(fn (object $row) => $this->movement($row))->values()]);
    }

    private function serialize(int $tenant, object $item, bool $detail = false): array
    {
        $totals = isset($item->total_quantity)
            ? $item
            : DB::table('stock_balances')
                ->where('tenant_id', $tenant)
                ->where('inventory_item_id', $item->id)
                ->selectRaw('COALESCE(SUM(quantity_on_hand), 0) as total_quantity')
                ->selectRaw('COALESCE(SUM(quantity_on_hand - reserved_quantity), 0) as available_quantity')
                ->selectRaw('COALESCE(SUM(quantity_on_hand * average_unit_cost), 0) as total_value')
                ->first();
        $data = ['id' => (int) $item->id, 'nameAr' => $item->name_ar, 'nameEn' => $item->name_en, 'displayName' => $item->name_en ?: $item->sku, 'sku' => $item->sku, 'barcode' => $item->barcode, 'itemType' => $item->item_type, 'category' => $item->category, 'unit' => $item->unit, 'minimumStock' => $item->minimum_stock, 'reorderLevel' => $item->reorder_level, 'latestUnitCost' => $item->latest_unit_cost, 'totalQuantity' => number_format((float) ($totals->total_quantity ?? 0), 3, '.', ''), 'availableQuantity' => number_format((float) ($totals->available_quantity ?? 0), 3, '.', ''), 'totalValue' => number_format((float) ($totals->total_value ?? 0), 2, '.', ''), 'isActive' => (bool) $item->is_active, 'notes' => $item->notes];
        if ($detail) {
            $data['stockByWarehouse'] = DB::table('stock_balances as balances')->join('warehouses as warehouses', 'warehouses.id', '=', 'balances.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('balances.tenant_id', $tenant)->where('balances.inventory_item_id', $item->id)->whereNull('warehouses.deleted_at')->where('warehouses.is_active', true)->where('warehouses.code', 'not like', 'LEGACY-%')->orderByRaw('CASE WHEN warehouses.branch_id IS NULL THEN 0 ELSE 1 END')->orderBy('branches.name')->orderBy('warehouses.name')->get(['balances.*', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name'])->map(fn (object $row) => $this->balance($row))->values();
            $data['recentMovements'] = DB::table('stock_movements as movements')->join('warehouses as warehouses', 'warehouses.id', '=', 'movements.warehouse_id')->where('movements.tenant_id', $tenant)->where('movements.inventory_item_id', $item->id)->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%')->orderByDesc('movements.occurred_at')->orderByDesc('movements.id')->limit(5)->get(['movements.*', 'warehouses.name as warehouse_name'])->map(fn (object $row) => $this->movement($row))->values();
            $data['lastMovement'] = $data['recentMovements']->first();
        }

        return $data;
    }

    private function balance(object $row): array
    {
        return ['warehouseId' => (int) $row->warehouse_id, 'warehouseName' => $row->warehouse_name, 'warehouseCode' => $row->warehouse_code, 'branchName' => $row->branch_name, 'displayWarehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($row->warehouse_type), 'quantityOnHand' => $row->quantity_on_hand, 'reservedQuantity' => $row->reserved_quantity, 'availableQuantity' => number_format((float) $row->quantity_on_hand - (float) $row->reserved_quantity, 3, '.', ''), 'averageUnitCost' => $row->average_unit_cost, 'totalValue' => number_format((float) $row->quantity_on_hand * (float) $row->average_unit_cost, 2, '.', ''), 'lastMovementAt' => $row->last_movement_at];
    }

    private function movement(object $row): array
    {
        return ['id' => (int) $row->id, 'warehouseName' => $row->warehouse_name, 'type' => $row->type, 'quantityIn' => $row->quantity_in, 'quantityOut' => $row->quantity_out, 'quantityBefore' => $row->quantity_before, 'quantityAfter' => $row->quantity_after, 'unitCost' => $row->unit_cost, 'totalCost' => $row->total_cost, 'reason' => $row->reason, 'occurredAt' => $row->occurred_at];
    }


    private function perPage(Request $request): int
    {
        return min(max((int) $request->query('perPage', 25), 1), 100);
    }

    private function meta($paginator): array
    {
        return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()];
    }

    private function filters(int $tenant): array
    {
        $items = DB::table('inventory_items')
            ->where('tenant_id', $tenant)
            ->whereNull('deleted_at');

        return [
            'categories' => (clone $items)->whereNotNull('category')->where('category', '!=', '')->distinct()->orderBy('category')->pluck('category')->values(),
        ];
    }
}
