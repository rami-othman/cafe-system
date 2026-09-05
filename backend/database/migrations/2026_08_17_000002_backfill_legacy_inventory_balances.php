<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('stock_movements')->whereNotNull('warehouse_id')->orderBy('id')->get()->each(function (object $movement): void {
            $balance = DB::table('stock_balances')->where(['tenant_id' => $movement->tenant_id, 'warehouse_id' => $movement->warehouse_id, 'inventory_item_id' => $movement->inventory_item_id])->first();
            if ($balance) {
                return;
            }
            $quantity = (float) $movement->quantity_in - (float) $movement->quantity_out;
            if ($quantity < 0) {
                $quantity = 0;
            }
            DB::table('stock_balances')->insert(['tenant_id' => $movement->tenant_id, 'warehouse_id' => $movement->warehouse_id, 'inventory_item_id' => $movement->inventory_item_id, 'quantity_on_hand' => number_format($quantity, 3, '.', ''), 'reserved_quantity' => 0, 'average_unit_cost' => $movement->unit_cost, 'last_movement_at' => $movement->occurred_at ?? $movement->created_at, 'created_at' => now(), 'updated_at' => now()]);
        });
    }

    public function down(): void {}
};
