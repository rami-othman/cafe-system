<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouse_transfers', function (Blueprint $table): void {
            $table->string('idempotency_key', 120)->nullable()->after('status');
            $table->text('shortage_reason')->nullable()->after('rejection_reason');
            $table->foreignId('closed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('rejected_at')->nullable();
            $table->timestamp('closed_at')->nullable();
            $table->unique(['tenant_id', 'idempotency_key'], 'warehouse_transfers_tenant_idempotency_unique');
        });
        Schema::table('warehouse_transfer_lines', function (Blueprint $table): void {
            $table->decimal('requested_base_quantity', 15, 3)->default(0)->after('requested_quantity');
            $table->decimal('requested_conversion_factor', 18, 6)->default(1)->after('requested_base_quantity');
            $table->decimal('reserved_quantity', 15, 3)->default(0)->after('requested_conversion_factor');
            $table->decimal('dispatched_base_quantity', 15, 3)->default(0)->after('dispatched_quantity');
            $table->decimal('received_base_quantity', 15, 3)->default(0)->after('received_quantity');
            $table->decimal('shortage_closed_quantity', 15, 3)->default(0)->after('resolved_quantity');
        });
        Schema::create('warehouse_transfer_operations', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained();
            $table->foreignId('warehouse_transfer_id')->constrained()->cascadeOnDelete();
            $table->string('operation', 30); $table->string('idempotency_key', 120);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['warehouse_transfer_id', 'operation', 'idempotency_key'], 'warehouse_transfer_operation_idempotency_unique');
        });
        Schema::create('warehouse_transfer_receipt_lines', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained();
            $table->foreignId('warehouse_transfer_receipt_id')->constrained('warehouse_transfer_receipts')->cascadeOnDelete();
            $table->foreignId('warehouse_transfer_line_id')->constrained('warehouse_transfer_lines')->cascadeOnDelete();
            $table->decimal('entered_quantity', 15, 3); $table->string('entered_unit', 40);
            $table->decimal('conversion_factor', 18, 6); $table->decimal('base_quantity', 15, 3);
            $table->foreignId('stock_movement_id')->nullable()->constrained('stock_movements')->nullOnDelete();
            $table->text('discrepancy_reason')->nullable(); $table->timestamps();
        });
    }
    public function down(): void
    {
        Schema::dropIfExists('warehouse_transfer_receipt_lines'); Schema::dropIfExists('warehouse_transfer_operations');
        Schema::table('warehouse_transfer_lines', function (Blueprint $table): void { $table->dropColumn(['requested_base_quantity', 'requested_conversion_factor', 'reserved_quantity', 'dispatched_base_quantity', 'received_base_quantity', 'shortage_closed_quantity']); });
        Schema::table('warehouse_transfers', function (Blueprint $table): void { $table->dropUnique('warehouse_transfers_tenant_idempotency_unique'); $table->dropConstrainedForeignId('closed_by'); $table->dropColumn(['idempotency_key', 'shortage_reason', 'rejected_at', 'closed_at']); });
    }
};
