<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('sales_invoice_lines', function (Blueprint $table): void {
            $table->foreignId('product_id')->nullable()->change();
            $table->foreignId('inventory_item_id')->nullable()->after('product_id')->constrained('inventory_items')->restrictOnDelete();
            $table->string('unit_code', 40)->nullable()->after('inventory_item_id');
            $table->decimal('base_quantity', 15, 3)->nullable()->after('unit_code');
        });
        Schema::table('sales_credit_note_lines', function (Blueprint $table): void {
            $table->foreignId('product_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('sales_invoice_lines', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('inventory_item_id');
            $table->dropColumn(['unit_code', 'base_quantity']);
            $table->foreignId('product_id')->nullable(false)->change();
        });
        Schema::table('sales_credit_note_lines', function (Blueprint $table): void {
            $table->foreignId('product_id')->nullable(false)->change();
        });
    }
};
