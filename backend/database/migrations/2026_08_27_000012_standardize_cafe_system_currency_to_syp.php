<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Cafe System 618 is deployed only in Syria. This corrects the persisted
     * currency identity without touching monetary amounts or snapshots.
     */
    public function up(): void
    {
        DB::table('tenants')->whereNull('deleted_at')->update([
            'currency' => 'SYP',
            'updated_at' => now(),
        ]);

        DB::table('branches')->whereNull('deleted_at')->update([
            'currency' => 'SYP',
            'updated_at' => now(),
        ]);

        DB::table('discounts')->where('conditions', 'Min. $10 spent')->update([
            'conditions' => 'Min. 10 SYP spent',
            'description' => 'Min. 10 SYP spent',
            'updated_at' => now(),
        ]);

        DB::table('discounts')->where('conditions', 'Orders over $75')->update([
            'conditions' => 'Orders over 75 SYP',
            'description' => 'Orders over 75 SYP',
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        // Intentionally irreversible: the former code was not a reliable
        // historic FX record and no monetary value was converted.
    }
};
