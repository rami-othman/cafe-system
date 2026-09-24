<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\InventoryItemRequest;
use App\Services\InventoryItemService;
use App\Support\Search\SmartSearch;
use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\TenantContext;
use App\Support\InventoryUnitCatalog;
use App\Support\InventoryAccess;
use App\Support\WarehousePresentation;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class InventoryItemController extends Controller
{
    public function __construct(private readonly InventoryItemService $items) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $branchId = $request->filled('branchId') ? (int) $request->query('branchId') : null;
        $warehouseId = $request->filled('warehouseId') ? (int) $request->query('warehouseId') : null;
        if ($branchId) {
            abort_unless(DB::table('branches')->where('tenant_id', $tenant)->where('id', $branchId)->whereNull('deleted_at')->exists(), 404);
            InventoryAccess::assertBranchAccess($request, $branchId);
        }
        if ($warehouseId) {
            $warehouse = DB::table('warehouses')->where('tenant_id', $tenant)->where('id', $warehouseId)->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $warehouse) {
                abort(422, 'The selected warehouse is not available.');
            }
            // Tenant ownership alone is not enough: a branch-restricted actor
            // must not be able to pull another branch's items (with names/SKUs
            // visible, just zeroed stock) by requesting its warehouseId directly.
            InventoryAccess::assertBranchAccess($request, $warehouse->branch_id);
            if ($branchId && $warehouse->branch_id !== null && (int) $warehouse->branch_id !== $branchId) {
                abort(422, 'The selected warehouse does not belong to the selected branch.');
            }
            if ($warehouse->branch_id === null) $branchId = null;
        }
        $stockTotals = DB::table('stock_balances')
            ->select(
                'inventory_item_id',
                DB::raw('COALESCE(SUM(quantity_on_hand), 0) as total_quantity'),
                DB::raw('COALESCE(SUM(quantity_on_hand - reserved_quantity), 0) as available_quantity'),
                DB::raw('COALESCE(SUM(quantity_on_hand * average_unit_cost), 0) as total_value'),
            )
            ->where('tenant_id', $tenant)
            ->groupBy('inventory_item_id');
        $stockTotals->whereIn('warehouse_id', function ($warehouses) use ($tenant, $request, $branchId): void {
            $warehouses->select('id')->from('warehouses')
                ->where('tenant_id', $tenant)
                ->where('is_active', true)
                ->whereNull('deleted_at')
                ->where('code', 'not like', 'LEGACY-%');
            InventoryAccess::scopeWarehouseBranches($warehouses, $request, 'branch_id');
            if ($branchId) $warehouses->where('branch_id', $branchId);
        });
        if ($warehouseId) {
            $stockTotals->where('warehouse_id', $warehouseId);
        }
        $query = DB::table('inventory_items as items')
            ->leftJoinSub($stockTotals, 'stock_totals', fn ($join) => $join->on('stock_totals.inventory_item_id', '=', 'items.id'))
            ->where('items.tenant_id', $tenant)
            ->whereNull('items.deleted_at')
            ->select('items.*', 'stock_totals.total_quantity', 'stock_totals.available_quantity', 'stock_totals.total_value');
        if ($warehouseId && Schema::hasTable('inventory_item_warehouses')) {
            $query->whereExists(fn (Builder $assigned) => $assigned
                ->selectRaw('1')
                ->from('inventory_item_warehouses as availability')
                ->whereColumn('availability.inventory_item_id', 'items.id')
                ->where('availability.tenant_id', $tenant)
                ->where('availability.warehouse_id', $warehouseId));
        } elseif ($warehouseId) {
            $query->whereRaw('1 = 0');
        }
        $search = $request->query('search');
        $searchFields = [
            ['column' => 'items.name_ar', 'weight' => 3],
            ['column' => 'items.name_en', 'weight' => 3],
            ['column' => 'items.sku', 'weight' => 2, 'type' => 'code'],
            ['column' => 'items.barcode', 'weight' => 2, 'type' => 'code'],
        ];
        if ($request->filled('search')) {
            SmartSearch::apply($query, $search, $searchFields);
            SmartSearch::withRelevance($query, $search, $searchFields);
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
            'active' => $query->where('items.is_active', true),
            'inactive' => $query->where('items.is_active', false),
            'in' => $query->whereRaw('COALESCE(stock_totals.available_quantity, 0) > items.reorder_level'),
            'low', 'low_stock' => $query->whereNotIn('items.item_type', ['non_stock_item', 'service'])->whereRaw('COALESCE(stock_totals.available_quantity, 0) > 0')->whereRaw('COALESCE(stock_totals.available_quantity, 0) <= items.reorder_level'),
            'out', 'out_of_stock' => $query->whereNotIn('items.item_type', ['non_stock_item', 'service'])->whereRaw('COALESCE(stock_totals.available_quantity, 0) <= 0'),
            // Expiry is deliberately empty until batches with expiry dates exist;
            // an item-level toggle alone is not evidence of an expired quantity.
            'expired' => $query->whereRaw('1 = 0'),
            default => null,
        };
        if ($request->filled('search')) {
            $query->orderByDesc('smart_rank');
        }
        $paginator = $query
            ->orderBy('items.name_en')
            ->orderBy('items.id')
            ->paginate(
                $this->perPage($request),
                ['*'],
                'page',
                max(1, (int) $request->query('page', 1)),
            );

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
        $conversionSearch = $request->query('search');
        $conversionSearchFields = [
            ['column' => 'name_ar', 'weight' => 3],
            ['column' => 'name_en', 'weight' => 3],
            ['column' => 'sku', 'weight' => 2, 'type' => 'code'],
        ];
        if ($request->filled('search')) {
            SmartSearch::apply($query, $conversionSearch, $conversionSearchFields);
            SmartSearch::withRelevance($query, $conversionSearch, $conversionSearchFields);
            $query->orderByDesc('smart_rank');
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

        // Branch users obtain branch-filtered stock and movement details from
        // the dedicated endpoints below. Do not expose tenant-wide detail
        // aggregates from this catalogue endpoint.
        $detail = InventoryAccess::actor($request)->isOwner();

        return response()->json(['data' => $this->serialize($tenant, $this->items->find($tenant, $item), $detail)]);
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
        $query = DB::table('stock_balances as balances')->join('warehouses as warehouses', 'warehouses.id', '=', 'balances.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('balances.tenant_id', $tenant)->where('balances.inventory_item_id', $item)->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%')->orderBy('warehouses.name');
        InventoryAccess::scopeWarehouseBranches($query, $request, 'warehouses.branch_id');
        $rows = $query->get(['balances.*', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name']);

        return response()->json(['data' => $rows->map(fn (object $row) => $this->balance($row))->values()]);
    }

    /**
     * The item detail screen's full, paginated movement history - the
     * `recentMovements` array on show()/serialize() below is deliberately
     * capped at 5 rows for a quick summary and must stay that way; this is
     * the only endpoint the "سجل الحركات" tab may treat as the complete
     * history (see docs/client_feedback_review_2026-09-22.md, E1).
     */
    public function movements(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $itemRow = $this->items->find($tenant, $item);
        $query = DB::table('stock_movements as movements')
            ->join('warehouses', 'warehouses.id', '=', 'movements.warehouse_id')
            ->leftJoin('users', 'users.id', '=', 'movements.created_by')
            ->where('movements.tenant_id', $tenant)
            ->where('movements.inventory_item_id', $item)
            ->whereNull('warehouses.deleted_at')
            ->where('warehouses.code', 'not like', 'LEGACY-%');
        InventoryAccess::scopeWarehouseBranches($query, $request, 'warehouses.branch_id');
        if ($request->filled('from')) {
            $query->whereDate('movements.occurred_at', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('movements.occurred_at', '<=', $request->query('to'));
        }
        // occurred_at alone is not unique - Task C notes purchase flows can
        // still write a date-only business value there, so several
        // movements can share the same instant. `id DESC` breaks ties
        // deterministically without ever touching historical occurred_at.
        $paginator = $query
            ->orderByDesc('movements.occurred_at')
            ->orderByDesc('movements.id')
            ->paginate(
                min(max((int) $request->query('perPage', 25), 1), 100),
                ['movements.*', 'warehouses.name as warehouse_name', 'users.name as user_name'],
                'page',
                max(1, (int) $request->query('page', 1)),
            );

        return response()->json([
            'data' => collect($paginator->items())->map(fn (object $row) => $this->movement($row, $itemRow))->values(),
            'meta' => $this->meta($paginator),
        ]);
    }

    /**
     * Read-only "استخدام الوصفات" tab data: every live POS recipe that
     * consumes this material. `recipe_lines`/`recipes` are legacy tables
     * with zero remaining application references - the sale/costing path
     * (SaleConsumptionService) resolves recipes from the published menu
     * snapshot, itself built from `variant_recipe_components` and, for
     * modifier-driven adjustments, `modifier_option_recipe_profile_components`.
     * Those two tables are therefore the only correct source; this never
     * reads or writes manufacturing production/costing tables.
     */
    public function recipeUsage(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->items->find($tenant, $item);

        $variantLines = DB::table('variant_recipe_components as c')
            ->join('variant_recipes as r', 'r.id', '=', 'c.variant_recipe_id')
            ->join('product_variants as v', 'v.id', '=', 'r.product_variant_id')
            ->join('products as p', 'p.id', '=', 'v.product_id')
            ->where('c.tenant_id', $tenant)
            ->where('c.inventory_item_id', $item)
            ->whereNull('v.deleted_at')
            ->whereNull('p.deleted_at')
            ->get(['p.id as product_id', 'p.name as product_name', 'p.is_active as product_active', 'v.id as variant_id', 'v.name as variant_name', 'v.is_active as variant_active', 'c.quantity', 'c.unit_code'])
            ->map(fn (object $row) => [
                'source' => 'variant_recipe',
                'productId' => (int) $row->product_id,
                'productName' => $row->product_name,
                'variantId' => (int) $row->variant_id,
                'variantName' => $row->variant_name,
                'isActive' => (bool) $row->product_active && (bool) $row->variant_active,
                // Recipe component quantities carry 6 decimal places
                // (decimal(18,6) - a per-serving amount, e.g. "18.166667"g),
                // a different precision than inventory's own 3-decimal-place
                // base units, so this is passed through as-is rather than
                // round-tripped through InventoryDecimal::units()/quantity(),
                // which only accepts up to 3 decimal places.
                'quantity' => (string) $row->quantity,
                'unit' => $row->unit_code,
                'condition' => null,
            ]);

        $modifierLines = DB::table('modifier_option_recipe_profile_components as c')
            ->join('modifier_option_recipe_profiles as profile', 'profile.id', '=', 'c.modifier_option_recipe_profile_id')
            ->join('modifier_options as o', 'o.id', '=', 'profile.modifier_option_id')
            ->leftJoin('products as p', 'p.id', '=', 'profile.product_id')
            ->leftJoin('product_variants as v', 'v.id', '=', 'profile.product_variant_id')
            ->where('c.tenant_id', $tenant)
            ->where('c.inventory_item_id', $item)
            ->get(['o.id as option_id', 'o.name as option_name', 'o.is_available', 'profile.scope_type', 'p.name as product_name', 'v.name as variant_name', 'c.operation', 'c.quantity', 'c.unit_code'])
            ->map(fn (object $row) => [
                'source' => 'modifier_option',
                'productId' => null,
                'productName' => $row->product_name ?? $row->variant_name,
                'variantId' => null,
                'variantName' => $row->option_name,
                'isActive' => (bool) $row->is_available,
                'quantity' => (string) $row->quantity,
                'unit' => $row->unit_code,
                'condition' => $row->operation === 'remove' ? 'يُزال عند اختيار الإضافة' : 'يُضاف عند اختيار الإضافة',
            ]);

        $all = $variantLines->concat($modifierLines)->sortBy('productName')->values();
        $perPage = min(max((int) $request->query('perPage', 50), 1), 200);
        $page = max(1, (int) $request->query('page', 1));

        return response()->json([
            'data' => $all->forPage($page, $perPage)->values(),
            'meta' => ['currentPage' => $page, 'perPage' => $perPage, 'total' => $all->count(), 'lastPage' => max(1, (int) ceil($all->count() / $perPage))],
        ]);
    }

    /**
     * Read-only "سجل الشراء" tab data. `purchase_receipt_lines` is the one
     * unambiguous "a purchase actually moved this item's stock" record: it
     * is created 1:1 with the `stock_movements` row it produces
     * (referenceType='purchase_receipt_line', see PurchaseReceivingService)
     * and only exists once its parent goods receipt is posted, so a single
     * purchase can never be counted twice here even though the invoice line
     * it came from may be split across several receipts.
     */
    public function purchaseHistory(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->items->find($tenant, $item);
        $query = DB::table('purchase_receipt_lines as l')
            ->join('purchase_receipts as r', 'r.id', '=', 'l.purchase_receipt_id')
            ->join('supplier_invoices as si', 'si.id', '=', 'r.supplier_invoice_id')
            ->join('suppliers as s', 's.id', '=', 'si.supplier_id')
            ->join('warehouses as w', 'w.id', '=', 'l.warehouse_id')
            ->where('l.tenant_id', $tenant)
            ->where('l.inventory_item_id', $item)
            ->where('r.status', 'posted');
        InventoryAccess::scopeWarehouseBranches($query, $request, 'w.branch_id');
        $paginator = $query
            ->orderByDesc('r.receipt_date')
            ->orderByDesc('l.id')
            ->paginate(
                min(max((int) $request->query('perPage', 25), 1), 100),
                ['l.*', 'r.receipt_number', 'r.receipt_date', 's.name as supplier_name', 'si.invoice_number', 'si.invoice_date', 'w.name as warehouse_name'],
                'page',
                max(1, (int) $request->query('page', 1)),
            );

        return response()->json([
            'data' => collect($paginator->items())->map(fn (object $row) => [
                'receiptId' => (int) $row->purchase_receipt_id,
                'receiptNumber' => $row->receipt_number,
                'receiptDate' => $row->receipt_date,
                'supplierName' => $row->supplier_name,
                'invoiceNumber' => $row->invoice_number,
                'invoiceDate' => $row->invoice_date,
                'warehouseName' => $row->warehouse_name,
                'quantity' => InventoryDecimal::quantity(InventoryDecimal::units($row->received_quantity)),
                'unit' => $row->received_unit,
                'unitCost' => InventoryDecimal::unitCost(InventoryDecimal::cost($row->unit_cost)),
                'lineTotal' => InventoryDecimal::totalCost(InventoryDecimal::units($row->received_quantity), InventoryDecimal::cost($row->unit_cost)),
            ])->values(),
            'meta' => $this->meta($paginator),
        ]);
    }

    private function serialize(int $tenant, object $item, bool $detail = false): array
    {
        // Must mirror the same warehouse scope as $data['stockByWarehouse']
        // below (active, not soft-deleted, not a read-only LEGACY-% bucket):
        // a bare unscoped SUM() here previously let stock sitting in a
        // read-only legacy warehouse (invisible in the per-warehouse
        // breakdown) drag this aggregate's stockStatus into out_of_stock
        // even though every warehouse the user can actually see was
        // positive - see docs/client_feedback_review_2026-09-22.md (E4).
        $totals = isset($item->total_quantity)
            ? $item
            : DB::table('stock_balances as balances')
                ->join('warehouses as warehouses', 'warehouses.id', '=', 'balances.warehouse_id')
                ->where('balances.tenant_id', $tenant)
                ->where('balances.inventory_item_id', $item->id)
                ->where('warehouses.is_active', true)
                ->whereNull('warehouses.deleted_at')
                ->where('warehouses.code', 'not like', 'LEGACY-%')
                ->selectRaw('COALESCE(SUM(balances.quantity_on_hand), 0) as total_quantity')
                ->selectRaw('COALESCE(SUM(balances.quantity_on_hand - balances.reserved_quantity), 0) as available_quantity')
                ->selectRaw('COALESCE(SUM(balances.quantity_on_hand * balances.average_unit_cost), 0) as total_value')
                ->first();
        $availableQuantity = (float) ($totals->available_quantity ?? 0);
        $stockStatus = ! $item->is_active || in_array($item->item_type, ['non_stock_item', 'service'], true)
            ? ($item->is_active ? 'active' : 'inactive')
            : ($availableQuantity <= 0
                ? 'out_of_stock'
                : ($availableQuantity <= (float) $item->reorder_level ? 'low_stock' : 'active'));
        $data = ['id' => (int) $item->id, 'nameAr' => $item->name_ar, 'nameEn' => $item->name_en, 'displayName' => $item->name_en ?: $item->sku, 'sku' => $item->sku, 'barcode' => $item->barcode, 'itemType' => $item->item_type, 'category' => $item->category, 'unit' => $item->unit, 'purchaseUnit' => $item->purchase_unit ?? null, 'consumptionUnit' => $item->consumption_unit ?? null, 'minimumStock' => InventoryDecimal::quantity(InventoryDecimal::units($item->minimum_stock)), 'reorderLevel' => InventoryDecimal::quantity(InventoryDecimal::units($item->reorder_level)), 'latestUnitCost' => InventoryDecimal::unitCost(InventoryDecimal::cost($item->latest_unit_cost)), 'lastPurchaseCost' => $item->last_purchase_cost === null ? null : InventoryDecimal::unitCost(InventoryDecimal::cost($item->last_purchase_cost, 'lastPurchaseCost')), 'preferredSupplierName' => $item->preferred_supplier_name ?? null, 'trackExpiry' => (bool) ($item->track_expiry ?? false), 'trackBatch' => (bool) ($item->track_batch ?? false), 'stockStatus' => $stockStatus, 'lastUpdatedAt' => $item->updated_at, 'totalQuantity' => number_format((float) ($totals->total_quantity ?? 0), 3, '.', ''), 'availableQuantity' => number_format($availableQuantity, 3, '.', ''), 'totalValue' => number_format((float) ($totals->total_value ?? 0), 2, '.', ''), 'isActive' => (bool) $item->is_active, 'notes' => $item->notes];
        if ($detail) {
            $data['warehouseIds'] = Schema::hasTable('inventory_item_warehouses') ? DB::table('inventory_item_warehouses')
                ->where('tenant_id', $tenant)
                ->where('inventory_item_id', $item->id)
                ->orderBy('warehouse_id')
                ->pluck('warehouse_id')
                ->map(fn ($id) => (int) $id)
                ->values() : collect();
            $data['stockByWarehouse'] = DB::table('stock_balances as balances')->join('warehouses as warehouses', 'warehouses.id', '=', 'balances.warehouse_id')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('balances.tenant_id', $tenant)->where('balances.inventory_item_id', $item->id)->whereNull('warehouses.deleted_at')->where('warehouses.is_active', true)->where('warehouses.code', 'not like', 'LEGACY-%')->orderByRaw('CASE WHEN warehouses.branch_id IS NULL THEN 0 ELSE 1 END')->orderBy('branches.name')->orderBy('warehouses.name')->get(['balances.*', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code', 'warehouses.type as warehouse_type', 'branches.name as branch_name'])->map(fn (object $row) => $this->balance($row))->values();
            $data['recentMovements'] = DB::table('stock_movements as movements')->join('warehouses as warehouses', 'warehouses.id', '=', 'movements.warehouse_id')->where('movements.tenant_id', $tenant)->where('movements.inventory_item_id', $item->id)->whereNull('warehouses.deleted_at')->where('warehouses.code', 'not like', 'LEGACY-%')->orderByDesc('movements.occurred_at')->orderByDesc('movements.id')->limit(5)->get(['movements.*', 'warehouses.name as warehouse_name'])->map(fn (object $row) => $this->movement($row, $item))->values();
            $data['lastMovement'] = $data['recentMovements']->first();
        }

        return $data;
    }

    private function balance(object $row): array
    {
        return ['warehouseId' => (int) $row->warehouse_id, 'warehouseName' => $row->warehouse_name, 'warehouseCode' => $row->warehouse_code, 'branchName' => $row->branch_name, 'displayWarehouseName' => WarehousePresentation::displayName($row->branch_name, $row->warehouse_type), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($row->warehouse_type), 'quantityOnHand' => $row->quantity_on_hand, 'reservedQuantity' => $row->reserved_quantity, 'availableQuantity' => number_format((float) $row->quantity_on_hand - (float) $row->reserved_quantity, 3, '.', ''), 'averageUnitCost' => $row->average_unit_cost, 'totalValue' => number_format((float) $row->quantity_on_hand * (float) $row->average_unit_cost, 2, '.', ''), 'lastMovementAt' => $row->last_movement_at];
    }

    private function movement(object $row, ?object $item = null): array
    {
        return ['id' => (int) $row->id, 'warehouseName' => $row->warehouse_name, 'itemNameEn' => $item->name_en ?? null, 'itemNameAr' => $item->name_ar ?? null, 'unit' => $item->unit ?? null, 'type' => $row->type, 'quantityIn' => $row->quantity_in, 'quantityOut' => $row->quantity_out, 'quantityBefore' => $row->quantity_before, 'quantityAfter' => $row->quantity_after, 'unitCost' => $row->unit_cost, 'totalCost' => $row->total_cost, 'reason' => $row->reason, 'referenceType' => $row->reference_type ?? null, 'referenceId' => isset($row->reference_id) && $row->reference_id ? (int) $row->reference_id : null, 'userName' => $row->user_name ?? null, 'occurredAt' => $row->occurred_at, 'createdAt' => $row->created_at ?? null];
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
