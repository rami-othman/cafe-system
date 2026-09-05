<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('suppliers', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('supplier_number', 40);
            $table->string('name');
            $table->string('phone', 40)->nullable();
            $table->string('email')->nullable();
            $table->string('address', 500)->nullable();
            $table->string('contact_person')->nullable();
            $table->string('tax_number', 60)->nullable();
            $table->unsignedInteger('payment_terms_days')->default(0);
            $table->text('notes')->nullable();
            $table->boolean('is_active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'supplier_number']);
            $table->index(['tenant_id', 'is_active', 'name']);
        });

        // Future-compatible link only — the legacy free-text
        // inventory_items.preferred_supplier_name is left untouched. There is
        // no deterministic way to map ambiguous historical free text to a
        // real supplier row, so no backfill is performed (see docs §5).
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->foreignId('preferred_supplier_id')->nullable()->after('preferred_supplier_name')->constrained('suppliers')->nullOnDelete();
        });

        Schema::create('supplier_invoices', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('supplier_id')->constrained()->restrictOnDelete();
            $table->string('internal_reference', 40);
            $table->string('invoice_number', 80);
            $table->date('invoice_date');
            $table->date('due_date');
            $table->string('invoice_type', 20);
            $table->foreignId('expense_category_id')->nullable()->constrained('expense_categories')->restrictOnDelete();
            $table->foreignId('debit_account_id')->constrained('financial_accounts')->restrictOnDelete();
            $table->decimal('subtotal', 14, 2);
            $table->decimal('tax_amount', 14, 2)->default(0);
            $table->decimal('total_amount', 14, 2);
            $table->string('status', 20)->default('draft');
            $table->text('description')->nullable();
            $table->text('notes')->nullable();
            $table->string('attachment_path')->nullable();
            $table->string('source_type', 60)->nullable();
            $table->unsignedBigInteger('source_id')->nullable();
            $table->foreignId('journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('reversal_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->string('idempotency_key', 120)->nullable();
            $table->string('idempotency_fingerprint', 64)->nullable();
            $table->string('posting_idempotency_key', 120)->nullable();
            $table->string('posting_idempotency_fingerprint', 64)->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('posted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('posted_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'internal_reference']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->unique(['tenant_id', 'posting_idempotency_key']);
            $table->index(['tenant_id', 'supplier_id', 'status']);
            $table->index(['tenant_id', 'branch_id', 'invoice_date']);
            $table->index(['tenant_id', 'due_date']);
            $table->index(['tenant_id', 'source_type', 'source_id']);
        });

        Schema::create('supplier_payments', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('supplier_id')->constrained()->restrictOnDelete();
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
            $table->index(['tenant_id', 'supplier_id', 'status']);
            $table->index(['tenant_id', 'branch_id', 'payment_date']);
        });

        Schema::create('payment_allocations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('supplier_payment_id')->constrained()->cascadeOnDelete();
            $table->foreignId('supplier_invoice_id')->constrained()->restrictOnDelete();
            $table->decimal('amount', 14, 2);
            $table->timestamps();
            $table->unique(['supplier_payment_id', 'supplier_invoice_id'], 'payment_allocations_pair_unique');
            $table->index(['tenant_id', 'supplier_invoice_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_allocations');
        Schema::dropIfExists('supplier_payments');
        Schema::dropIfExists('supplier_invoices');
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('preferred_supplier_id');
        });
        Schema::dropIfExists('suppliers');
    }
};
