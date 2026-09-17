<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Purchase Invoice V2 phase 2 — additional charges (landed cost / standalone
 * expense) and a whole-invoice discount. A charge with treatment
 * `capitalize` is proportionally allocated into the eligible (inventory)
 * lines' cost basis — see SupplierInvoiceService::allocateAndFinalize(); a
 * `expense` charge posts standalone to its own expense_category's account
 * and never touches inventory cost. The invoice-level discount is allocated
 * the same proportional way, subtracted instead of added.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('supplier_invoice_charges', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('supplier_invoice_id')->constrained()->cascadeOnDelete();
            $table->unsignedSmallInteger('charge_number');
            $table->string('description', 255);
            $table->string('treatment', 20); // capitalize | expense
            $table->foreignId('expense_category_id')->nullable()->constrained()->nullOnDelete();
            $table->decimal('amount', 14, 2);
            $table->decimal('tax_amount', 14, 2)->default(0);
            $table->timestamps();
            $table->unique(['supplier_invoice_id', 'charge_number']);
        });

        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->string('discount_type', 20)->default('fixed')->after('tax_amount');
            $table->decimal('discount_value', 14, 4)->nullable()->after('discount_type');
            $table->decimal('discount_amount', 14, 2)->default(0)->after('discount_value');
            $table->decimal('charges_amount', 14, 2)->default(0)->after('discount_amount');
        });

        Schema::table('supplier_invoice_lines', function (Blueprint $table): void {
            $table->decimal('allocated_discount', 14, 2)->default(0)->after('discount_amount');
            $table->decimal('allocated_landed_cost', 14, 2)->default(0)->after('allocated_discount');
        });
    }

    public function down(): void
    {
        Schema::table('supplier_invoice_lines', function (Blueprint $table): void {
            $table->dropColumn(['allocated_discount', 'allocated_landed_cost']);
        });
        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->dropColumn(['discount_type', 'discount_value', 'discount_amount', 'charges_amount']);
        });
        Schema::dropIfExists('supplier_invoice_charges');
    }
};
