<?php

namespace App\Services;

use App\Models\User;
use App\Support\WarehousePresentation;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/**
 * The Cashier's operational stock list for the effective POS warehouse.
 *
 * Intentionally a separate read model from InventoryBalanceController::index,
 * which serialises averageUnitCost and totalValue. Those are valuation figures
 * a Cashier must not see, so this query never selects the cost columns at all
 * rather than selecting and then stripping them.
 *
 * Scope is the single warehouse PosInventoryWarehouseResolver resolves for a
 * branch the caller may already access; there is no warehouse parameter, so a
 * caller cannot point this at another branch's warehouse.
 */
class CashierInventoryQueryService
{
    public const STATE_NORMAL = 'normal';

    public const STATE_LOW = 'low';

    public const STATE_ZERO = 'zero';

    public const STATE_NEGATIVE = 'negative';

    public function __construct(
        private readonly PosInventoryWarehouseResolver $posWarehouses,
        private readonly BranchAccessService $branches,
    ) {}

    /**
     * @param  string|null  $state  one of the STATE_* values, or null for all
     * @return array<string, mixed>
     */
    public function list(User $actor, ?int $requestedBranchId, ?string $search, ?string $state, int $page, int $perPage): array
    {
        $tenantId = (int) $actor->tenant_id;
        $accessible = $this->branches->accessibleBranchIds($actor);
        $branchId = $requestedBranchId !== null
            ? (in_array($requestedBranchId, $accessible, true) ? $requestedBranchId : null)
            : (count($accessible) === 1 ? $accessible[0] : $this->branchOfOpenShift($tenantId, $actor, $accessible));

        if ($branchId === null) {
            return $this->empty();
        }

        $resolved = $this->posWarehouses->resolveForDashboard($tenantId, $branchId);
        if ($resolved['id'] === null) {
            return [...$this->empty(), 'branchId' => $branchId, 'ambiguous' => $resolved['ambiguous']];
        }

        $branchName = DB::table('branches')->where('id', $branchId)->value('name');

        $query = DB::table('stock_balances as balances')
            ->join('inventory_items as items', 'items.id', '=', 'balances.inventory_item_id')
            ->where('balances.tenant_id', $tenantId)
            ->where('balances.warehouse_id', $resolved['id'])
            ->where('items.is_active', true)
            ->whereNull('items.deleted_at');

        if ($search !== null && $search !== '') {
            $like = '%'.mb_strtolower($search).'%';
            $query->where(fn (Builder $scope) => $scope
                ->whereRaw('LOWER(items.name_ar) LIKE ?', [$like])
                ->orWhereRaw('LOWER(items.name_en) LIKE ?', [$like])
                ->orWhereRaw('LOWER(items.sku) LIKE ?', [$like]));
        }

        match ($state) {
            self::STATE_NEGATIVE => $query->where('balances.quantity_on_hand', '<', 0),
            self::STATE_ZERO => $query->where('balances.quantity_on_hand', '=', 0),
            self::STATE_LOW => $query->where('balances.quantity_on_hand', '>', 0)->whereColumn('balances.quantity_on_hand', '<=', 'items.reorder_level'),
            self::STATE_NORMAL => $query->where('balances.quantity_on_hand', '>', 0)->whereColumn('balances.quantity_on_hand', '>', 'items.reorder_level'),
            default => null,
        };

        $paginator = $query
            ->orderByRaw('CASE WHEN balances.quantity_on_hand < 0 THEN 0 WHEN balances.quantity_on_hand = 0 THEN 1 WHEN balances.quantity_on_hand <= items.reorder_level THEN 2 ELSE 3 END')
            ->orderBy('items.name_ar')
            ->orderBy('items.id')
            ->paginate($perPage, [
                'balances.inventory_item_id', 'balances.quantity_on_hand', 'balances.last_movement_at',
                'items.name_ar', 'items.name_en', 'items.sku', 'items.unit', 'items.reorder_level',
            ], 'page', $page);

        return [
            'branchId' => $branchId,
            'warehouseId' => (int) $resolved['id'],
            'warehouseName' => WarehousePresentation::displayName($branchName, $resolved['row']->type),
            'warehouseTypeLabel' => WarehousePresentation::typeLabel($resolved['row']->type),
            'configured' => true,
            'ambiguous' => false,
            'items' => collect($paginator->items())->map(fn (object $row) => [
                'itemId' => (int) $row->inventory_item_id,
                'nameAr' => $row->name_ar,
                'nameEn' => $row->name_en ?: $row->sku,
                'sku' => $row->sku,
                'unit' => $row->unit,
                'quantity' => number_format((float) $row->quantity_on_hand, 3, '.', ''),
                'state' => $this->stateFor((float) $row->quantity_on_hand, (float) $row->reorder_level),
                'lastMovementAt' => $row->last_movement_at,
            ])->values()->all(),
            'meta' => [
                'currentPage' => $paginator->currentPage(),
                'perPage' => $paginator->perPage(),
                'total' => $paginator->total(),
                'lastPage' => $paginator->lastPage(),
            ],
        ];
    }

    private function stateFor(float $quantity, float $reorderLevel): string
    {
        return match (true) {
            $quantity < 0 => self::STATE_NEGATIVE,
            $quantity === 0.0 => self::STATE_ZERO,
            $quantity <= $reorderLevel => self::STATE_LOW,
            default => self::STATE_NORMAL,
        };
    }

    private function branchOfOpenShift(int $tenantId, User $actor, array $accessible): ?int
    {
        if ($accessible === []) {
            return null;
        }

        $branchId = DB::table('shifts')
            ->where('tenant_id', $tenantId)->where('user_id', $actor->id)
            ->whereIn('branch_id', $accessible)->where('status', 'open')->whereNull('deleted_at')
            ->latest('opened_at')->value('branch_id');

        return $branchId === null ? null : (int) $branchId;
    }

    /** @return array<string, mixed> */
    private function empty(): array
    {
        return [
            'branchId' => null, 'warehouseId' => null, 'warehouseName' => null, 'warehouseTypeLabel' => null,
            'configured' => false, 'ambiguous' => false, 'items' => [],
            'meta' => ['currentPage' => 1, 'perPage' => 0, 'total' => 0, 'lastPage' => 1],
        ];
    }
}
