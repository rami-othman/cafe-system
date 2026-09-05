<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A bar-check line denotes an operationally available item in that bar.
     * Older templates predate warehouse assignments, so make their existing
     * lines valid without removing a configured shift-close check.
     */
    public function up(): void
    {
        if (! Schema::hasTable('bar_check_templates') ||
            ! Schema::hasTable('bar_check_template_lines') ||
            ! Schema::hasTable('inventory_item_warehouses')) {
            return;
        }

        $now = now();

        DB::table('bar_check_template_lines as lines')
            ->join(
                'bar_check_templates as templates',
                'templates.id',
                '=',
                'lines.bar_check_template_id',
            )
            ->select([
                'templates.tenant_id',
                'templates.warehouse_id',
                'lines.inventory_item_id',
            ])
            ->orderBy('lines.id')
            ->each(function (object $line) use ($now): void {
                DB::table('inventory_item_warehouses')->updateOrInsert(
                    [
                        'tenant_id' => $line->tenant_id,
                        'warehouse_id' => $line->warehouse_id,
                        'inventory_item_id' => $line->inventory_item_id,
                    ],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            });
    }

    public function down(): void
    {
        // Assignment may later be maintained independently, so preserve it.
    }
};
