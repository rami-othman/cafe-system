<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sales_invoice_lines', function (Blueprint $table): void {
            // The selected sellable variant is part of the immutable sales-line
            // snapshot.  A tracked line without it must not guess a recipe.
            $table->foreignId('product_variant_id')->nullable()->after('product_id')
                ->constrained('product_variants')->restrictOnDelete();
            $table->index(['tenant_id', 'product_variant_id'], 'sales_invoice_lines_tenant_variant_index');
        });
    }

    public function down(): void
    {
        Schema::table('sales_invoice_lines', function (Blueprint $table): void {
            $table->dropIndex('sales_invoice_lines_tenant_variant_index');
            $table->dropConstrainedForeignId('product_variant_id');
        });
    }
};
