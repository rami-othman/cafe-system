<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Discount System V3 Phase 1: per-discount combination behavior.
 *
 * A discount may only restrict the cafe policy (exclusive); it can never widen
 * it. Existing rows take follow_cafe_policy, which together with the cafe
 * default allow_multiple_discounts=false keeps today's single-discount runtime.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('discounts', function (Blueprint $table): void {
            $table->string('combination_behavior', 30)->default('follow_cafe_policy');
        });
        DB::statement("ALTER TABLE discounts ADD CONSTRAINT discount_combination_behavior_check CHECK (combination_behavior IN ('follow_cafe_policy','exclusive'))");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE discounts DROP CONSTRAINT IF EXISTS discount_combination_behavior_check');
        Schema::table('discounts', fn (Blueprint $table) => $table->dropColumn('combination_behavior'));
    }
};
