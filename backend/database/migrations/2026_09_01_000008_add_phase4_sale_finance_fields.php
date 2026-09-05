<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('recipe_lines', function (Blueprint $table): void {
            $table->string('unit', 20)->nullable()->after('quantity');
        });

        Schema::table('payment_refunds', function (Blueprint $table): void {
            $table->foreignId('shift_id')->nullable()->after('payment_id')->constrained('shifts')->nullOnDelete();
        });

        // Backfill: a refund's shift is the shift of the payment it refunds —
        // matching how `payments.shift_id` itself is inherited from the order.
        // A portable correlated-subquery UPDATE (works on SQLite/Postgres/MySQL),
        // since query-builder JOIN...UPDATE is not portable across those drivers.
        DB::statement(
            'UPDATE payment_refunds SET shift_id = ('
            .'SELECT payments.shift_id FROM payments WHERE payments.id = payment_refunds.payment_id'
            .') WHERE payment_id IS NOT NULL'
        );
    }

    public function down(): void
    {
        Schema::table('payment_refunds', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('shift_id');
        });
        Schema::table('recipe_lines', function (Blueprint $table): void {
            $table->dropColumn('unit');
        });
    }
};
