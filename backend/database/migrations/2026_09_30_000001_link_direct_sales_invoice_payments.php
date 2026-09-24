<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_payments', function (Blueprint $table): void {
            $table->foreignId('direct_sales_invoice_id')->nullable()
                ->constrained('sales_invoices')->restrictOnDelete();
            $table->unique(['tenant_id', 'direct_sales_invoice_id'], 'customer_payments_direct_invoice_unique');
        });
    }

    public function down(): void
    {
        Schema::table('customer_payments', function (Blueprint $table): void {
            $table->dropUnique('customer_payments_direct_invoice_unique');
            $table->dropConstrainedForeignId('direct_sales_invoice_id');
        });
    }
};
