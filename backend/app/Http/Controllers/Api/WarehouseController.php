<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\WarehouseRequest;
use App\Services\WarehouseService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use App\Support\WarehousePresentation;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WarehouseController extends Controller
{
    public function __construct(private readonly WarehouseService $warehouses) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $query = DB::table('warehouses')
            ->leftJoin('branches', function ($join): void {
                $join->on('branches.id', '=', 'warehouses.branch_id')->whereNull('branches.deleted_at');
            })
            ->where('warehouses.tenant_id', $tenantId)
            ->whereNull('warehouses.deleted_at')
            ->select('warehouses.*', 'branches.name as branch_name');
        if ($request->boolean('includeLegacy') !== true) {
            $query->where('warehouses.code', 'not like', 'LEGACY-%');
        }
        if ($request->filled('search')) {
            $search = '%'.strtolower((string) $request->query('search')).'%';
            $query->where(fn (Builder $items) => $items->whereRaw('LOWER(warehouses.name) LIKE ?', [$search])->orWhereRaw('LOWER(warehouses.code) LIKE ?', [$search]));
        }
        foreach (['branchId' => 'warehouses.branch_id', 'type' => 'warehouses.type'] as $parameter => $column) {
            if ($request->filled($parameter)) {
                $query->where($column, $request->query($parameter));
            }
        }
        if ($request->filled('status')) {
            $query->where('warehouses.is_active', $request->query('status') === 'active');
        }

        $paginator = $query->orderBy('branches.name')->orderBy('warehouses.type')->orderBy('warehouses.id')->paginate($this->perPage($request));

        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row))->values(), 'meta' => $this->meta($paginator)]);
    }

    public function store(WarehouseRequest $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $id = $this->warehouses->create($request, $tenantId, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serialize($this->withBranch($tenantId, $id))], 201);
    }

    public function update(WarehouseRequest $request, int $warehouse): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->warehouses->update($request, $tenantId, $warehouse, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serialize($this->withBranch($tenantId, $warehouse))]);
    }

    public function status(Request $request, int $warehouse): JsonResponse
    {
        $data = $request->validate(['isActive' => ['required', 'boolean']]);
        $tenantId = TenantContext::id($request);
        $this->warehouses->setStatus($request, $tenantId, $warehouse, (bool) $data['isActive'], FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serialize($this->withBranch($tenantId, $warehouse))]);
    }

    private function withBranch(int $tenantId, int $id): object
    {
        $row = DB::table('warehouses')->leftJoin('branches', 'branches.id', '=', 'warehouses.branch_id')->where('warehouses.tenant_id', $tenantId)->where('warehouses.id', $id)->whereNull('warehouses.deleted_at')->select('warehouses.*', 'branches.name as branch_name')->first();
        abort_unless($row, 404, 'Warehouse not found.');

        return $row;
    }

    private function serialize(object $row): array
    {
        return ['id' => (int) $row->id, 'branchId' => $row->branch_id ? (int) $row->branch_id : null, 'branchName' => $row->branch_name, 'name' => $row->name, 'displayName' => WarehousePresentation::displayName($row->branch_name, $row->type), 'code' => $row->code, 'type' => $row->type, 'typeLabel' => WarehousePresentation::typeLabel($row->type), 'isLegacy' => WarehousePresentation::isLegacy($row->code), 'isActive' => (bool) $row->is_active, 'notes' => $row->notes, 'createdAt' => $row->created_at, 'updatedAt' => $row->updated_at];
    }

    private function perPage(Request $request): int
    {
        return min(max((int) $request->query('perPage', 25), 1), 100);
    }

    private function meta($paginator): array
    {
        return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()];
    }
}
