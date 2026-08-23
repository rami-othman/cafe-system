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
        $query = DB::table('stock_counts as counts')->join('warehouses as warehouses', 'warehouses.id', '=', 'counts.warehouse_id')->where('counts.tenant_id', $tenant)->where('warehouses.code', 'not like', 'LEGACY-%')->select('counts.*', 'warehouses.name as warehouse_name', 'warehouses.code as warehouse_code');
        foreach (['status' => 'counts.status', 'warehouseId' => 'counts.warehouse_id'] as $key => $column) {
            if ($request->filled($key)) {
                $query->where($column, $request->query($key));
            }
        }
        $paginator = $query->orderByDesc('counts.count_date')->orderByDesc('counts.id')->paginate(min(max((int) $request->query('perPage', 25), 1), 100));

        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($tenant, $row))->values(), 'meta' => ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]]);
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
        $this->counts->upsertLine($tenant, $count, $request->validated());

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
        $data = ['id' => (int) $count->id, 'warehouseId' => (int) $count->warehouse_id, 'warehouseName' => $warehouse?->name, 'warehouseCode' => $warehouse?->code, 'displayWarehouseName' => WarehousePresentation::displayName($warehouse?->branch_name, $warehouse?->type ?? 'central'), 'warehouseTypeLabel' => WarehousePresentation::typeLabel($warehouse?->type ?? 'central'), 'countDate' => $count->count_date, 'status' => $count->status, 'notes' => $count->notes, 'countedBy' => $count->counted_by ? (int) $count->counted_by : null, 'approvedBy' => $count->approved_by ? (int) $count->approved_by : null, 'submittedAt' => $count->submitted_at, 'approvedAt' => $count->approved_at, 'postedAt' => $count->posted_at];
        if ($detail) {
            $data['lines'] = DB::table('stock_count_lines as lines')->join('inventory_items as items', 'items.id', '=', 'lines.inventory_item_id')->where('lines.tenant_id', $tenant)->where('lines.stock_count_id', $count->id)->orderBy('items.name_en')->get(['lines.*', 'items.name_ar', 'items.name_en', 'items.unit'])->map(fn (object $line) => ['id' => (int) $line->id, 'itemId' => (int) $line->inventory_item_id, 'itemNameAr' => $line->name_ar, 'itemNameEn' => $line->name_en ?: $line->name_ar, 'unit' => $line->unit, 'expectedQuantity' => $line->expected_quantity, 'countedQuantity' => $line->counted_quantity, 'varianceQuantity' => $line->variance_quantity, 'reason' => $line->reason])->values();
        }

        return $data;
    }
}
