<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Purchasing Phase 0 — schema groundwork only. A Supplier Invoice line is
     * subordinate to `supplier_invoices`; it never carries its own AP or GL
     * effect. `SupplierInvoiceService::post()` still posts exactly one
     * journal entry per invoice from the header's own `debit_account_id` —
     * these lines only make that header total auditable at item level and
     * lay groundwork for a future Goods Receipt (`warehouse_id`,
     * `received_quantity`) and for Phase 2 mixed-line postings
     * (`expense_category_id`, `financial_account_id`). Existing header-only
     * supplier invoices are unaffected — an invoice with zero rows here
     * behaves exactly as it does today.
     */
    public function up(): void
    {
        Schema::create('supplier_invoice_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('supplier_invoice_id')->constrained('supplier_invoices')->cascadeOnDelete();
            $table->unsignedSmallInteger('line_number');
            // 'inventory' | 'expense' | 'asset' | 'other' — Phase 1 requires
            // every line on one invoice to share the same line_type; mixed
            // invoices are a Phase 2 change to SupplierInvoiceService::post().
            $table->string('line_type', 20);
            $table->foreignId('inventory_item_id')->nullable()->constrained('inventory_items')->restrictOnDelete();
            // Reserved for Phase 2 mixed-line posting (grouping lines by
            // resolved account); unused by Phase 1 validation/posting.
            $table->foreignId('expense_category_id')->nullable()->constrained('expense_categories')->restrictOnDelete();
            $table->foreignId('financial_account_id')->nullable()->constrained('financial_accounts')->restrictOnDelete();
            $table->string('description', 500);
            $table->string('purchase_unit', 40)->nullable();
            $table->decimal('quantity', 15, 3);
            $table->decimal('conversion_factor', 18, 6)->nullable();
            $table->decimal('base_quantity', 15, 3)->nullable();
            $table->decimal('unit_price', 14, 4);
            $table->decimal('discount_amount', 14, 2)->default(0);
            $table->decimal('tax_amount', 14, 2)->default(0);
            $table->decimal('line_total', 14, 2);
            // Reserved for the Phase 2 Goods Receipt domain; Phase 1 never
            // reads or writes a warehouse-driven stock effect from this
            // column, and inventory quantity does not change in Phase 1.
            $table->foreignId('warehouse_id')->nullable()->constrained('warehouses')->restrictOnDelete();
            $table->decimal('received_quantity', 15, 3)->default(0);
            $table->timestamps();
            $table->unique(['supplier_invoice_id', 'line_number']);
            $table->index(['tenant_id', 'supplier_invoice_id']);
            $table->index(['tenant_id', 'inventory_item_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_invoice_lines');
    }
};
