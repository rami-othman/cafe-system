<?php

namespace Database\Seeders;

use App\Services\StockCountService;
use App\Services\StockMovementService;
use App\Support\InventoryCatalogIdentity;
use App\Support\InventoryUnitCatalog;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryCenterSeeder extends Seeder
{
    public function run(): void
    {
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $manager = (int) DB::table('users')->where('tenant_id', $tenant)->where('email', 'manager@cafe618.local')->value('id');
        if (! $tenant || ! $manager) {
            return;
        }
        $request = Request::create('/seed/inventory', 'POST');
        $now = now();
        $warehouses = DB::table('warehouses')->where('tenant_id', $tenant)->whereNull('deleted_at')->orderBy('id')->get();
        $central = $warehouses->firstWhere('type', 'central') ?: $warehouses->first();
        if (! $central) {
            return;
        }

        foreach ($this->items() as $position => $item) {
            $unit = InventoryUnitCatalog::normalize($item['unit']);
            DB::table('inventory_items')->updateOrInsert(['tenant_id' => $tenant, 'sku' => $item['sku']], ['name' => $item['nameAr'], 'name_ar' => $item['nameAr'], 'name_en' => $item['nameEn'], 'catalog_identity' => InventoryCatalogIdentity::forValues($item['sku'], $item['nameEn'], $unit, $item['type']), 'item_type' => $item['type'], 'category' => $item['category'], 'unit' => $unit, 'minimum_stock' => $item['minimum'], 'reorder_level' => $item['minimum'], 'cost_per_unit' => $item['cost'], 'latest_unit_cost' => $item['cost'], 'is_active' => true, 'created_by' => $manager, 'updated_by' => $manager, 'created_at' => $now, 'updated_at' => $now]);
            $itemId = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', $item['sku'])->value('id');
            $warehouse = $position % 8 === 0 ? $warehouses->firstWhere('type', 'bar') ?: $central : ($position % 9 === 0 ? $warehouses->firstWhere('type', 'kitchen') ?: $central : $central);
            // A stock-count is scoped to the materials explicitly available in
            // its warehouse. Keep the demo catalogue assignment in sync with
            // the balance that is seeded below.
            DB::table('inventory_item_warehouses')->updateOrInsert(
                ['tenant_id' => $tenant, 'inventory_item_id' => $itemId, 'warehouse_id' => $warehouse->id],
                ['created_at' => $now, 'updated_at' => $now],
            );
            if (! DB::table('stock_balances')->where(['tenant_id' => $tenant, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $itemId])->exists()) {
                if ($item['opening'] === '0.000') {
                    DB::table('stock_balances')->insert(['tenant_id' => $tenant, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $itemId, 'quantity_on_hand' => 0, 'reserved_quantity' => 0, 'average_unit_cost' => $item['cost'], 'created_at' => $now, 'updated_at' => $now]);
                } else {
                    app(StockMovementService::class)->record($request, $tenant, ['warehouseId' => $warehouse->id, 'itemId' => $itemId, 'type' => 'opening_balance', 'quantity' => $item['opening'], 'unitCost' => $item['cost'], 'reason' => 'رصيد افتتاحي تجريبي', 'referenceType' => 'inventory_demo_seed', 'referenceId' => 1, 'occurredAt' => '2026-08-17 08:00:00'], $manager);
                }
            }
        }

        $beans = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'INV-BEANS')->value('id');
        $milk = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'INV-MILK-FRESH')->value('id');
        $cups = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'INV-CUP-12OZ')->value('id');
        $this->movementOnce($request, $tenant, $manager, $central->id, $beans, 'stock_in', '12.000', '10.250', 'توريد حبوب قهوة أسبوعي', 'seed-stock-in');
        $this->movementOnce($request, $tenant, $manager, $central->id, $beans, 'stock_out', '2.000', null, 'استهلاك تحضير تجريبي', 'seed-stock-out');
        $this->movementOnce($request, $tenant, $manager, $central->id, $milk, 'waste', '1.000', null, 'انتهاء صلاحية الحليب', 'seed-waste');
        $this->movementOnce($request, $tenant, $manager, $central->id, $cups, 'adjustment_in', '5.000', '0.0800', 'تصحيح عدّ العبوات', 'seed-adjustment');

        if (! DB::table('stock_counts')->where('tenant_id', $tenant)->where('notes', 'جرد تجريبي مرحّل')->exists()) {
            $counts = app(StockCountService::class);
            $id = $counts->create($request, $tenant, ['warehouseId' => $central->id, 'countDate' => '2026-08-17', 'notes' => 'جرد تجريبي مرحّل'], $manager);
            $counts->transition($request, $tenant, $id, 'start', $manager);
            $counts->upsertLine($tenant, $id, ['itemId' => $beans, 'countedQuantity' => '20.000', 'reason' => 'فرق عدّ تجريبي']);
            $counts->transition($request, $tenant, $id, 'submit', $manager);
            $counts->transition($request, $tenant, $id, 'approve', $manager);
            $counts->transition($request, $tenant, $id, 'post', $manager);
        }
    }

    private function movementOnce(Request $request, int $tenant, int $user, int $warehouse, int $item, string $type, string $quantity, ?string $cost, string $reason, string $reference): void
    {
        if (! DB::table('stock_movements')->where('tenant_id', $tenant)->where('reference_type', $reference)->exists()) {
            app(StockMovementService::class)->record($request, $tenant, array_filter(['warehouseId' => $warehouse, 'itemId' => $item, 'type' => $type, 'quantity' => $quantity, 'unitCost' => $cost, 'reason' => $reason, 'referenceType' => $reference, 'referenceId' => 1]), $user);
        }
    }

    private function items(): array
    {
        return [
            ['sku' => 'INV-BEANS', 'nameAr' => 'حبوب قهوة أرابيكا', 'nameEn' => 'Arabica coffee beans', 'type' => 'raw_material', 'category' => 'قهوة', 'unit' => 'kg', 'minimum' => '5.000', 'cost' => '9.5000', 'opening' => '24.500'], ['sku' => 'INV-MILK-FRESH', 'nameAr' => 'حليب طازج', 'nameEn' => 'Fresh milk', 'type' => 'raw_material', 'category' => 'ألبان', 'unit' => 'liter', 'minimum' => '8.000', 'cost' => '1.2500', 'opening' => '42.000'], ['sku' => 'INV-SUGAR', 'nameAr' => 'سكر أبيض', 'nameEn' => 'White sugar', 'type' => 'raw_material', 'category' => 'محليات', 'unit' => 'kg', 'minimum' => '4.000', 'cost' => '0.8000', 'opening' => '18.000'], ['sku' => 'INV-VANILLA', 'nameAr' => 'شراب فانيلا', 'nameEn' => 'Vanilla syrup', 'type' => 'raw_material', 'category' => 'شرابات', 'unit' => 'bottle', 'minimum' => '2.000', 'cost' => '4.0000', 'opening' => '8.000'], ['sku' => 'INV-CARAMEL', 'nameAr' => 'شراب كراميل', 'nameEn' => 'Caramel syrup', 'type' => 'raw_material', 'category' => 'شرابات', 'unit' => 'bottle', 'minimum' => '2.000', 'cost' => '4.0000', 'opening' => '6.000'], ['sku' => 'INV-MATCHA', 'nameAr' => 'بودرة ماتشا', 'nameEn' => 'Matcha powder', 'type' => 'raw_material', 'category' => 'شاي', 'unit' => 'gram', 'minimum' => '500.000', 'cost' => '0.0200', 'opening' => '2500.000'], ['sku' => 'INV-TEA', 'nameAr' => 'شاي أسود', 'nameEn' => 'Black tea', 'type' => 'raw_material', 'category' => 'شاي', 'unit' => 'gram', 'minimum' => '400.000', 'cost' => '0.0100', 'opening' => '0.000'], ['sku' => 'INV-CHOCOLATE', 'nameAr' => 'صلصة شوكولاتة', 'nameEn' => 'Chocolate sauce', 'type' => 'raw_material', 'category' => 'صلصات', 'unit' => 'bottle', 'minimum' => '2.000', 'cost' => '3.5000', 'opening' => '7.000'], ['sku' => 'INV-CUP-12OZ', 'nameAr' => 'أكواب ورقية 12 أونصة', 'nameEn' => '12 oz paper cups', 'type' => 'packaging', 'category' => 'أكواب', 'unit' => 'piece', 'minimum' => '100.000', 'cost' => '0.0600', 'opening' => '350.000'], ['sku' => 'INV-LID-12OZ', 'nameAr' => 'أغطية أكواب', 'nameEn' => 'Cup lids', 'type' => 'packaging', 'category' => 'أكواب', 'unit' => 'piece', 'minimum' => '100.000', 'cost' => '0.0300', 'opening' => '280.000'], ['sku' => 'INV-CUP-16OZ', 'nameAr' => 'أكواب ورقية 16 أونصة', 'nameEn' => '16 oz paper cups', 'type' => 'packaging', 'category' => 'أكواب', 'unit' => 'piece', 'minimum' => '80.000', 'cost' => '0.0800', 'opening' => '75.000'], ['sku' => 'INV-NAPKIN', 'nameAr' => 'مناديل', 'nameEn' => 'Napkins', 'type' => 'supply', 'category' => 'ضيافة', 'unit' => 'pack', 'minimum' => '10.000', 'cost' => '1.2000', 'opening' => '22.000'], ['sku' => 'INV-WATER', 'nameAr' => 'مياه معبأة', 'nameEn' => 'Bottled water', 'type' => 'supply', 'category' => 'مشروبات', 'unit' => 'bottle', 'minimum' => '24.000', 'cost' => '0.3500', 'opening' => '48.000'], ['sku' => 'INV-GLOVES', 'nameAr' => 'قفازات استخدام واحد', 'nameEn' => 'Disposable gloves', 'type' => 'supply', 'category' => 'نظافة', 'unit' => 'box', 'minimum' => '3.000', 'cost' => '2.0000', 'opening' => '5.000'], ['sku' => 'INV-CLEANER', 'nameAr' => 'منظف أسطح', 'nameEn' => 'Surface cleaner', 'type' => 'supply', 'category' => 'نظافة', 'unit' => 'bottle', 'minimum' => '2.000', 'cost' => '2.7500', 'opening' => '4.000'], ['sku' => 'INV-STRAWS', 'nameAr' => 'شفاطات', 'nameEn' => 'Straws', 'type' => 'packaging', 'category' => 'أكواب', 'unit' => 'pack', 'minimum' => '5.000', 'cost' => '1.0000', 'opening' => '12.000'], ['sku' => 'INV-ICE', 'nameAr' => 'ثلج', 'nameEn' => 'Ice', 'type' => 'raw_material', 'category' => 'بار', 'unit' => 'kg', 'minimum' => '10.000', 'cost' => '0.2500', 'opening' => '30.000'], ['sku' => 'INV-LEMON', 'nameAr' => 'ليمون', 'nameEn' => 'Lemon', 'type' => 'raw_material', 'category' => 'فواكه', 'unit' => 'kg', 'minimum' => '3.000', 'cost' => '1.5000', 'opening' => '9.000'], ['sku' => 'INV-CROISSANT', 'nameAr' => 'كرواسون', 'nameEn' => 'Croissant', 'type' => 'finished_good', 'category' => 'مخبوزات', 'unit' => 'piece', 'minimum' => '10.000', 'cost' => '1.1000', 'opening' => '12.000'], ['sku' => 'INV-MUFFIN', 'nameAr' => 'مافن شوكولاتة', 'nameEn' => 'Chocolate muffin', 'type' => 'finished_good', 'category' => 'مخبوزات', 'unit' => 'piece', 'minimum' => '8.000', 'cost' => '1.2500', 'opening' => '6.000'], ['sku' => 'INV-OAT-MILK', 'nameAr' => 'حليب شوفان', 'nameEn' => 'Oat milk', 'type' => 'raw_material', 'category' => 'ألبان', 'unit' => 'liter', 'minimum' => '4.000', 'cost' => '2.1000', 'opening' => '8.000'], ['sku' => 'INV-DECAF', 'nameAr' => 'قهوة منزوعة الكافيين', 'nameEn' => 'Decaf beans', 'type' => 'raw_material', 'category' => 'قهوة', 'unit' => 'kg', 'minimum' => '2.000', 'cost' => '11.0000', 'opening' => '3.000'], ['sku' => 'INV-HONEY', 'nameAr' => 'عسل', 'nameEn' => 'Honey', 'type' => 'raw_material', 'category' => 'محليات', 'unit' => 'bottle', 'minimum' => '2.000', 'cost' => '3.0000', 'opening' => '5.000'], ['sku' => 'INV-CARD-SLEEVE', 'nameAr' => 'حامل كوب كرتوني', 'nameEn' => 'Cup sleeve', 'type' => 'packaging', 'category' => 'أكواب', 'unit' => 'piece', 'minimum' => '80.000', 'cost' => '0.0400', 'opening' => '60.000'], ['sku' => 'INV-FILTER', 'nameAr' => 'فلاتر قهوة', 'nameEn' => 'Coffee filters', 'type' => 'supply', 'category' => 'قهوة', 'unit' => 'pack', 'minimum' => '4.000', 'cost' => '2.0000', 'opening' => '9.000'],
        ];
    }
}
