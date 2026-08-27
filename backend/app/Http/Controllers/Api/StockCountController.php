<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StockCountLineRequest;
use App\Http\Requests\Api\V1\StockCountRequest;
use App\Services\StockCountService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use App\Support\WarehousePresentation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StockCountController extends Controller
{
    public function __construct(private readonly StockCountService $counts) {}

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

        return response()->json(['data' => $this->serialize($tenant, $this->counts->find($tenant, $count), true)]);
    }

    public function line(StockCountLineRequest $request, int $count): JsonResponse
    {
        $tenant = TenantContext::id($request);
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
        abort_unless(in_array($action, ['start', 'submit', 'approve', 'post', 'cancel'], true), 404);
        $this->counts->transition($request, $tenant, $count, $action, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serialize($tenant, $this->counts->find($tenant, $count), true)]);
    }

    private function serialize(int $tenant, object $count, bool $detail = false): array
    {
        $warehouse = DB::table('warehouses as warehouses')->leftJoin('branches as branches', 'branches.id', '=', 'warehouses.branch_id')->where('warehouses.id', $count->warehouse_id)->select('warehouses.name', 'warehouses.code', 'warehouses.type', 'branches.name as branch_name')->first();
        $data = ['id' => (int) $count->id, 'number' => 'SC-'.str_pad((string) $count->id, 5, '0', STR_PAD_LEFT), 'warehouseId' => (int) $count->warehouse_id, 'warehouseName' => $warehouse?->name, 'warehouseCode' => $warehouse?->code, 'displayWarehouseName' => WarehousePresentation::displayName($warehouse?->branch_name, $warehouse?->type ?? 'central'), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($warehouse?->type ?? 'central'), 'countDate' => $count->count_date, 'countType' => $count->count_type ?? 'full', 'categoryFilters' => $count->category_filters ? json_decode($count->category_filters, true) : [], 'status' => $count->status, 'notes' => $count->notes, 'countedBy' => $count->counted_by ? (int) $count->counted_by : null, 'createdByName' => $count->creator_name ?? null, 'approvedBy' => $count->approved_by ? (int) $count->approved_by : null, 'submittedAt' => $count->submitted_at, 'approvedAt' => $count->approved_at, 'postedAt' => $count->posted_at, 'totalItems' => (int) ($count->total_items ?? 0), 'countedItems' => (int) ($count->counted_items ?? 0), 'varianceItems' => (int) ($count->variance_items ?? 0), 'varianceValue' => number_format((float) ($count->variance_value ?? 0), 2, '.', '')];
        if ($detail) {
            $data['lines'] = DB::table('stock_count_lines as lines')->join('inventory_items as items', 'items.id', '=', 'lines.inventory_item_id')->where('lines.tenant_id', $tenant)->where('lines.stock_count_id', $count->id)->orderBy('items.name_en')->get(['lines.*', 'items.name_ar', 'items.name_en', 'items.sku', 'items.unit'])->map(fn (object $line) => ['id' => (int) $line->id, 'itemId' => (int) $line->inventory_item_id, 'itemNameAr' => $line->name_ar, 'itemNameEn' => $line->name_en ?: $line->name_ar, 'sku' => $line->sku, 'unit' => $line->unit, 'expectedQuantity' => $line->expected_quantity, 'countedQuantity' => $line->counted_quantity, 'varianceQuantity' => $line->variance_quantity, 'averageUnitCost' => $line->average_unit_cost ?? '0.0000', 'varianceValue' => number_format((float) $line->variance_quantity * (float) ($line->average_unit_cost ?? 0), 2, '.', ''), 'isCounted' => $line->counted_at !== null, 'reason' => $line->reason])->values();
        }

        return $data;
    }
}
