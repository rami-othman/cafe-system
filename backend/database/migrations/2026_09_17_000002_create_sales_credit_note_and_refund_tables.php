<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sales_credit_notes', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('branch_id')->constrained()->restrictOnDelete();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->foreignId('original_sales_invoice_id')->constrained('sales_invoices')->restrictOnDelete();
            $table->string('credit_note_number', 64);
            $table->date('credit_date');
            $table->string('reason', 500)->nullable();
            $table->string('status', 32)->default('draft');
            $table->decimal('subtotal', 14, 2)->default(0);
            $table->decimal('tax_total', 14, 2)->default(0);
            $table->decimal('total', 14, 2)->default(0);
            // Fixed at posting time: how much of `total` reduced the original
            // invoice's AR versus became unapplied customer credit (never a
            // negative AR — see docs/sales Phase 4 ADR "Paid Invoice Case").
            $table->decimal('ar_reduction_amount', 14, 2)->nullable();
            $table->decimal('customer_credit_amount', 14, 2)->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('request_fingerprint', 64)->nullable();
            $table->foreignId('posted_journal_entry_id')->nullable()->constrained('journal_entries')->restrictOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('posted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('posted_at')->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'credit_note_number']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->index(['tenant_id', 'branch_id', 'status', 'credit_date']);
            $table->index(['tenant_id', 'customer_id']);
            $table->index(['tenant_id', 'original_sales_invoice_id']);
        });

        Schema::create('sales_credit_note_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_credit_note_id')->constrained()->cascadeOnDelete();
            $table->foreignId('original_sales_invoice_line_id')->constrained('sales_invoice_lines')->restrictOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('line_number');
            $table->string('product_name', 255);
            $table->string('product_sku', 128)->nullable();
            $table->decimal('quantity', 15, 3);
            $table->decimal('unit_price', 14, 2);
            $table->decimal('tax_rate', 8, 6)->default(0);
            $table->decimal('tax_total', 14, 2)->default(0);
            $table->decimal('subtotal', 14, 2)->default(0);
            $table->decimal('total', 14, 2)->default(0);
            // Per line, not per document: a service line and a damaged-goods
            // line can coexist in one Credit Note with different dispositions
            // (§16). True only for inventory-tracked lines; forced false for
            // service/non-tracked products.
            $table->boolean('restock')->default(false);
            $table->decimal('cogs_total', 14, 2)->nullable();
            $table->timestamps();
            $table->unique(['sales_credit_note_id', 'line_number']);
            $table->index(['tenant_id', 'original_sales_invoice_line_id']);
        });

        Schema::create('sales_credit_note_costs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_credit_note_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_credit_note_line_id')->nullable()->constrained('sales_credit_note_lines')->cascadeOnDelete();
            $table->foreignId('inventory_movement_id')->nullable()->constrained('stock_movements')->restrictOnDelete();
            $table->decimal('cost_amount', 14, 2);
            $table->timestamps();
            $table->index(['tenant_id', 'sales_credit_note_id']);
        });

        Schema::create('sales_credit_note_postings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_credit_note_id')->constrained()->cascadeOnDelete();
            $table->string('idempotency_key', 128);
            $table->string('request_fingerprint', 64);
            $table->foreignId('journal_entry_id')->constrained()->restrictOnDelete();
            $table->foreignId('posted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['tenant_id', 'sales_credit_note_id']);
            $table->unique(['tenant_id', 'idempotency_key']);
        });

        Schema::create('customer_refunds', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->constrained()->restrictOnDelete();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->string('refund_number', 40);
            $table->date('refund_date');
            $table->decimal('amount', 14, 2);
            $table->foreignId('payment_method_id')->constrained('payment_methods')->restrictOnDelete();
            $table->foreignId('financial_location_id')->constrained('financial_locations')->restrictOnDelete();
            $table->string('external_reference', 120)->nullable();
            $table->text('notes')->nullable();
            $table->string('status', 20)->default('posted');
            $table->string('idempotency_key', 120)->nullable();
            $table->string('idempotency_fingerprint', 64)->nullable();
            $table->foreignId('journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['tenant_id', 'refund_number']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->index(['tenant_id', 'customer_id', 'status']);
            $table->index(['tenant_id', 'branch_id', 'refund_date']);
        });

        // The customer-credit subledger (§10): a Credit Note grants credit
        // (positive), a Customer Refund consumes it (negative). Balance is
        // always SUM(amount) — never a stored column — mirroring how AR
        // itself is derived rather than cached (see CustomerCreditQueryService).
        Schema::create('customer_credit_ledger', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->foreignId('sales_credit_note_id')->nullable()->constrained('sales_credit_notes')->restrictOnDelete();
            $table->foreignId('customer_refund_id')->nullable()->constrained('customer_refunds')->restrictOnDelete();
            $table->decimal('amount', 14, 2);
            $table->timestamps();
            $table->index(['tenant_id', 'customer_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_credit_ledger');
        Schema::dropIfExists('customer_refunds');
        Schema::dropIfExists('sales_credit_note_postings');
        Schema::dropIfExists('sales_credit_note_costs');
        Schema::dropIfExists('sales_credit_note_lines');
        Schema::dropIfExists('sales_credit_notes');
    }
};
