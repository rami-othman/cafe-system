<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Discount priority is now an integer from 0 to 10 (was 0 to 1000).
 *
 * Existing priorities above 10 are clamped to 10 before the CHECK is narrowed;
 * values already within 0..10 are kept as they are.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::transaction(function (): void {
            DB::statement("SET LOCAL lock_timeout = '5s'");
            DB::table('discounts')->where('priority', '>', 10)->update(['priority' => 10]);
            DB::statement('ALTER TABLE discounts DROP CONSTRAINT discount_priority_check');
            DB::statement('ALTER TABLE discounts ADD CONSTRAINT discount_priority_check CHECK (priority BETWEEN 0 AND 10)');
        });
    }

    public function down(): void
    {
        DB::transaction(function (): void {
            DB::statement("SET LOCAL lock_timeout = '5s'");
            DB::statement('ALTER TABLE discounts DROP CONSTRAINT discount_priority_check');
            DB::statement('ALTER TABLE discounts ADD CONSTRAINT discount_priority_check CHECK (priority BETWEEN 0 AND 1000)');
        });
    }
};
