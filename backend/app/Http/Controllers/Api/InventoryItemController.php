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
use App\Support\DataScope;
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
        $scope = DataScope::resolve($request);
        $branchId = $request->filled('branchId') ? (int) $request->query('branchId') : null;
        $warehouseId = $request->filled('warehouseId') ? (int) $request->query('warehouseId') : null;
        if ($scope !== null) $branchId = $scope;
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
        $actor = $request->attributes->get('auth_user');
        if (! ($actor->isOwner() && ! $branchId && $request->query('scope') === 'all')) {
            if ($actor->isOwner() && ! $branchId && $request->query('scope') === 'factory') $query->whereNotNull('items.owner_branch_id');
            else DataScope::apply($query, 'items.owner_branch_id', $scope);
        }
        if ($request->boolean('inStockOnly')) $query->whereRaw('COALESCE(stock_totals.available_quantity, 0) > 0');
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
        if ($request->filled('types')) {
            $data = $request->validate(['types' => ['array'], 'types.*' => ['string']]);
            $query->whereIn('items.item_type', $data['types']);
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
                'filters' => $this->filters($tenant, $scope),
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
        DataScope::apply($query, 'owner_branch_id', DataScope::resolve($request));
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
        $actor = InventoryAccess::actor($request);
        $detail = $actor->isOwner() || $actor->effectiveRoleCode() === 'factory_manager';

        return response()->json(['data' => $this->serialize($tenant, $this->scopedItem($request, $tenant, $item), $detail)]);
    }

    public function store(InventoryItemRequest $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $id = $this->items->save($request, $tenant, $request->validated(), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($tenant, $this->scopedItem($request, $tenant, $id), true)], 201);
    }

    public function update(InventoryItemRequest $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->items->save($request, $tenant, $request->validated(), FinancialActor::id($request, $tenant), $item);

        return response()->json(['data' => $this->serialize($tenant, $this->scopedItem($request, $tenant, $item), true)]);
    }

    public function status(Request $request, int $item): JsonResponse
    {
        $data = $request->validate(['isActive' => ['required', 'boolean']]);
        $tenant = TenantContext::id($request);
        $this->items->setStatus($request, $tenant, $item, (bool) $data['isActive'], FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($tenant, $this->scopedItem($request, $tenant, $item), true)]);
    }

    public function stock(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->scopedItem($request, $tenant, $item);
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
        $itemRow = $this->scopedItem($request, $tenant, $item);
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
        $material = $this->scopedItem($request, $tenant, $item);
        if ($material->owner_branch_id !== null) {
            $rows = DB::table('manufacturing_recipes as r')->join('manufacturing_recipe_versions as v', 'v.id', '=', 'r.current_version_id')
                ->join('inventory_items as p', 'p.id', '=', 'r.product_item_id')
                ->leftJoin('manufacturing_recipe_version_lines as l', 'l.manufacturing_recipe_version_id', '=', 'v.id')
                ->where('r.tenant_id', $tenant)->whereNull('r.deleted_at')->where('p.owner_branch_id', $material->owner_branch_id)
                ->where(fn ($q) => $q->where('r.product_item_id', $item)->orWhere('l.inventory_item_id', $item))
                ->get(['r.id', 'r.product_item_id', 'r.status', 'p.name_ar', 'v.version_number', 'v.output_quantity', 'v.output_unit', 'l.quantity', 'l.unit'])
                ->unique('id')->map(fn ($r) => [
                    'source' => 'manufacturing_recipe', 'productName' => $r->name_ar, 'variantName' => 'إصدار '.$r->version_number,
                    'isActive' => $r->status === 'active', 'quantity' => (int) $r->product_item_id === $item ? $r->output_quantity : $r->quantity,
                    'unit' => (int) $r->product_item_id === $item ? $r->output_unit : $r->unit, 'condition' => null,
                ])->values();
            return response()->json(['data' => $rows, 'meta' => ['currentPage' => 1, 'lastPage' => 1, 'total' => $rows->count()]]);
        }

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
        $hint = null;
        if ($all->isEmpty()) {
            $similar = DB::table('inventory_items as i')
                ->where('i.tenant_id', $tenant)->where('i.id', '!=', $item)->whereNull('i.deleted_at')
                ->where(function ($query) use ($material): void {
                    if ($material->sku) $query->where('i.sku', $material->sku);
                    if ($material->name_ar) $query->orWhere('i.name_ar', $material->name_ar);
                })->where(function ($query) use ($tenant): void {
                    $query->whereExists(fn ($q) => $q->selectRaw('1')->from('variant_recipe_components as c')->whereColumn('c.inventory_item_id', 'i.id')->where('c.tenant_id', $tenant))
                        ->orWhereExists(fn ($q) => $q->selectRaw('1')->from('modifier_option_recipe_profile_components as c')->whereColumn('c.inventory_item_id', 'i.id')->where('c.tenant_id', $tenant));
                })->first(['i.id']);
            if ($similar) {
                $count = DB::table('variant_recipe_components')->where('tenant_id', $tenant)->where('inventory_item_id', $similar->id)->distinct()->count('variant_recipe_id')
                    + DB::table('modifier_option_recipe_profile_components')->where('tenant_id', $tenant)->where('inventory_item_id', $similar->id)->distinct()->count('modifier_option_recipe_profile_id');
                $hint = "هذه المادة غير مستخدمة بوصفات، يوجد مادة مشابهة (#{$similar->id}) مستخدمة في {$count} وصفة";
            }
        }
        $perPage = min(max((int) $request->query('perPage', 50), 1), 200);
        $page = max(1, (int) $request->query('page', 1));

        return response()->json([
            'data' => $all->forPage($page, $perPage)->values(),
            'meta' => ['currentPage' => $page, 'perPage' => $perPage, 'total' => $all->count(), 'lastPage' => max(1, (int) ceil($all->count() / $perPage)), 'hint' => $hint],
        ]);
    }

    /** Purchase invoice lines include posted but not-yet-received purchases. */
    public function purchaseHistory(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $material = $this->scopedItem($request, $tenant, $item);
        $latestReceipts = DB::table('purchase_receipt_lines as rl')->join('purchase_receipts as r', 'r.id', '=', 'rl.purchase_receipt_id')
            ->where('r.tenant_id', $tenant)->where('r.status', 'posted')
            ->groupBy('rl.supplier_invoice_line_id')
            ->selectRaw('rl.supplier_invoice_line_id, MAX(r.id) as receipt_id');
        $query = DB::table('supplier_invoice_lines as l')
            ->join('supplier_invoices as i', 'i.id', '=', 'l.supplier_invoice_id')
            ->join('suppliers as s', 's.id', '=', 'i.supplier_id')
            ->leftJoin('warehouses as w', 'w.id', '=', 'l.warehouse_id')
            ->leftJoinSub($latestReceipts, 'latest_receipt', 'latest_receipt.supplier_invoice_line_id', '=', 'l.id')
            ->leftJoin('purchase_receipts as r', 'r.id', '=', 'latest_receipt.receipt_id')
            ->where('l.tenant_id', $tenant)->where('l.inventory_item_id', $item)
            ->whereNotIn('i.status', ['draft', 'cancelled'])->whereNull('i.deleted_at');
        if ($material->owner_branch_id !== null) $query->where('i.branch_id', $material->owner_branch_id);
        else InventoryAccess::scopeWarehouseBranches($query, $request, 'w.branch_id');
        $paginator = $query
            ->orderByDesc('i.invoice_date')
            ->orderByDesc('l.id')
            ->paginate(
                min(max((int) $request->query('perPage', 25), 1), 100),
                ['l.*', 'i.id as invoice_id', 'i.invoice_number', 'i.invoice_date', 'r.id as receipt_id', 'r.receipt_number', 'r.receipt_date', 's.name as supplier_name', 'w.name as warehouse_name'],
                'page',
                max(1, (int) $request->query('page', 1)),
            );

        return response()->json([
            'data' => collect($paginator->items())->map(fn (object $row) => [
                'invoiceId' => (int) $row->invoice_id,
                'receiptId' => $row->receipt_id ? (int) $row->receipt_id : null,
                'receiptNumber' => $row->receipt_number,
                'receiptDate' => $row->receipt_date,
                'supplierName' => $row->supplier_name,
                'invoiceNumber' => $row->invoice_number,
                'invoiceDate' => $row->invoice_date,
                'warehouseName' => $row->warehouse_name,
                'quantity' => $row->quantity,
                'unit' => $row->purchase_unit ?: $material->unit,
                'unitCost' => $row->unit_price,
                'lineTotal' => $row->line_total,
                'receivedQuantity' => $row->received_quantity,
                'receivedUnit' => $material->unit,
                'receiptStatus' => InventoryDecimal::units($row->received_quantity) >= InventoryDecimal::units($row->base_quantity ?? $row->quantity) ? 'received' : (InventoryDecimal::units($row->received_quantity) > 0 ? 'partial' : 'not_received'),
            ])->values(),
            'meta' => $this->meta($paginator),
        ]);
    }

    public function productionBatches(Request $request, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $material = $this->scopedItem($request, $tenant, $item);
        abort_if($material->owner_branch_id === null, 404);
        $page = DB::table('manufacturing_batches as b')->join('manufacturing_orders as o', 'o.id', '=', 'b.manufacturing_order_id')
            ->where('b.tenant_id', $tenant)->where('b.inventory_item_id', $item)->where('o.branch_id', $material->owner_branch_id)
            ->orderByDesc('b.id')->paginate($this->perPage($request), ['b.*', 'o.reference', 'o.actual_unit_cost']);
        return response()->json(['data' => $page->items(), 'meta' => $this->meta($page)]);
    }

    private function scopedItem(Request $request, int $tenant, int $id): object
    {
        $item = $this->items->find($tenant, $id);
        DataScope::assertOwned($item, DataScope::resolve($request));
        return $item;
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
        $data = ['ownerBranchId' => $item->owner_branch_id === null ? null : (int) $item->owner_branch_id, 'id' => (int) $item->id, 'nameAr' => $item->name_ar, 'nameEn' => $item->name_en, 'displayName' => $item->name_en ?: $item->sku, 'sku' => $item->sku, 'barcode' => $item->barcode, 'itemType' => $item->item_type, 'category' => $item->category, 'unit' => $item->unit, 'purchaseUnit' => $item->purchase_unit ?? null, 'consumptionUnit' => $item->consumption_unit ?? null, 'minimumStock' => InventoryDecimal::quantity(InventoryDecimal::units($item->minimum_stock)), 'reorderLevel' => InventoryDecimal::quantity(InventoryDecimal::units($item->reorder_level)), 'latestUnitCost' => InventoryDecimal::unitCost(InventoryDecimal::cost($item->latest_unit_cost)), 'lastPurchaseCost' => $item->last_purchase_cost === null ? null : InventoryDecimal::unitCost(InventoryDecimal::cost($item->last_purchase_cost, 'lastPurchaseCost')), 'preferredSupplierName' => $item->preferred_supplier_name ?? null, 'trackExpiry' => (bool) ($item->track_expiry ?? false), 'trackBatch' => (bool) ($item->track_batch ?? false), 'stockStatus' => $stockStatus, 'lastUpdatedAt' => $item->updated_at, 'totalQuantity' => number_format((float) ($totals->total_quantity ?? 0), 3, '.', ''), 'availableQuantity' => number_format($availableQuantity, 3, '.', ''), 'totalValue' => number_format((float) ($totals->total_value ?? 0), 2, '.', ''), 'isActive' => (bool) $item->is_active, 'notes' => $item->notes];
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
        $type = $row->reference_type ?? null;
        $id = isset($row->reference_id) && $row->reference_id ? (int) $row->reference_id : null;
        $document = null;
        if ($id && $type === 'purchase_receipt_line') {
            $document = DB::table('purchase_receipt_lines as l')->join('purchase_receipts as r', 'r.id', '=', 'l.purchase_receipt_id')
                ->where('l.tenant_id', $row->tenant_id)->where('l.id', $id)->first(['r.id', 'r.receipt_number as number']);
            $type = 'purchase_receipt';
        } elseif ($id && $type === 'sales_invoice_line') {
            $document = DB::table('sales_invoice_lines as l')->join('sales_invoices as i', 'i.id', '=', 'l.sales_invoice_id')
                ->where('l.tenant_id', $row->tenant_id)->where('l.id', $id)->first(['i.id', 'i.invoice_number as number']);
            $type = 'sales_invoice';
        } elseif ($id && $type === 'order_item') {
            $document = DB::table('order_items as l')->join('orders as o', 'o.id', '=', 'l.order_id')
                ->where('l.tenant_id', $row->tenant_id)->where('l.id', $id)->first(['o.id', 'o.order_number as number']);
            $type = 'order';
        }
        return ['id' => (int) $row->id, 'warehouseName' => $row->warehouse_name, 'itemNameEn' => $item->name_en ?? null, 'itemNameAr' => $item->name_ar ?? null, 'unit' => $item->unit ?? null, 'type' => $row->type, 'quantityIn' => $row->quantity_in, 'quantityOut' => $row->quantity_out, 'quantityBefore' => $row->quantity_before, 'quantityAfter' => $row->quantity_after, 'unitCost' => $row->unit_cost, 'totalCost' => $row->total_cost, 'reason' => $row->reason, 'referenceType' => $type, 'referenceId' => $document ? (int) $document->id : $id, 'referenceNumber' => $document->number ?? ($id ? (string) $id : null), 'userName' => $row->user_name ?? null, 'occurredAt' => $row->occurred_at, 'createdAt' => $row->created_at ?? null];
    }


    private function perPage(Request $request): int
    {
        return min(max((int) $request->query('perPage', 25), 1), 100);
    }

    private function meta($paginator): array
    {
        return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()];
    }

    private function filters(int $tenant, ?int $scope): array
    {
        $items = DB::table('inventory_items')
            ->where('tenant_id', $tenant)
            ->whereNull('deleted_at');

        DataScope::apply($items, 'owner_branch_id', $scope);
        return [
            'categories' => (clone $items)->whereNotNull('category')->where('category', '!=', '')->distinct()->orderBy('category')->pluck('category')->values(),
        ];
    }
}
