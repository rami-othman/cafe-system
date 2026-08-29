<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StockMovementRequest;
use App\Domain\Inventory\InventoryPostingService;
use App\Support\FinancialActor;
use App\Support\InventoryAccess;
use App\Support\InventoryDecimal;
use App\Support\TenantContext;
use App\Support\WarehousePresentation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class StockMovementController extends Controller
{
    public function __construct(private readonly InventoryPostingService $movements) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = DB::table('stock_movements as movements')->join('inventory_items as items', 'items.id', '=', 'movements.inventory_item_id')->join('warehouses as warehouses', 'warehouses.id', '=', 'movements.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->leftJoin('users', 'users.id', '=', 'movements.created_by')->where('movements.tenant_id', $tenant)->where('warehouses.code', 'not like', 'LEGACY-%')->select('movements.*', 'items.name_ar as item_name_ar', 'items.name_en as item_name_en', 'items.sku', 'items.unit', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name', 'users.name as user_name');
        InventoryAccess::scopeWarehouseBranches($query, $request, 'warehouses.branch_id');
        foreach (['warehouseId' => 'movements.warehouse_id', 'itemId' => 'movements.inventory_item_id', 'type' => 'movements.type', 'userId' => 'movements.created_by'] as $key => $column) {
            if ($request->filled($key)) {
                $query->where($column, $request->query($key));
            }
        }
        if ($request->filled('from')) {
            $query->whereDate('movements.occurred_at', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('movements.occurred_at', '<=', $request->query('to'));
        }
        $paginator = $query->orderByDesc('movements.occurred_at')->orderByDesc('movements.id')->paginate(min(max((int) $request->query('perPage', 50), 1), 100));

        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row))->values(), 'meta' => ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]]);
    }

    public function store(StockMovementRequest $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        if (! in_array($request->validated('type'), ['stock_in', 'stock_out', 'adjustment_in', 'adjustment_out', 'waste'], true)) {
            throw ValidationException::withMessages(['type' => 'هذه الحركة تُنشأ من سير عمل النظام فقط.']);
        }
        $result = $this->movements->post($request, $tenant, $request->validated(), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($this->find($tenant, $result->movementId))], $result->replayed ? 200 : 201);
    }

    public function show(Request $request, int $movement): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $row = $this->find($tenant, $movement);
        InventoryAccess::assertBranchAccess($request, DB::table('warehouses')->where('id', $row->warehouse_id)->value('branch_id'));

        return response()->json(['data' => $this->serialize($row)]);
    }

    private function find(int $tenant, int $id): object
    {
        $row = DB::table('stock_movements as movements')->join('inventory_items as items', 'items.id', '=', 'movements.inventory_item_id')->join('warehouses as warehouses', 'warehouses.id', '=', 'movements.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->leftJoin('users', 'users.id', '=', 'movements.created_by')->where('movements.tenant_id', $tenant)->where('movements.id', $id)->select('movements.*', 'items.name_ar as item_name_ar', 'items.name_en as item_name_en', 'items.sku', 'items.unit', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name', 'users.name as user_name')->first();
        abort_unless($row, 404, 'حركة المخزون غير موجودة.');

        return $row;
    }

    private function serialize(object $row): array
    {
        return ['id' => (int) $row->id, 'warehouseId' => (int) $row->warehouse_id, 'warehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($row->warehouse_type), 'itemId' => (int) $row->inventory_item_id, 'itemNameAr' => $row->item_name_en ?: $row->sku, 'unit' => $row->unit, 'inputUnit' => $row->input_unit ?? $row->unit, 'conversionFactor' => InventoryDecimal::conversionFactor(InventoryDecimal::factor($row->conversion_factor ?? '1.000000')), 'baseQuantity' => InventoryDecimal::quantity(InventoryDecimal::units($row->base_quantity ?? $row->quantity)), 'type' => $row->type, 'quantityIn' => InventoryDecimal::quantity(InventoryDecimal::units($row->quantity_in)), 'quantityOut' => InventoryDecimal::quantity(InventoryDecimal::units($row->quantity_out)), 'quantityBefore' => InventoryDecimal::quantity(InventoryDecimal::units($row->quantity_before)), 'quantityAfter' => InventoryDecimal::quantity(InventoryDecimal::units($row->quantity_after)), 'unitCost' => InventoryDecimal::unitCost(InventoryDecimal::cost($row->unit_cost)), 'totalCost' => $row->total_cost, 'reason' => $row->reason, 'referenceType' => $row->reference_type, 'referenceId' => $row->reference_id ? (int) $row->reference_id : null, 'userName' => $row->user_name, 'occurredAt' => $row->occurred_at, 'createdAt' => $row->created_at];
    }
}
