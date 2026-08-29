<?php

namespace App\Domain\Inventory;

use App\Services\OperationalAuditService;
use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\WarehousePresentation;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class InventoryPostingService
{
    private const INCOMING = ['opening_balance', 'stock_in', 'adjustment_in', 'transfer_in', 'return_in'];

    public function __construct(
        private readonly OperationalAuditService $audit,
        private readonly UnitConversionResolver $conversions,
    ) {}

    public function post(Request $request, int $tenantId, array $data, ?int $actorId): MovementPostingResult
    {
        $key = $data['idempotencyKey'] ?? null;
        if ($key !== null) {
            $existing = $this->byIdempotencyKey($tenantId, $key);
            if ($existing !== null) return new MovementPostingResult($existing, true);
        }

        try {
            return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $key): MovementPostingResult {
                if ($key !== null) {
                    $existing = $this->byIdempotencyKey($tenantId, $key, true);
                    if ($existing !== null) return new MovementPostingResult($existing, true);
                }
                $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $data['warehouseId'])->where('is_active', true)->whereNull('deleted_at')->lockForUpdate()->first();
                $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $data['itemId'])->whereNull('deleted_at')->first();
                if (! $warehouse || ! $item) throw ValidationException::withMessages(['warehouseId' => 'The warehouse or item does not belong to the current tenant.']);
                if (WarehousePresentation::isLegacy($warehouse->code)) throw ValidationException::withMessages(['warehouseId' => 'Legacy warehouses are read-only and cannot receive new movements.']);
                if (! empty($data['branchId']) && (int) $data['branchId'] !== (int) $warehouse->branch_id) throw ValidationException::withMessages(['branchId' => 'The selected branch does not match the warehouse.']);
                FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);

                $converted = $this->conversions->resolve($tenantId, $item, $data['quantity'], $data['unit'] ?? null);
                if ($converted['baseQuantity'] <= 0) throw ValidationException::withMessages(['quantity' => 'Quantity must be greater than zero.']);
                if (in_array($data['type'], ['adjustment_in', 'adjustment_out', 'waste', 'stock_count_variance'], true) && blank($data['reason'] ?? null)) throw ValidationException::withMessages(['reason' => 'A reason is required for this movement.']);

                $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id])->lockForUpdate()->first();
                if (! $balance) {
                    DB::table('stock_balances')->insert(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id, 'quantity_on_hand' => '0.000', 'reserved_quantity' => '0.000', 'average_unit_cost' => '0.0000', 'created_at' => now(), 'updated_at' => now()]);
                    $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id])->lockForUpdate()->first();
                }

                $incoming = in_array($data['type'], self::INCOMING, true) || ($data['type'] === 'stock_count_variance' && ($data['countDirection'] ?? null) === 'in');
                $before = InventoryDecimal::units($balance->quantity_on_hand);
                $reserved = InventoryDecimal::units($balance->reserved_quantity);
                $quantity = $converted['baseQuantity'];
                // A dispatched transfer has already reserved this quantity under
                // the same balance lock. It may consume its own reservation,
                // while every other outbound movement remains availability-bound.
                $outboundLimit = ! empty($data['consumeReservation']) ? $before : $before - $reserved;
                if (! $incoming && $quantity > $outboundLimit) throw ValidationException::withMessages(['quantity' => 'The requested quantity exceeds available stock.']);
                $oldCost = InventoryDecimal::cost($balance->average_unit_cost);
                $inputCost = InventoryDecimal::cost($data['unitCost'] ?? $item->latest_unit_cost);
                $cost = $incoming ? $inputCost : $oldCost;
                $after = $incoming ? $before + $quantity : $before - $quantity;
                $average = $incoming ? intdiv(($before * $oldCost) + ($quantity * $inputCost), max($after, 1)) : $oldCost;
                $now = now();

                DB::table('stock_balances')->where('id', $balance->id)->update(['quantity_on_hand' => InventoryDecimal::quantity($after), 'average_unit_cost' => InventoryDecimal::unitCost($average), 'last_movement_at' => $now, 'updated_at' => $now]);
                DB::table('inventory_items')->where('id', $item->id)->update(['latest_unit_cost' => InventoryDecimal::unitCost($incoming ? $inputCost : $average), 'cost_per_unit' => InventoryDecimal::unitCost($incoming ? $inputCost : $average), 'updated_at' => $now]);
                $id = (int) DB::table('stock_movements')->insertGetId(['tenant_id' => $tenantId, 'branch_id' => $data['branchId'] ?? $warehouse->branch_id, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id, 'type' => $data['type'], 'quantity' => InventoryDecimal::quantity($quantity), 'input_unit' => $converted['inputUnit'], 'conversion_factor' => InventoryDecimal::conversionFactor($converted['factor']), 'base_quantity' => InventoryDecimal::quantity($quantity), 'idempotency_key' => $key, 'quantity_in' => InventoryDecimal::quantity($incoming ? $quantity : 0), 'quantity_out' => InventoryDecimal::quantity($incoming ? 0 : $quantity), 'quantity_before' => InventoryDecimal::quantity($before), 'quantity_after' => InventoryDecimal::quantity($after), 'unit_cost' => InventoryDecimal::unitCost($cost), 'total_cost' => InventoryDecimal::totalCost($quantity, $cost), 'reason' => $data['reason'] ?? null, 'reference_type' => $data['referenceType'] ?? null, 'reference_id' => $data['referenceId'] ?? null, 'created_by' => $actorId, 'occurred_at' => $data['occurredAt'] ?? $now, 'created_at' => $now, 'updated_at' => $now]);
                $this->audit->record($request, $tenantId, 'stock_movement.posted', 'stock_movement', $id, [], ['type' => $data['type'], 'quantityBefore' => InventoryDecimal::quantity($before), 'quantityAfter' => InventoryDecimal::quantity($after)], $warehouse->branch_id, $actorId);
                return new MovementPostingResult($id);
            });
        } catch (QueryException $exception) {
            if ($key !== null && ($existing = $this->byIdempotencyKey($tenantId, $key)) !== null) return new MovementPostingResult($existing, true);
            throw $exception;
        }
    }

    /** Reserve or release base-unit stock without creating a movement. */
    public function adjustReservation(int $tenantId, int $warehouseId, int $itemId, int $delta): void
    {
        DB::transaction(function () use ($tenantId, $warehouseId, $itemId, $delta): void {
            $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouseId, 'inventory_item_id' => $itemId])->lockForUpdate()->first();
            if (! $balance) throw ValidationException::withMessages(['lines' => 'No stock balance exists for this transfer item.']);
            $onHand = InventoryDecimal::units($balance->quantity_on_hand);
            $reserved = InventoryDecimal::units($balance->reserved_quantity);
            $after = $reserved + $delta;
            if ($after < 0 || ($delta > 0 && $delta > $onHand - $reserved)) throw ValidationException::withMessages(['lines' => 'Insufficient available stock to reserve this transfer.']);
            DB::table('stock_balances')->where('id', $balance->id)->update(['reserved_quantity' => InventoryDecimal::quantity($after), 'updated_at' => now()]);
        });
    }

    private function byIdempotencyKey(int $tenantId, string $key, bool $lock = false): ?int
    {
        $query = DB::table('stock_movements')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) $query->lockForUpdate();
        $id = $query->value('id');
        return $id === null ? null : (int) $id;
    }
}
