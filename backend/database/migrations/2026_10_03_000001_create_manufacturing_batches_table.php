<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-production-order lot/batch tracking, complementing (not replacing) the
 * existing stock_balances/stock_movements WAC ledger. One row is created per
 * manufacturing_orders completion (one output per order in this schema).
 *
 * remaining_quantity is decremented additively by InventoryPostingService::post()
 * for outbound movements of the same tenant+item+warehouse, FEFO-ordered across
 * any batches that exist for that item — see the "batch decrement" note in
 * InventoryPostingService. Items that never produced a manufacturing batch are
 * completely unaffected: the decrement is a no-op lookup when no batch row exists.
 *
 * Reversal reads remaining_quantity for the SPECIFIC order's batch (not
 * item-level on-hand), closing the "batch-blind" reversal gap.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('manufacturing_batches', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('manufacturing_order_id')->constrained('manufacturing_orders')->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained('inventory_items');
            $table->foreignId('warehouse_id')->constrained();
            $table->decimal('produced_quantity', 15, 3);
            $table->decimal('remaining_quantity', 15, 3);
            $table->date('production_date')->nullable();
            $table->date('expiry_date')->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'manufacturing_order_id'], 'manufacturing_batches_order_unique');
            // FEFO lookup: for a given tenant+item+warehouse, consume the batch
            // with the earliest expiry first (nulls last), then oldest production date.
            $table->index(['tenant_id', 'inventory_item_id', 'warehouse_id', 'expiry_date'], 'manufacturing_batches_fefo_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('manufacturing_batches');
    }
};
