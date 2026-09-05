<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('expense_categories', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('code', 40);
            $table->string('name');
            $table->foreignId('financial_account_id')->constrained('financial_accounts')->restrictOnDelete();
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'is_active', 'sort_order']);
        });

        Schema::create('expenses', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->string('expense_number', 40);
            $table->foreignId('expense_category_id')->constrained('expense_categories')->restrictOnDelete();
            $table->decimal('amount', 14, 2);
            $table->decimal('tax_amount', 14, 2)->default(0);
            $table->decimal('total_amount', 14, 2);
            $table->date('expense_date');
            $table->unsignedBigInteger('supplier_id')->nullable();
            $table->unsignedBigInteger('cost_center_id')->nullable();
            $table->string('description', 1000);
            $table->text('notes')->nullable();
            $table->string('attachment_path')->nullable();
            $table->string('status', 30)->default('draft');
            $table->string('payment_status', 20)->default('unpaid');
            $table->foreignId('payment_method_id')->nullable()->constrained('payment_methods')->nullOnDelete();
            $table->foreignId('paid_from_financial_location_id')->nullable()->constrained('financial_locations')->restrictOnDelete();
            $table->date('paid_at')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->foreignId('rejected_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('rejected_at')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->foreignId('journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('reversal_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->string('idempotency_key', 120)->nullable();
            $table->string('idempotency_fingerprint', 64)->nullable();
            $table->string('payment_idempotency_key', 120)->nullable();
            $table->string('payment_idempotency_fingerprint', 64)->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'expense_number']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->unique(['tenant_id', 'payment_idempotency_key']);
            $table->index(['tenant_id', 'branch_id', 'expense_date']);
            $table->index(['tenant_id', 'status', 'payment_status']);
            $table->index(['tenant_id', 'expense_category_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expenses');
        Schema::dropIfExists('expense_categories');
    }
};
