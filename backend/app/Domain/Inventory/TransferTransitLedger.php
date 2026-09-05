<?php

namespace App\Domain\Inventory;

use App\Support\InventoryDecimal;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Immutable per-transfer-line in-transit ledger. Physical balances remain owned by InventoryPostingService. */
final class TransferTransitLedger
{
    public function dispatch(int $tenant, object $transfer, object $line, int $quantity, ?int $actor): void
    {
        $this->change($tenant, $transfer, $line, 'dispatch', $quantity, 'Warehouse transfer dispatched', $actor, "transfer-{$transfer->id}-transit-dispatch-line-{$line->id}");
    }

    public function receipt(int $tenant, object $transfer, object $line, int $quantity, ?int $actor, int $receiptId): void
    {
        $this->change($tenant, $transfer, $line, 'receipt', -$quantity, 'Warehouse transfer received', $actor, "transfer-{$transfer->id}-transit-receipt-{$receiptId}-line-{$line->id}");
    }

    public function shortage(int $tenant, object $transfer, object $line, int $quantity, string $reason, ?int $actor): void
    {
        $this->change($tenant, $transfer, $line, 'shortage', -$quantity, $reason, $actor, "transfer-{$transfer->id}-transit-shortage-line-{$line->id}");
    }

    private function change(int $tenant, object $transfer, object $line, string $type, int $delta, string $reason, ?int $actor, string $key): void
    {
        if (DB::table('warehouse_transfer_transit_movements')->where('tenant_id', $tenant)->where('idempotency_key', $key)->exists()) return;
        $balance = DB::table('warehouse_transfer_transit_balances')->where('tenant_id', $tenant)->where('warehouse_transfer_line_id', $line->id)->lockForUpdate()->first();
        if (! $balance) {
            DB::table('warehouse_transfer_transit_balances')->insert(['tenant_id' => $tenant, 'warehouse_transfer_line_id' => $line->id, 'quantity_in_transit' => '0.000', 'created_at' => now(), 'updated_at' => now()]);
            $balance = DB::table('warehouse_transfer_transit_balances')->where('tenant_id', $tenant)->where('warehouse_transfer_line_id', $line->id)->lockForUpdate()->first();
        }
        $before = InventoryDecimal::units($balance->quantity_in_transit);
        $after = $before + $delta;
        if ($after < 0) throw ValidationException::withMessages(['lines' => 'Transfer in-transit quantity cannot become negative.']);
        DB::table('warehouse_transfer_transit_balances')->where('id', $balance->id)->update(['quantity_in_transit' => InventoryDecimal::quantity($after), 'updated_at' => now()]);
        DB::table('warehouse_transfer_transit_movements')->insert(['tenant_id' => $tenant, 'warehouse_transfer_id' => $transfer->id, 'warehouse_transfer_line_id' => $line->id, 'inventory_item_id' => $line->inventory_item_id, 'source_warehouse_id' => $transfer->source_warehouse_id, 'destination_warehouse_id' => $transfer->destination_warehouse_id, 'type' => $type, 'quantity' => InventoryDecimal::quantity(abs($delta)), 'quantity_before' => InventoryDecimal::quantity($before), 'quantity_after' => InventoryDecimal::quantity($after), 'reason' => $reason, 'idempotency_key' => $key, 'created_by' => $actor, 'occurred_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
    }
}
