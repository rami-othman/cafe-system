<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Purchase Invoice V2 (phase 1 — basics): the client now enters a line's
 * gross purchase amount instead of a manual unit price; the server derives
 * `unit_price` from (gross - discount) / quantity. `line_gross_amount` keeps
 * the originally entered amount for display/edit round-tripping (unit_price
 * alone can't be inverted back to it once a discount is applied).
 * `discount_type`/`discount_value` record how the stored `discount_amount`
 * was produced (fixed amount or percentage of the gross) — `discount_amount`
 * itself remains the source of truth for totals.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('supplier_invoice_lines', function (Blueprint $table): void {
            $table->decimal('line_gross_amount', 14, 2)->nullable()->after('unit_price');
            $table->string('discount_type', 20)->default('fixed')->after('discount_amount');
            $table->decimal('discount_value', 14, 4)->nullable()->after('discount_type');
        });
    }

    public function down(): void
    {
        Schema::table('supplier_invoice_lines', function (Blueprint $table): void {
            $table->dropColumn(['line_gross_amount', 'discount_type', 'discount_value']);
        });
    }
};
