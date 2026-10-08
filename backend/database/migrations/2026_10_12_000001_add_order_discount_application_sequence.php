<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Discount System V3 Phase 2: authoritative application order.
 *
 * Sequential stacking makes order financially significant, so it is persisted
 * explicitly instead of being inferred from row ids. Rows written before V3
 * keep NULL and sort by id, which is how they were always applied.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('order_discounts', function (Blueprint $table): void {
            $table->unsignedSmallInteger('application_sequence')->nullable();
        });
        DB::statement('ALTER TABLE order_discounts ADD CONSTRAINT applied_discount_sequence_check CHECK (application_sequence IS NULL OR application_sequence >= 1)');
        DB::statement('CREATE INDEX order_discounts_order_sequence_index ON order_discounts (tenant_id, order_id, application_sequence, id)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS order_discounts_order_sequence_index');
        DB::statement('ALTER TABLE order_discounts DROP CONSTRAINT IF EXISTS applied_discount_sequence_check');
        Schema::table('order_discounts', fn (Blueprint $table) => $table->dropColumn('application_sequence'));
    }
};
