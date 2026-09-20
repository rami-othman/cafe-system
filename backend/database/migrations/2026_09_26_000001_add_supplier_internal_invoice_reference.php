<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('supplier_invoices', function (Blueprint $table): void {
            // Historical invoices retain their original external reference; new
            // invoices receive this separate supplier-scoped internal number.
            $table->string('supplier_internal_reference', 80)->nullable();
            $table->unique(['tenant_id', 'supplier_internal_reference']);
        });
    }

    public function down(): void
    {
        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->dropUnique(['tenant_id', 'supplier_internal_reference']);
            $table->dropColumn('supplier_internal_reference');
        });
    }
};
