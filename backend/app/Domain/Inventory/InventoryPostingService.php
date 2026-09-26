<?php

namespace App\Domain\Inventory;

use App\Services\OperationalAuditService;
use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\PaymentPerformanceProbe;
use App\Support\WarehousePresentation;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class InventoryPostingService
{
    private const INCOMING = ['opening_balance', 'stock_in', 'adjustment_in', 'transfer_in', 'return_in', 'production_output', 'conversion_output'];

    public function __construct(
        private readonly OperationalAuditService $audit,
        private readonly UnitConversionResolver $conversions,
        private readonly InventoryAccountingMapper $accounting,
        private readonly InventoryWarehouseAssignment $assignments,
        private readonly PaymentPerformanceProbe $performance,
    ) {}

    public function post(Request $request, int $tenantId, array $data, ?int $actorId): MovementPostingResult
    {
        $key = $data['idempotencyKey'] ?? null;
        if ($key !== null) {
            $existing = $this->byIdempotencyKey($tenantId, $key);
            if ($existing !== null) {
                return new MovementPostingResult($existing, true);
            }
        }

        try {
            return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $key): MovementPostingResult {
                if ($key !== null) {
                    $existing = $this->byIdempotencyKey($tenantId, $key, true);
                    if ($existing !== null) {
                        return new MovementPostingResult($existing, true);
                    }
                }
                $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $data['warehouseId'])->where('is_active', true)->whereNull('deleted_at')->lockForUpdate()->first();
                $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $data['itemId'])->whereNull('deleted_at')->first();
                if (! $warehouse || ! $item) {
                    throw ValidationException::withMessages(['warehouseId' => 'The warehouse or item does not belong to the current tenant.']);
                }
                $this->assignments->assertAssigned($tenantId, (int) $item->id, (int) $warehouse->id);
                if (WarehousePresentation::isLegacy($warehouse->code)) {
                    throw ValidationException::withMessages(['warehouseId' => 'Legacy warehouses are read-only and cannot receive new movements.']);
                }
                if (! empty($data['branchId']) && (int) $data['branchId'] !== (int) $warehouse->branch_id) {
                    throw ValidationException::withMessages(['branchId' => 'The selected branch does not match the warehouse.']);
                }
                FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);

                $converted = $this->conversions->resolve($tenantId, $item, $data['quantity'], $data['unit'] ?? null);
                if ($converted['baseQuantity'] <= 0) {
                    throw ValidationException::withMessages(['quantity' => 'Quantity must be greater than zero.']);
                }
                if (in_array($data['type'], ['adjustment_in', 'adjustment_out', 'waste', 'stock_count_variance'], true) && blank($data['reason'] ?? null)) {
                    throw ValidationException::withMessages(['reason' => 'A reason is required for this movement.']);
                }

                $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id])->lockForUpdate()->first();
                if (! $balance) {
                    DB::table('stock_balances')->insert(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id, 'quantity_on_hand' => '0.000', 'reserved_quantity' => '0.000', 'average_unit_cost' => '0.0000', 'created_at' => now(), 'updated_at' => now()]);
                    $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id])->lockForUpdate()->first();
                }

                $incoming = in_array($data['type'], self::INCOMING, true) || ($data['type'] === 'stock_count_variance' && ($data['countDirection'] ?? null) === 'in');
                $before = InventoryDecimal::signedUnits($balance->quantity_on_hand);
                $reserved = InventoryDecimal::units($balance->reserved_quantity);
                $quantity = $converted['baseQuantity'];
                // A dispatched transfer has already reserved this quantity under
                // the same balance lock. It may consume its own reservation,
                // while every other outbound movement remains availability-bound.
                $outboundLimit = ! empty($data['consumeReservation']) ? $before : $before - $reserved;
                if (! $incoming && $quantity > $outboundLimit && empty($data['allowNegativeStock'])) {
                    throw ValidationException::withMessages(['quantity' => 'The requested quantity exceeds available stock.']);
                }
                $oldCost = InventoryDecimal::cost($balance->average_unit_cost);
                $inputCost = InventoryDecimal::cost($data['unitCost'] ?? $item->latest_unit_cost);
                // A Manufacturing reversal removes an untouched, identified batch
                // at that batch's original cost. This internal flag is never part
                // of StockMovementRequest's public validated input.
                $reversalOutput = $data['type'] === 'stock_out'
                    && ($data['referenceType'] ?? null) === 'manufacturing_order_reversal'
                    && ! empty($data['revalueAfterRemoval']);
                $cost = ($incoming || $reversalOutput) ? $inputCost : $oldCost;
                $after = $incoming ? $before + $quantity : $before - $quantity;
                if (! $incoming) {
                    $average = $reversalOutput
                        ? ($after > 0 ? max(0, intdiv($before * $oldCost - $quantity * $cost, $after)) : 0)
                        : $oldCost;
                } elseif ($before < 0) {
                    // Incoming stock first settles a POS-created deficit. There
                    // is no positive inventory pool to average until the
                    // receipt crosses back above zero.
                    $average = $after > 0 ? $inputCost : ($oldCost > 0 ? $oldCost : $inputCost);
                } else {
                    $average = intdiv(($before * $oldCost) + ($quantity * $inputCost), max($after, 1));
                }
                $now = now();

                DB::table('stock_balances')->where('id', $balance->id)->update(['quantity_on_hand' => InventoryDecimal::quantity($after), 'average_unit_cost' => InventoryDecimal::unitCost($average), 'last_movement_at' => $now, 'updated_at' => $now]);
                $itemUpdate = [
                    'latest_unit_cost' => InventoryDecimal::unitCost($incoming ? $inputCost : $average),
                    'cost_per_unit' => InventoryDecimal::unitCost($incoming ? $inputCost : $average),
                    'updated_at' => $now,
                ];
                // `stock_in` is the purchase-receiving movement. It is the
                // authoritative place to record the most recent buy price.
                if ($data['type'] === 'stock_in' && ($data['referenceType'] ?? null) !== 'manufacturing_order_reversal') {
                    $itemUpdate['last_purchase_cost'] = InventoryDecimal::unitCost($inputCost);
                }
                DB::table('inventory_items')->where('id', $item->id)->update($itemUpdate);
                $id = (int) $this->performance->measure('stock movement creation', fn () => DB::table('stock_movements')->insertGetId(['tenant_id' => $tenantId, 'branch_id' => $data['branchId'] ?? $warehouse->branch_id, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id, 'type' => $data['type'], 'quantity' => InventoryDecimal::quantity($quantity), 'input_unit' => $converted['inputUnit'], 'conversion_factor' => InventoryDecimal::conversionFactor($converted['factor']), 'base_quantity' => InventoryDecimal::quantity($quantity), 'idempotency_key' => $key, 'quantity_in' => InventoryDecimal::quantity($incoming ? $quantity : 0), 'quantity_out' => InventoryDecimal::quantity($incoming ? 0 : $quantity), 'quantity_before' => InventoryDecimal::quantity($before), 'quantity_after' => InventoryDecimal::quantity($after), 'unit_cost' => InventoryDecimal::unitCost($cost), 'total_cost' => InventoryDecimal::totalCost($quantity, $cost), 'reason' => $data['reason'] ?? null, 'reference_type' => $data['referenceType'] ?? null, 'reference_id' => $data['referenceId'] ?? null, 'created_by' => $actorId, 'occurred_at' => $data['occurredAt'] ?? $now, 'created_at' => $now, 'updated_at' => $now]));
                $movement = DB::table('stock_movements')->where('tenant_id', $tenantId)->where('id', $id)->first();
                $impact = $this->accounting->postForFinalMovement($request, $tenantId, $movement, $actorId);
                $this->audit->record($request, $tenantId, 'stock_movement.posted', 'stock_movement', $id, [], ['type' => $data['type'], 'quantityBefore' => InventoryDecimal::quantity($before), 'quantityAfter' => InventoryDecimal::quantity($after), 'financeImpact' => $impact['classification']], $warehouse->branch_id, $actorId);

                // Manufacturing reversal handles its own batch's remaining_quantity
                // explicitly (it must target that specific order's batch, not
                // whichever batch FEFO would pick) — skip the generic decrement here
                // to avoid double-counting or decrementing the wrong batch.
                if (! $incoming && in_array($item->item_type, ['semi_finished_good', 'finished_good'], true)
                    && ($data['referenceType'] ?? null) !== 'manufacturing_order_reversal') {
                    $this->decrementManufacturingBatchesFefo($tenantId, (int) $warehouse->id, (int) $item->id, $quantity);
                }

                return new MovementPostingResult($id);
            });
        } catch (QueryException $exception) {
            if ($key !== null && ($existing = $this->byIdempotencyKey($tenantId, $key)) !== null) {
                return new MovementPostingResult($existing, true);
            }
            throw $exception;
        }
    }

    /** Reserve or release base-unit stock without creating a movement. */
    public function adjustReservation(int $tenantId, int $warehouseId, int $itemId, int $delta): void
    {
        DB::transaction(function () use ($tenantId, $warehouseId, $itemId, $delta): void {
            $this->assignments->assertAssigned($tenantId, $itemId, $warehouseId, 'lines');
            $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouseId, 'inventory_item_id' => $itemId])->lockForUpdate()->first();
            if (! $balance) {
                throw ValidationException::withMessages(['lines' => 'No stock balance exists for this transfer item.']);
            }
            $onHand = InventoryDecimal::signedUnits($balance->quantity_on_hand);
            $reserved = InventoryDecimal::units($balance->reserved_quantity);
            $after = $reserved + $delta;
            if ($after < 0 || ($delta > 0 && $delta > $onHand - $reserved)) {
                throw ValidationException::withMessages(['lines' => 'Insufficient available stock to reserve this transfer.']);
            }
            DB::table('stock_balances')->where('id', $balance->id)->update(['reserved_quantity' => InventoryDecimal::quantity($after), 'updated_at' => now()]);
        });
    }

    /**
     * Additive, Manufacturing-scoped lot tracking. Decrements manufacturing_batches
     * rows FEFO (earliest expiry first, then oldest production date) for outbound
     * finished and semi-finished goods. Items with no manufacturing_batches row
     * are unaffected by the lookup. It never
     * blocks the movement and never affects quantity_on_hand/WAC — it is purely
     * a parallel remaining-quantity bookkeeping ledger for batch/expiry reporting
     * and reversal eligibility.
     */
    private function decrementManufacturingBatchesFefo(int $tenantId, int $warehouseId, int $itemId, int $quantityBaseUnits): void
    {
        $remainingToConsume = $quantityBaseUnits;
        $batches = DB::table('manufacturing_batches')
            ->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)
            ->where('remaining_quantity', '>', 0)
            ->orderByRaw('expiry_date IS NULL, expiry_date ASC, production_date ASC')
            ->lockForUpdate()->get();

        foreach ($batches as $batch) {
            if ($remainingToConsume <= 0) {
                break;
            }
            $batchRemaining = InventoryDecimal::signedUnits($batch->remaining_quantity);
            $take = min($batchRemaining, $remainingToConsume);
            if ($take <= 0) {
                continue;
            }
            DB::table('manufacturing_batches')->where('id', $batch->id)->update([
                'remaining_quantity' => InventoryDecimal::quantity($batchRemaining - $take),
                'updated_at' => now(),
            ]);
            $remainingToConsume -= $take;
        }
        // If $remainingToConsume > 0 here, the outbound quantity exceeded the sum
        // of known batch remaining quantities (e.g. stock pre-dating batch
        // tracking, or a manual adjustment). That is expected and not an error —
        // batches only ever floor at 0, they never go negative.
    }

    private function byIdempotencyKey(int $tenantId, string $key, bool $lock = false): ?int
    {
        $query = DB::table('stock_movements')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) {
            $query->lockForUpdate();
        }
        $id = $query->value('id');

        return $id === null ? null : (int) $id;
    }
}
