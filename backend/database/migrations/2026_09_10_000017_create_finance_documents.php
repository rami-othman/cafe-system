<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('finance_documents', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->string('document_number', 40);
            $table->string('document_type', 20); // receipt | payment
            $table->string('status', 20)->default('draft'); // draft | posted | reversed
            $table->date('document_date');
            $table->foreignId('financial_location_id')->constrained('financial_locations')->restrictOnDelete();
            $table->string('counterparty_type', 30)->nullable();
            $table->unsignedBigInteger('counterparty_id')->nullable();
            $table->string('currency_code', 3)->default('SYP');
            $table->decimal('exchange_rate', 18, 6)->default(1);
            $table->decimal('amount', 14, 2);
            $table->string('external_reference', 120)->nullable();
            $table->text('description')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('reversal_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('original_document_id')->nullable()->constrained('finance_documents')->nullOnDelete();
            $table->foreignId('reversal_document_id')->nullable()->constrained('finance_documents')->nullOnDelete();
            $table->timestamp('reversed_at')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('posted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reversed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('posted_at')->nullable();
            $table->string('reversal_reason', 1000)->nullable();
            $table->string('idempotency_key', 120)->nullable();
            $table->string('idempotency_fingerprint', 64)->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'document_number']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->index(['tenant_id', 'document_date', 'document_type', 'status']);
            $table->index(['tenant_id', 'branch_id']);
        });

        Schema::create('finance_document_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('finance_document_id')->constrained('finance_documents')->cascadeOnDelete();
            $table->foreignId('financial_account_id')->constrained('financial_accounts')->restrictOnDelete();
            $table->unsignedSmallInteger('line_number');
            $table->text('description')->nullable();
            $table->decimal('debit', 14, 2)->default(0);
            $table->decimal('credit', 14, 2)->default(0);
            $table->string('cost_center', 120)->nullable();
            $table->string('reference', 120)->nullable();
            $table->timestamps();

            $table->unique(['finance_document_id', 'line_number']);
            $table->index(['tenant_id', 'financial_account_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('finance_document_lines');
        Schema::dropIfExists('finance_documents');
    }
};
