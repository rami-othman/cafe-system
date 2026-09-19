<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shifts', function (Blueprint $table): void {
            $table->foreignId('financial_location_id')->nullable()->after('user_id')->constrained('financial_locations')->nullOnDelete();
        });

        Schema::table('supplier_payments', function (Blueprint $table): void {
            $table->foreignId('shift_id')->nullable()->after('financial_location_id')->constrained('shifts')->nullOnDelete();
            $table->foreignId('finance_document_id')->nullable()->after('shift_id')->constrained('finance_documents')->nullOnDelete();
            $table->index(['tenant_id', 'shift_id']);
        });

        Schema::table('finance_documents', function (Blueprint $table): void {
            $table->foreignId('shift_id')->nullable()->after('financial_location_id')->constrained('shifts')->nullOnDelete();
            $table->string('source_type', 60)->nullable()->after('external_reference');
            $table->unsignedBigInteger('source_id')->nullable()->after('source_type');
            $table->foreignId('purchase_invoice_id')->nullable()->after('source_id')->constrained('supplier_invoices')->nullOnDelete();
            $table->unique(['tenant_id', 'source_type', 'source_id'], 'finance_documents_source_unique');
        });

        Schema::table('shift_cash_movements', function (Blueprint $table): void {
            $table->string('source_type', 60)->nullable()->after('description');
            $table->unsignedBigInteger('source_id')->nullable()->after('source_type');
            $table->unique(['tenant_id', 'source_type', 'source_id'], 'shift_cash_movements_source_unique');
        });
    }

    public function down(): void
    {
        Schema::table('shift_cash_movements', function (Blueprint $table): void {
            $table->dropUnique('shift_cash_movements_source_unique');
            $table->dropColumn(['source_type', 'source_id']);
        });
        Schema::table('finance_documents', function (Blueprint $table): void {
            $table->dropUnique('finance_documents_source_unique');
            $table->dropConstrainedForeignId('shift_id');
            $table->dropConstrainedForeignId('purchase_invoice_id');
            $table->dropColumn(['source_type', 'source_id']);
        });
        Schema::table('supplier_payments', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'shift_id']);
            $table->dropConstrainedForeignId('finance_document_id');
            $table->dropConstrainedForeignId('shift_id');
        });
        Schema::table('shifts', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('financial_location_id');
        });
    }
};
