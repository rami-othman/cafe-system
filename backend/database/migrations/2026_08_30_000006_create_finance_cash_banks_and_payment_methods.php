<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('financial_locations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('financial_account_id')->constrained('financial_accounts')->restrictOnDelete();
            $table->string('code', 40);
            $table->string('name');
            $table->string('kind', 10); // cash | bank
            $table->string('type', 30); // cash_drawer | main_safe | petty_cash | bank
            $table->string('bank_name')->nullable();
            $table->string('masked_reference', 80)->nullable();
            $table->boolean('is_active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['tenant_id', 'code']);
            $table->unique(['tenant_id', 'financial_account_id']);
            $table->index(['tenant_id', 'kind', 'is_active']);
            $table->index(['tenant_id', 'branch_id']);
        });

        Schema::create('payment_methods', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('code', 40);
            $table->string('name');
            $table->string('type', 30);
            $table->foreignId('financial_account_id')->constrained('financial_accounts')->restrictOnDelete();
            $table->foreignId('financial_location_id')->nullable()->constrained('financial_locations')->nullOnDelete();
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'is_active', 'sort_order']);
        });

        Schema::create('cash_transfers', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('from_financial_location_id')->constrained('financial_locations')->restrictOnDelete();
            $table->foreignId('to_financial_location_id')->constrained('financial_locations')->restrictOnDelete();
            $table->decimal('amount', 14, 2);
            $table->date('transfer_date');
            $table->text('description')->nullable();
            $table->string('status', 20)->default('posted');
            $table->string('idempotency_key', 120)->nullable();
            $table->string('idempotency_fingerprint', 64)->nullable();
            $table->foreignId('journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('reversal_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['tenant_id', 'idempotency_key']);
            $table->index(['tenant_id', 'transfer_date', 'status']);
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->foreignId('payment_method_id')->nullable()->after('method')->constrained('payment_methods')->nullOnDelete();
            $table->index(['tenant_id', 'payment_method_id']);
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'payment_method_id']);
            $table->dropConstrainedForeignId('payment_method_id');
        });
        Schema::dropIfExists('cash_transfers');
        Schema::dropIfExists('payment_methods');
        Schema::dropIfExists('financial_locations');
    }
};
