<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * `products.is_stock_tracked` is the canonical inventory-tracking flag; the
 * legacy `products.inventory_controlled` column (the one SaleConsumptionService
 * actually gated consumption on) is kept as a synchronized compatibility
 * mirror going forward (see CatalogProductService::productPayload()).
 *
 * Any row where the two already disagree is reconciled to the union of both
 * — a product that was legacy inventory_controlled=true keeps consuming
 * inventory (is_stock_tracked is turned on for it), and a product that was
 * is_stock_tracked=true also gets inventory_controlled turned on so the
 * legacy column stops lying about it. Nothing that was already tracked is
 * ever turned off by this migration.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::table('products')
            ->where('is_stock_tracked', true)
            ->orWhere('inventory_controlled', true)
            ->update(['is_stock_tracked' => true, 'inventory_controlled' => true]);
    }

    public function down(): void
    {
        // Intentionally irreversible: the union performed above cannot be
        // decomposed back into which column originally carried which value.
    }
};
