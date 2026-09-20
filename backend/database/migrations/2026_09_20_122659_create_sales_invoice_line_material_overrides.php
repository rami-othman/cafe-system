<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A per-invoice-line override of a product variant's default recipe
     * (App\Models\VariantRecipeComponent). When a sales invoice line has
     * rows here, SalesInvoiceInventoryConsumptionService consumes these
     * instead of recomputing from the variant's recipe — letting a
     * cashier/accountant correct what a specific sale actually used (e.g.
     * an extra cup) without changing the product's standard recipe.
     */
    public function up(): void
    {
        Schema::create('sales_invoice_line_material_overrides', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_invoice_line_id')->constrained('sales_invoice_lines')->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained('inventory_items')->restrictOnDelete();
            $table->decimal('quantity', 18, 6);
            $table->string('unit_code', 8);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
            $table->index(['tenant_id', 'sales_invoice_line_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sales_invoice_line_material_overrides');
    }
};
