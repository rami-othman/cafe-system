<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('financial_reconciliations', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('financial_account_id')->constrained('financial_accounts')->restrictOnDelete();
            $table->foreignId('financial_location_id')->nullable()->constrained('financial_locations')->nullOnDelete();
            $table->foreignId('payment_method_id')->nullable()->constrained('payment_methods')->nullOnDelete();
            $table->string('reference', 48); $table->string('type', 12); $table->string('status', 20)->default('draft');
            $table->date('date_from'); $table->date('date_to');
            $table->decimal('book_opening_balance', 14, 2); $table->decimal('book_closing_balance', 14, 2);
            $table->decimal('external_opening_balance', 14, 2)->nullable(); $table->decimal('external_closing_balance', 14, 2)->nullable();
            $table->decimal('actual_cash_count', 14, 2)->nullable(); $table->decimal('difference', 14, 2)->nullable();
            $table->text('notes')->nullable(); $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('completed_by')->nullable()->constrained('users')->nullOnDelete(); $table->timestamp('completed_at')->nullable(); $table->timestamps();
            $table->unique(['tenant_id', 'reference']); $table->index(['tenant_id', 'financial_account_id', 'date_from', 'date_to']); $table->index(['tenant_id', 'branch_id', 'status']);
        });
        Schema::create('financial_reconciliation_statement_lines', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('financial_reconciliation_id')->constrained()->cascadeOnDelete();
            $table->date('transaction_date'); $table->date('value_date')->nullable(); $table->string('reference', 120)->nullable(); $table->text('description');
            $table->decimal('amount', 14, 2); $table->string('direction', 10); $table->string('external_identifier', 120)->nullable(); $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete(); $table->timestamps();
            $table->unique(['financial_reconciliation_id', 'external_identifier'], 'recon_statement_external_unique'); $table->index(['tenant_id', 'financial_reconciliation_id', 'transaction_date']);
        });
        Schema::create('financial_reconciliation_matches', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('financial_reconciliation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('statement_line_id')->constrained('financial_reconciliation_statement_lines')->cascadeOnDelete(); $table->foreignId('journal_entry_id')->constrained('journal_entries')->restrictOnDelete();
            $table->decimal('matched_amount', 14, 2); $table->string('idempotency_key', 120)->nullable(); $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete(); $table->timestamps();
            $table->unique(['tenant_id', 'financial_reconciliation_id', 'idempotency_key'], 'recon_match_idempotency_unique'); $table->index(['tenant_id', 'financial_reconciliation_id', 'statement_line_id'], 'recon_match_line_index'); $table->index(['tenant_id', 'financial_reconciliation_id', 'journal_entry_id'], 'recon_match_journal_index');
        });
    }
    public function down(): void { Schema::dropIfExists('financial_reconciliation_matches'); Schema::dropIfExists('financial_reconciliation_statement_lines'); Schema::dropIfExists('financial_reconciliations'); }
};
