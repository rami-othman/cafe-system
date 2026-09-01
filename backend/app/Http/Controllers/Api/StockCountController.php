<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StockCountLineRequest;
use App\Http\Requests\Api\V1\StockCountRequest;
use App\Services\StockCountService;
use App\Domain\Inventory\InventoryAccountingMapper;
use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\InventoryAccess;
use App\Support\TenantContext;
use App\Support\WarehousePresentation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StockCountController extends Controller
{
    public function __construct(private readonly StockCountService $counts, private readonly InventoryAccountingMapper $accounting) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $lineTotals = DB::table('stock_count_lines')
            ->selectRaw('stock_count_id, COUNT(*) as total_items, SUM(CASE WHEN counted_at IS NOT NULL THEN 1 ELSE 0 END) as counted_items, SUM(CASE WHEN variance_quantity <> 0 THEN 1 ELSE 0 END) as variance_items, COALESCE(SUM(variance_quantity * average_unit_cost), 0) as variance_value')
            ->groupBy('stock_count_id');
        $query = DB::table('stock_counts as counts')
            ->join('warehouses as warehouses', 'warehouses.id', '=', 'counts.warehouse_id')
            ->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')
            ->leftJoin('users as creator', 'creator.id', '=', 'counts.counted_by')
            ->leftJoinSub($lineTotals, 'line_totals', fn ($join) => $join->on('line_totals.stock_count_id', '=', 'counts.id'))
            ->where('counts.tenant_id', $tenant)
            ->where('warehouses.code', 'not like', 'LEGACY-%')
            ->select('counts.*', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code', 'branches.name as branch_name', 'creator.name as creator_name', 'line_totals.total_items', 'line_totals.counted_items', 'line_totals.variance_items', 'line_totals.variance_value');
        InventoryAccess::scopeWarehouseBranches($query, $request, 'warehouses.branch_id');
        foreach (['status' => 'counts.status', 'warehouseId' => 'counts.warehouse_id', 'countType' => 'counts.count_type', 'branchId' => 'warehouses.branch_id'] as $key => $column) {
            if ($request->filled($key)) {
                $query->where($column, $request->query($key));
            }
        }
        if ($request->query('source') === 'administrative') {
            $query->where('counts.count_type', '<>', 'shift_check');
        } elseif ($request->query('source') === 'shift_pos') {
            $query->where('counts.count_type', 'shift_check');
        }
        if ($request->filled('from')) {
            $query->whereDate('counts.count_date', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('counts.count_date', '<=', $request->query('to'));
        }
        $creatorOptions = (clone $query)
            ->whereNotNull('counts.counted_by')
            ->whereNotNull('creator.name')
            // Select only comparable scalar columns before DISTINCT. `counts.*`
            // includes category_filters (json), which PostgreSQL cannot compare.
            ->select('counts.counted_by as id', 'creator.name')
            ->distinct()
            ->orderBy('creator.name')
            ->get();
        if ($request->filled('createdBy')) {
            $query->where('counts.counted_by', $request->query('createdBy'));
        }
        $summaryQuery = clone $query;
        $summary = $summaryQuery->select([])->selectRaw("SUM(CASE WHEN counts.status = 'draft' THEN 1 ELSE 0 END) as drafts, SUM(CASE WHEN counts.status = 'in_progress' THEN 1 ELSE 0 END) as in_progress, SUM(CASE WHEN counts.status = 'submitted' THEN 1 ELSE 0 END) as submitted, SUM(CASE WHEN counts.status = 'approved' THEN 1 ELSE 0 END) as approved")->first();
        $paginator = $query->orderByDesc('counts.count_date')->orderByDesc('counts.id')->paginate(min(max((int) $request->query('perPage', 25), 1), 100));

        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($tenant, $row))->values(), 'meta' => ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage(), 'summary' => ['drafts' => (int) ($summary->drafts ?? 0), 'inProgress' => (int) ($summary->in_progress ?? 0), 'submitted' => (int) ($summary->submitted ?? 0), 'approved' => (int) ($summary->approved ?? 0)], 'filterOptions' => ['createdBy' => $creatorOptions->map(fn (object $creator) => ['id' => (int) $creator->id, 'name' => $creator->name])->values()]]]);
    }

    public function store(StockCountRequest $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $id = $this->counts->create($request, $tenant, $request->validated(), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($tenant, $this->counts->find($tenant, $id))], 201);
    }

    public function show(Request $request, int $count): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->assertCountBranchAccess($request, $tenant, $count);

        return response()->json(['data' => $this->serialize($tenant, $this->counts->find($tenant, $count), true)]);
    }

    public function line(StockCountLineRequest $request, int $count): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->assertCountBranchAccess($request, $tenant, $count);
        $this->counts->upsertLine(
            $tenant,
            $count,
            $request->validated(),
            FinancialActor::id($request, $tenant),
        );

        return response()->json(['data' => $this->serialize($tenant, $this->counts->find($tenant, $count), true)]);
    }

    public function action(Request $request, int $count, string $action): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->assertCountBranchAccess($request, $tenant, $count);
        abort_unless(in_array($action, ['start', 'submit', 'approve', 'post', 'cancel'], true), 404);
        $this->counts->transition($request, $tenant, $count, $action, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($tenant, $this->counts->find($tenant, $count), true)]);
    }

    public function reviewLine(Request $request, int $count, int $item): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->assertCountBranchAccess($request, $tenant, $count);
        $data = $request->validate([
            'decision' => ['required', 'in:approved,rejected'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);
        $this->counts->reviewLine($request, $tenant, $count, $item, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($tenant, $this->counts->find($tenant, $count), true)]);
    }

    private function serialize(int $tenant, object $count, bool $detail = false): array
    {
        $warehouse = DB::table('warehouses as warehouses')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('warehouses.id', $count->warehouse_id)->select('warehouses.name', 'warehouses.code', 'warehouses.type', 'branches.name as branch_name')->first();
        $data = ['id' => (int) $count->id, 'number' => 'SC-'.str_pad((string) $count->id, 5, '0', STR_PAD_LEFT), 'warehouseId' => (int) $count->warehouse_id, 'warehouseName' => $warehouse?->name, 'warehouseCode' => $warehouse?->code, 'displayWarehouseName' => WarehousePresentation::displayName($warehouse?->branch_name, $warehouse?->type ?? 'central'), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($warehouse?->type ?? 'central'), 'countDate' => $count->count_date, 'countType' => $count->count_type ?? 'full', 'categoryFilters' => $count->category_filters ? json_decode($count->category_filters, true) : [], 'status' => $count->status, 'notes' => $count->notes, 'countedBy' => $count->counted_by ? (int) $count->counted_by : null, 'createdByName' => $count->creator_name ?? null, 'approvedBy' => $count->approved_by ? (int) $count->approved_by : null, 'submittedAt' => $count->submitted_at, 'approvedAt' => $count->approved_at, 'postedAt' => $count->posted_at, 'totalItems' => (int) ($count->total_items ?? 0), 'countedItems' => (int) ($count->counted_items ?? 0), 'varianceItems' => (int) ($count->variance_items ?? 0), 'varianceValue' => (string) ($count->variance_value ?? '0.00')];
        if ($detail) {
            $data['lines'] = DB::table('stock_count_lines as lines')->join('inventory_items as items', 'items.id', '=', 'lines.inventory_item_id')->where('lines.tenant_id', $tenant)->where('lines.stock_count_id', $count->id)->orderBy('items.name_en')->get(['lines.*', 'items.name_ar', 'items.name_en', 'items.sku', 'items.unit'])->map(function (object $line) use ($tenant, $count): array {
                $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('reference_type', 'stock_count')->where('reference_id', $count->id)->where('inventory_item_id', $line->inventory_item_id)->where('type', 'stock_count_variance')->orderByDesc('id')->first();
                $impact = $movement ? $this->accounting->impactForMovement($tenant, $movement) : ['status' => InventoryDecimal::signedUnits($line->variance_quantity) === 0 ? 'NOT_APPLICABLE' : 'PENDING', 'amount' => null, 'journalId' => null, 'journalReference' => null, 'classification' => 'STOCK_COUNT_VARIANCE', 'message' => null];
                return ['id' => (int) $line->id, 'itemId' => (int) $line->inventory_item_id, 'itemNameAr' => $line->name_ar, 'itemNameEn' => $line->name_en ?: $line->name_ar, 'sku' => $line->sku, 'unit' => $line->unit, 'countUnit' => $line->entered_unit ?: $line->unit, 'expectedQuantity' => $line->expected_quantity, 'countedQuantity' => $line->counted_quantity, 'enteredQuantity' => $line->entered_quantity, 'conversionFactor' => $line->conversion_factor, 'baseQuantity' => $line->base_quantity, 'varianceQuantity' => $line->variance_quantity, 'varianceStatus' => $line->variance_status, 'movementDirection' => InventoryDecimal::signedUnits($line->variance_quantity) > 0 ? 'in' : (InventoryDecimal::signedUnits($line->variance_quantity) < 0 ? 'out' : 'none'), 'isRequired' => (bool) $line->is_required, 'isCounted' => (bool) $line->is_counted, 'quantityTolerance' => $line->quantity_tolerance, 'toleranceType' => $line->tolerance_type, 'requiresReviewWhenExceeded' => (bool) $line->requires_review_when_exceeded, 'managerReviewStatus' => $line->manager_review_status, 'managerReviewedBy' => $line->manager_reviewed_by ? (int) $line->manager_reviewed_by : null, 'managerReviewedAt' => $line->manager_reviewed_at, 'managerReviewNotes' => $line->manager_review_notes, 'averageUnitCost' => $line->average_unit_cost ?? '0.0000', 'authoritativeUnitCost' => $movement?->unit_cost ?? $line->average_unit_cost ?? '0.0000', 'varianceValue' => InventoryDecimal::totalCost(InventoryDecimal::signedUnits($line->variance_quantity), InventoryDecimal::cost($line->average_unit_cost ?? '0')), 'financialImpactValue' => $movement?->total_cost, 'financeImpact' => $impact, 'reason' => $line->reason];
            })->values();
        }

        return $data;
    }

    private function assertCountBranchAccess(Request $request, int $tenant, int $count): void
    {
        $branchId = DB::table('stock_counts as counts')
            ->join('warehouses as warehouses', 'warehouses.id', '=', 'counts.warehouse_id')
            ->where('counts.tenant_id', $tenant)
            ->where('counts.id', $count)
            ->value('warehouses.branch_id');
        InventoryAccess::assertBranchAccess($request, $branchId ? (int) $branchId : null);
    }
}
