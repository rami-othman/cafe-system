<?php

use App\Support\InventoryUnitCatalog;
use App\Support\InventoryCatalogIdentity;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $seen = [];
        DB::table('inventory_items')->orderBy('tenant_id')->orderBy('id')->each(function (object $item) use (&$seen): void {
            $unit = InventoryUnitCatalog::normalize($item->unit);
            if (! in_array($unit, InventoryUnitCatalog::codes(), true)) {
                $unit = 'piece';
            }
            $identity = InventoryCatalogIdentity::forValues($item->sku, $item->name_en ?: ($item->name_ar ?: $item->name), $unit, $item->item_type);
            $key = $item->tenant_id.'|'.$identity;
            $payload = ['unit' => $unit, 'updated_at' => now()];
            if (isset($seen[$key])) {
                $payload += ['catalog_identity' => 'normalized-duplicate:'.$item->id, 'is_active' => false, 'notes' => trim((string) $item->notes."\nInactive duplicate after unit normalization.")];
            } else {
                $payload['catalog_identity'] = $identity;
                $seen[$key] = $item->id;
            }
            DB::table('inventory_items')->where('id', $item->id)->update($payload);
        });
    }

    public function down(): void
    {
        // Canonical units are intentionally not reverted to ambiguous free text.
    }
};
