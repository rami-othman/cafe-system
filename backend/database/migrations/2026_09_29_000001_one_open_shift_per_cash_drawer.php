<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Closed and soft-deleted shifts remain historical records. Existing
        // overlapping open shifts require an explicit operational resolution;
        // never rewrite them during a schema migration.
        $overlap = DB::table('shifts')->where('status', 'open')->whereNull('deleted_at')
            ->whereNotNull('financial_location_id')
            ->select('tenant_id', 'financial_location_id')->groupBy('tenant_id', 'financial_location_id')
            ->havingRaw('COUNT(*) > 1')->first();
        if ($overlap) {
            throw new RuntimeException('Overlapping open shifts exist for tenant '.$overlap->tenant_id
                .' and cash location '.$overlap->financial_location_id.'. Resolve their custody before adding the unique index.');
        }
        DB::statement("CREATE UNIQUE INDEX shifts_one_open_per_location
            ON shifts (tenant_id, financial_location_id)
            WHERE status = 'open' AND deleted_at IS NULL AND financial_location_id IS NOT NULL");
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS shifts_one_open_per_location');
    }
};
