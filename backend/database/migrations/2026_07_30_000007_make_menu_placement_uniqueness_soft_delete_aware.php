<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('menu_item_placements', function ($table): void {
            $table->dropUnique('menu_item_placements_tenant_id_menu_section_id_product_id_unique');
        });
        DB::statement('CREATE UNIQUE INDEX menu_item_placements_active_product_unique ON menu_item_placements (tenant_id, menu_section_id, product_id) WHERE deleted_at IS NULL');
    }

    public function down(): void
    {
        $hasHistoricalDuplicates = DB::table('menu_item_placements')
            ->select('tenant_id', 'menu_section_id', 'product_id')
            ->groupBy('tenant_id', 'menu_section_id', 'product_id')
            ->havingRaw('COUNT(*) > 1')
            ->exists();
        if ($hasHistoricalDuplicates) {
            throw new RuntimeException('Cannot restore the legacy placement unique constraint while historical placement rows share a composition key.');
        }
        DB::statement('DROP INDEX IF EXISTS menu_item_placements_active_product_unique');
        Schema::table('menu_item_placements', function ($table): void {
            $table->unique(['tenant_id', 'menu_section_id', 'product_id']);
        });
    }
};
