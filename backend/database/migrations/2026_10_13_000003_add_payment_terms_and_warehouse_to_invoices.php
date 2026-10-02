<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Every invoice states how it is paid: cash, credit (آجل) or Sham Cash. The due date only has meaning
 * for credit. A sales invoice also names the warehouse its goods leave from.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sales_invoices', function (Blueprint $table): void {
            $table->string('payment_terms', 20)->nullable();
            $table->string('payment_reference', 120)->nullable();
            $table->foreignId('warehouse_id')->nullable()->constrained('warehouses')->nullOnDelete();
        });
        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->string('payment_terms', 20)->nullable();
            $table->string('payment_reference', 120)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->dropColumn(['payment_terms', 'payment_reference']);
        });
        Schema::table('sales_invoices', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('warehouse_id');
            $table->dropColumn(['payment_terms', 'payment_reference']);
        });
    }
};
