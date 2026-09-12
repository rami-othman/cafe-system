<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Purchasing Phase 2 — the Goods Receipt domain. A `purchase_receipt` is
     * an independent, auditable physical-stock record that references a
     * posted `supplier_invoice`'s lines; it is never itself a financial
     * document and creates zero GL journal entries (see
     * PurchaseReceivingService, which is the only caller allowed to move
     * these rows into `stock_movements` via InventoryPostingService).
     * `supplier_invoice_lines.received_quantity` remains the cached rollup
     * this domain maintains transactionally — these tables are the auditable
     * history behind that cache.
     */
    public function up(): void
    {
        Schema::create('purchase_receipts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('supplier_invoice_id')->constrained('supplier_invoices')->restrictOnDelete();
            $table->string('receipt_number', 40);
            $table->date('receipt_date');
            // 'draft' | 'posted' — draft lines are editable and have not
            // touched inventory; posting is the one-way, immutable action
            // that calls InventoryPostingService per line.
            $table->string('status', 20)->default('draft');
            $table->string('reference', 120)->nullable();
            $table->text('notes')->nullable();
            $table->string('idempotency_key', 120)->nullable();
            $table->string('idempotency_fingerprint', 64)->nullable();
            $table->string('posting_idempotency_key', 120)->nullable();
            $table->string('posting_idempotency_fingerprint', 64)->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('posted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('posted_at')->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'receipt_number']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->unique(['tenant_id', 'posting_idempotency_key']);
            $table->index(['tenant_id', 'supplier_invoice_id']);
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'branch_id', 'receipt_date']);
        });

        Schema::create('purchase_receipt_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('purchase_receipt_id')->constrained('purchase_receipts')->cascadeOnDelete();
            $table->foreignId('supplier_invoice_line_id')->constrained('supplier_invoice_lines')->restrictOnDelete();
            $table->foreignId('inventory_item_id')->constrained('inventory_items')->restrictOnDelete();
            $table->foreignId('warehouse_id')->constrained('warehouses')->restrictOnDelete();
            // Frozen at receipt-creation time from the invoice line's own
            // purchase_unit/conversion_factor — never re-resolved from
            // inventory_item_unit_conversions, so a later change to the
            // item's unit configuration can never rewrite a historical
            // receipt's quantities or cost.
            $table->string('received_unit', 40);
            $table->decimal('received_quantity', 15, 3);
            $table->decimal('conversion_factor', 18, 6);
            $table->decimal('base_quantity', 15, 3);
            $table->decimal('unit_cost', 15, 4);
            $table->foreignId('stock_movement_id')->nullable()->constrained('stock_movements')->nullOnDelete();
            $table->timestamps();
            $table->index(['tenant_id', 'purchase_receipt_id']);
            $table->index(['tenant_id', 'supplier_invoice_line_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('purchase_receipt_lines');
        Schema::dropIfExists('purchase_receipts');
    }
};
