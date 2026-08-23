<?php

namespace App\Services;

use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\WarehousePresentation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class StockMovementService
{
    private const INCOMING = ['opening_balance', 'stock_in', 'adjustment_in', 'transfer_in', 'return_in'];

    public function __construct(private readonly OperationalAuditService $audit) {}

    public function record(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $data, $actorId): int {
            $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $data['warehouseId'])->where('is_active', true)->whereNull('deleted_at')->first();
            $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $data['itemId'])->whereNull('deleted_at')->first();
            if (! $warehouse || ! $item) {
                throw ValidationException::withMessages(['warehouseId' => 'المخزن أو الصنف لا يتبعان للمنشأة الحالية.']);
            }
            if (WarehousePresentation::isLegacy($warehouse->code)) {
                throw ValidationException::withMessages(['warehouseId' => 'Legacy warehouses are read-only and cannot receive new movements.']);
            }
            if (! empty($data['branchId']) && (int) $data['branchId'] !== (int) $warehouse->branch_id) {
                throw ValidationException::withMessages(['branchId' => 'الفرع المحدد لا يطابق المخزن.']);
            }
            FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);

            $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id])->lockForUpdate()->first();
            if (! $balance) {
                DB::table('stock_balances')->insert(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id, 'quantity_on_hand' => 0, 'reserved_quantity' => 0, 'average_unit_cost' => 0, 'created_at' => now(), 'updated_at' => now()]);
                $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id])->lockForUpdate()->first();
            }

            $type = $data['type'];
            $quantity = InventoryDecimal::units($data['quantity']);
            if ($quantity <= 0) {
                throw ValidationException::withMessages(['quantity' => 'يجب أن تكون الكمية أكبر من صفر.']);
            }
            if (in_array($type, ['adjustment_in', 'adjustment_out', 'waste', 'stock_count_variance'], true) && blank($data['reason'] ?? null)) {
                throw ValidationException::withMessages(['reason' => 'السبب مطلوب لهذه الحركة.']);
            }
            $incoming = in_array($type, self::INCOMING, true) || ($type === 'stock_count_variance' && ($data['countDirection'] ?? null) === 'in');
            $before = InventoryDecimal::units($balance->quantity_on_hand);
            $reserved = InventoryDecimal::units($balance->reserved_quantity);
            if (! $incoming && $quantity > $before - $reserved) {
                throw ValidationException::withMessages(['quantity' => 'الكمية المطلوبة أكبر من الرصيد المتاح في المخزن.']);
            }
            $oldCost = InventoryDecimal::cost($balance->average_unit_cost);
            $inputCost = InventoryDecimal::cost($data['unitCost'] ?? $item->latest_unit_cost);
            $cost = $incoming ? $inputCost : $oldCost;
            $after = $incoming ? $before + $quantity : $before - $quantity;
            $average = $incoming ? intdiv(($before * $oldCost) + ($quantity * $inputCost), max($after, 1)) : $oldCost;
            $now = now();

            DB::table('stock_balances')->where('id', $balance->id)->update(['quantity_on_hand' => InventoryDecimal::quantity($after), 'average_unit_cost' => InventoryDecimal::unitCost($average), 'last_movement_at' => $now, 'updated_at' => $now]);
            DB::table('inventory_items')->where('id', $item->id)->update(['latest_unit_cost' => InventoryDecimal::unitCost($incoming ? $inputCost : $average), 'cost_per_unit' => InventoryDecimal::unitCost($incoming ? $inputCost : $average), 'updated_at' => $now]);
            $id = (int) DB::table('stock_movements')->insertGetId(['tenant_id' => $tenantId, 'branch_id' => $data['branchId'] ?? $warehouse->branch_id, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $item->id, 'type' => $type, 'quantity' => InventoryDecimal::quantity($quantity), 'quantity_in' => InventoryDecimal::quantity($incoming ? $quantity : 0), 'quantity_out' => InventoryDecimal::quantity($incoming ? 0 : $quantity), 'quantity_before' => InventoryDecimal::quantity($before), 'quantity_after' => InventoryDecimal::quantity($after), 'unit_cost' => InventoryDecimal::unitCost($cost), 'total_cost' => InventoryDecimal::totalCost($quantity, $cost), 'reason' => $data['reason'] ?? null, 'reference_type' => $data['referenceType'] ?? null, 'reference_id' => $data['referenceId'] ?? null, 'created_by' => $actorId, 'occurred_at' => $data['occurredAt'] ?? $now, 'created_at' => $now, 'updated_at' => $now]);
            $this->audit->record($request, $tenantId, 'stock_movement.posted', 'stock_movement', $id, [], ['type' => $type, 'quantityBefore' => InventoryDecimal::quantity($before), 'quantityAfter' => InventoryDecimal::quantity($after)], $warehouse->branch_id, $actorId);

            return $id;
        });
    }
}
