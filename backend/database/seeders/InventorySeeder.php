<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Legacy entry point retained for existing onboarding scripts.
 *
 * InventoryCenterSeeder is the single source for the tenant-level inventory
 * catalog. The old generic demo SKUs are only deactivated, never deleted, so
 * any historical balances and immutable movement records remain intact.
 */
class InventorySeeder extends Seeder
{
    public function run(): void
    {
        $this->call(InventoryCenterSeeder::class);

        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        if (! $tenantId) {
            return;
        }

        DB::table('inventory_items')
            ->where('tenant_id', $tenantId)
            ->whereIn('sku', [
                'INV-COFFEE-BEANS',
                'INV-MILK',
                'INV-CUPS',
                'INV-CROISSANTS',
            ])
            ->update([
                'is_active' => false,
                'notes' => 'Inactive duplicate of the detailed demo inventory catalog.',
                'updated_at' => now(),
            ]);
    }
}
