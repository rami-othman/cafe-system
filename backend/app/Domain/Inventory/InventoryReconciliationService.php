<?php

namespace App\Domain\Inventory;

use App\Support\InventoryDecimal;
use Illuminate\Support\Facades\DB;

/** Read-only movement-to-balance reconciliation; it never repairs data. */
final class InventoryReconciliationService
{
    public function dryRun(?int $tenantId = null, ?int $warehouseId = null, ?int $itemId = null): array
    {
        $expected = [];
        $movements = DB::table('stock_movements')->when($tenantId !== null, fn ($q) => $q->where('tenant_id', $tenantId))->when($warehouseId !== null, fn ($q) => $q->where('warehouse_id', $warehouseId))->when($itemId !== null, fn ($q) => $q->where('inventory_item_id', $itemId))->orderBy('id')->get(['tenant_id', 'warehouse_id', 'inventory_item_id', 'quantity_in', 'quantity_out']);
        foreach ($movements as $movement) {
            $key = $movement->tenant_id.':'.$movement->warehouse_id.':'.$movement->inventory_item_id;
            $expected[$key] = ($expected[$key] ?? 0) + InventoryDecimal::units($movement->quantity_in) - InventoryDecimal::units($movement->quantity_out);
        }
        $balances = DB::table('stock_balances')->when($tenantId !== null, fn ($q) => $q->where('tenant_id', $tenantId))->when($warehouseId !== null, fn ($q) => $q->where('warehouse_id', $warehouseId))->when($itemId !== null, fn ($q) => $q->where('inventory_item_id', $itemId))->get();
        foreach ($balances as $balance) $expected[$balance->tenant_id.':'.$balance->warehouse_id.':'.$balance->inventory_item_id] ??= 0;
        $differences = [];
        foreach ($expected as $key => $movementQuantity) {
            [$tenant, $warehouse, $item] = array_map('intval', explode(':', $key));
            $balance = $balances->first(fn (object $row) => (int) $row->tenant_id === $tenant && (int) $row->warehouse_id === $warehouse && (int) $row->inventory_item_id === $item);
            $actual = $balance ? InventoryDecimal::units($balance->quantity_on_hand) : 0;
            if ($movementQuantity !== $actual) $differences[] = ['tenantId' => $tenant, 'warehouseId' => $warehouse, 'itemId' => $item, 'movementQuantity' => InventoryDecimal::quantity($movementQuantity), 'balanceQuantity' => InventoryDecimal::quantity($actual), 'difference' => InventoryDecimal::quantity($actual - $movementQuantity)];
        }
        $transferDifferences = [];
        if (DB::getSchemaBuilder()->hasTable('warehouse_transfer_transit_balances')) {
            $lines = DB::table('warehouse_transfer_lines as lines')->join('warehouse_transfers as transfers', 'transfers.id', '=', 'lines.warehouse_transfer_id')->leftJoin('warehouse_transfer_transit_balances as transit', 'transit.warehouse_transfer_line_id', '=', 'lines.id')->when($tenantId !== null, fn ($q) => $q->where('transfers.tenant_id', $tenantId))->whereIn('transfers.status', ['dispatched', 'partially_received', 'received', 'closed_shortage'])->get(['lines.id', 'lines.dispatched_base_quantity', 'lines.received_base_quantity', 'lines.shortage_closed_quantity', 'transit.quantity_in_transit']);
            foreach ($lines as $line) {
                $expectedTransit = InventoryDecimal::units($line->dispatched_base_quantity) - InventoryDecimal::units($line->received_base_quantity) - InventoryDecimal::units($line->shortage_closed_quantity);
                $actualTransit = InventoryDecimal::units($line->quantity_in_transit ?? '0');
                if ($expectedTransit !== $actualTransit) $transferDifferences[] = ['transferLineId' => (int) $line->id, 'expectedInTransit' => InventoryDecimal::quantity($expectedTransit), 'actualInTransit' => InventoryDecimal::quantity($actualTransit)];
            }
        }
        return ['checked' => count($expected), 'differences' => $differences, 'transferTransitDifferences' => $transferDifferences];
    }
}
