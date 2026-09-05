<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouse_transfers', function (Blueprint $table): void {
            $table->foreignId('cancelled_by')->nullable()->after('closed_by')->constrained('users')->nullOnDelete();
            $table->timestamp('cancelled_at')->nullable()->after('closed_at');
            $table->string('cancellation_reason', 1000)->nullable()->after('shortage_reason');
        });
        Schema::create('warehouse_transfer_transit_balances', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('warehouse_transfer_line_id')->constrained()->cascadeOnDelete();
            $table->decimal('quantity_in_transit', 18, 3)->default(0); $table->timestamps(); $table->unique(['tenant_id', 'warehouse_transfer_line_id']);
        });
        Schema::create('warehouse_transfer_transit_movements', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('warehouse_transfer_id')->constrained()->cascadeOnDelete(); $table->foreignId('warehouse_transfer_line_id')->constrained()->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained(); $table->foreignId('source_warehouse_id')->constrained('warehouses'); $table->foreignId('destination_warehouse_id')->constrained('warehouses');
            $table->string('type', 32); $table->decimal('quantity', 18, 3); $table->decimal('quantity_before', 18, 3); $table->decimal('quantity_after', 18, 3); $table->string('reason', 1000)->nullable(); $table->string('idempotency_key', 120); $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete(); $table->timestamp('occurred_at'); $table->timestamps();
            $table->unique(['tenant_id', 'idempotency_key']); $table->index(['tenant_id', 'warehouse_transfer_id', 'warehouse_transfer_line_id']);
        });
    }
    public function down(): void { Schema::dropIfExists('warehouse_transfer_transit_movements'); Schema::dropIfExists('warehouse_transfer_transit_balances'); Schema::table('warehouse_transfers', function (Blueprint $table): void { $table->dropConstrainedForeignId('cancelled_by'); $table->dropColumn(['cancelled_at', 'cancellation_reason']); }); }
};
