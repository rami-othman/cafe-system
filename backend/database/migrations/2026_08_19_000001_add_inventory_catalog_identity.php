<?php

use App\Support\InventoryCatalogIdentity;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->string('catalog_identity')->nullable()->after('barcode');
        });

        DB::table('inventory_items')
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

        $seen = [];
        DB::table('inventory_items')->orderBy('tenant_id')->orderBy('id')->each(function (object $item) use (&$seen): void {
            $identity = InventoryCatalogIdentity::forValues(
                $item->sku,
                $item->name_en ?: ($item->name_ar ?: $item->name),
                $item->unit,
                $item->item_type,
            );
            $key = $item->tenant_id.'|'.$identity;
            if (isset($seen[$key])) {
                // Keep all balances and immutable movements linked to this row.
                // Deactivation removes only the accidental duplicate from normal flows.
                DB::table('inventory_items')->where('id', $item->id)->update([
                    'sku' => null,
                    'barcode' => null,
                    'catalog_identity' => 'inactive-duplicate:'.$item->id,
                    'is_active' => false,
                    'notes' => trim((string) $item->notes."\nInactive duplicate of inventory item #".$seen[$key].'.'),
                    'updated_at' => now(),
                ]);

                return;
            }
            $seen[$key] = $item->id;
            DB::table('inventory_items')->where('id', $item->id)->update([
                'catalog_identity' => $identity,
                'updated_at' => now(),
            ]);
        });

        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->unique(['tenant_id', 'catalog_identity'], 'inventory_items_tenant_catalog_identity_unique');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->dropUnique('inventory_items_tenant_catalog_identity_unique');
            $table->dropColumn('catalog_identity');
        });
    }
};
