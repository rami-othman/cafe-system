<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Existing demo balances were created before warehouse availability was
     * introduced. A balance is authoritative evidence that the material is
     * available in that warehouse, so create the matching availability record.
     */
    public function up(): void
    {
        if (! Schema::hasTable('stock_balances') || ! Schema::hasTable('inventory_item_warehouses')) {
            return;
        }

        $now = now();
        DB::table('stock_balances')
            ->select(['tenant_id', 'warehouse_id', 'inventory_item_id'])
            ->orderBy('id')
            ->each(function (object $balance) use ($now): void {
                DB::table('inventory_item_warehouses')->updateOrInsert(
                    [
                        'tenant_id' => $balance->tenant_id,
                        'warehouse_id' => $balance->warehouse_id,
                        'inventory_item_id' => $balance->inventory_item_id,
                    ],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            });
    }

    public function down(): void
    {
        // Availability links can be edited independently after migration, so
        // they are intentionally preserved when rolling back this data fix.
    }
};
