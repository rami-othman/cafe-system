<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_payments', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->constrained()->restrictOnDelete();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->string('payment_number', 40);
            $table->date('payment_date');
            $table->decimal('amount', 14, 2);
            $table->foreignId('payment_method_id')->constrained('payment_methods')->restrictOnDelete();
            $table->foreignId('financial_location_id')->constrained('financial_locations')->restrictOnDelete();
            $table->string('external_reference', 120)->nullable();
            $table->text('notes')->nullable();
            $table->string('status', 20)->default('posted');
            $table->string('idempotency_key', 120)->nullable();
            $table->string('idempotency_fingerprint', 64)->nullable();
            $table->foreignId('journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('reversal_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reversed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reversed_at')->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'payment_number']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->index(['tenant_id', 'customer_id', 'status']);
            $table->index(['tenant_id', 'branch_id', 'payment_date']);
        });

        Schema::create('customer_payment_allocations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('customer_payment_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_invoice_id')->constrained()->restrictOnDelete();
            $table->decimal('amount', 14, 2);
            $table->timestamps();

            $table->unique(['customer_payment_id', 'sales_invoice_id'], 'customer_payment_allocations_pair_unique');
            $table->index(['tenant_id', 'sales_invoice_id']);
        });

        // Reversal-safe history: a reversed payment's allocations are removed
        // from the live table (so today's remaining balance is correct again)
        // but retained here with the original payment_date and a reversed_at
        // marker, so an as-of-date AR snapshot taken before the reversal still
        // reports the invoice as collected on that date (mirrors
        // supplier_payment_allocation_history for AP).
        Schema::create('customer_payment_allocation_history', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('customer_payment_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_invoice_id')->constrained()->restrictOnDelete();
            $table->decimal('amount', 14, 2);
            $table->date('payment_date');
            $table->timestamp('reversed_at');
            $table->timestamps();

            $table->unique(['customer_payment_id', 'sales_invoice_id'], 'customer_payment_allocation_history_pair_unique');
            $table->index(['tenant_id', 'sales_invoice_id', 'payment_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_payment_allocation_history');
        Schema::dropIfExists('customer_payment_allocations');
        Schema::dropIfExists('customer_payments');
    }
};
