<?php

namespace Database\Seeders;

use App\Domain\Inventory\InventoryPostingService;
use App\Models\User;
use App\Services\FinancialSetupService;
use App\Services\Menu\MenuPublishingService;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * A deliberately small, idempotent sample catalog for the Downtown branch.
 *
 * It only adds a visible POS menu and opening inventory to Downtown's main
 * store. It never resets data, modifies sales, or touches other branches.
 */
final class Cafe618DowntownDemoSeeder extends Seeder
{
    private int $tenantId;

    private int $branchId;

    private int $warehouseId;

    private User $owner;

    private Request $request;

    public function run(): void
    {
        if (! app()->environment(['local', 'development', 'testing'])) {
            throw new RuntimeException('Cafe618DowntownDemoSeeder is restricted to local, development, and testing environments.');
        }

        $this->tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branch = DB::table('branches')
            ->where('tenant_id', $this->tenantId)
            ->where('name', 'Downtown')
            ->whereNull('deleted_at')
            ->first();
        $this->owner = User::query()
            ->where('tenant_id', $this->tenantId)
            ->where('role', 'owner')
            ->firstOrFail();

        if (! $this->tenantId || ! $branch) {
            throw new RuntimeException('The Cafe 618 Downtown branch is unavailable.');
        }

        $this->branchId = (int) $branch->id;
        app(FinancialSetupService::class)->ensureForTenant($this->tenantId, $this->branchId, $this->owner->id);
        app(FinancialSetupService::class)->ensureBranchMainWarehouse($this->tenantId, $this->branchId, $this->owner->id);
        $this->warehouseId = (int) DB::table('warehouses')
            ->where('tenant_id', $this->tenantId)
            ->where('branch_id', $this->branchId)
            ->where('type', 'branch_main')
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->value('id');
        if (! $this->warehouseId) {
            throw new RuntimeException('Downtown main store warehouse is unavailable.');
        }

        $this->request = Request::create('/seed/cafe-618/downtown-demo', 'POST');
        $this->request->attributes->set('tenant_id', $this->tenantId);
        $this->request->attributes->set('auth_user', $this->owner);
        app()->instance('request', $this->request);

        $this->seedInventory();
        $this->seedMenu();
    }

    private function seedInventory(): void
    {
        $levels = [
            'INV-BEANS' => ['quantity' => '12.000', 'cost' => '10.0000'],
            'INV-MILK-FRESH' => ['quantity' => '30.000', 'cost' => '1.2500'],
            'INV-VANILLA' => ['quantity' => '6.000', 'cost' => '4.0000'],
            'INV-CARAMEL' => ['quantity' => '6.000', 'cost' => '4.0000'],
            'INV-CUP-12OZ' => ['quantity' => '300.000', 'cost' => '0.0700'],
            'INV-LID-12OZ' => ['quantity' => '300.000', 'cost' => '0.0350'],
            'INV-CUP-16OZ' => ['quantity' => '150.000', 'cost' => '0.0850'],
            'INV-ICE' => ['quantity' => '20.000', 'cost' => '0.2500'],
            'INV-CROISSANT' => ['quantity' => '30.000', 'cost' => '1.1000'],
        ];
        $items = DB::table('inventory_items')
            ->where('tenant_id', $this->tenantId)
            ->whereIn('sku', array_keys($levels))
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->get(['id', 'sku', 'unit'])
            ->keyBy('sku');
        if ($items->count() !== count($levels)) {
            throw new RuntimeException('The Downtown demo requires the standard Cafe 618 inventory catalog.');
        }

        $posting = app(InventoryPostingService::class);
        foreach ($levels as $sku => $level) {
            $item = $items->get($sku);
            DB::table('inventory_item_warehouses')->insertOrIgnore([
                'tenant_id' => $this->tenantId,
                'inventory_item_id' => $item->id,
                'warehouse_id' => $this->warehouseId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $posting->post($this->request, $this->tenantId, [
                'warehouseId' => $this->warehouseId,
                'branchId' => $this->branchId,
                'itemId' => $item->id,
                'type' => 'opening_balance',
                'quantity' => $level['quantity'],
                'unit' => $item->unit,
                'unitCost' => $level['cost'],
                'reason' => 'Downtown demo opening inventory',
                'referenceType' => 'cafe618_downtown_demo',
                'referenceId' => $item->id,
                'idempotencyKey' => 'cafe618-downtown-demo-opening-'.$item->id,
            ], $this->owner->id);
        }
    }

    private function seedMenu(): void
    {
        $now = now();
        $menuId = (int) DB::table('menus')
            ->where('tenant_id', $this->tenantId)
            ->where('name', 'Downtown Demo Menu')
            ->whereNull('deleted_at')
            ->value('id');
        if (! $menuId) {
            $menuId = (int) DB::table('menus')->insertGetId([
                'tenant_id' => $this->tenantId,
                'name' => 'Downtown Demo Menu',
                'name_ar' => 'قائمة داون تاون التجريبية',
                'name_en' => 'Downtown Demo Menu',
                'status' => 'published',
                'priority' => 0,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $products = $this->demoProducts();
        $sections = [
            ['name' => 'Coffee', 'nameAr' => 'قهوة', 'products' => ['DT-COFFEE-TURKISH', 'DT-COFFEE-LATTE']],
            ['name' => 'Cold Drinks', 'nameAr' => 'مشروبات باردة', 'products' => ['DT-DRINK-LEMONADE']],
            ['name' => 'Desserts', 'nameAr' => 'حلويات', 'products' => ['DT-DESSERT-CAKE']],
            ['name' => 'Sandwiches', 'nameAr' => 'سندويشات', 'products' => ['DT-FOOD-WRAP']],
        ];
        foreach ($sections as $sectionOrder => $definition) {
            $sectionId = (int) DB::table('menu_sections')
                ->where('tenant_id', $this->tenantId)
                ->where('menu_id', $menuId)
                ->where('name', $definition['name'])
                ->whereNull('deleted_at')
                ->value('id');
            if (! $sectionId) {
                $sectionId = (int) DB::table('menu_sections')->insertGetId([
                    'tenant_id' => $this->tenantId,
                    'menu_id' => $menuId,
                    'name' => $definition['name'],
                    'name_ar' => $definition['nameAr'],
                    'name_en' => $definition['name'],
                    'sort_order' => $sectionOrder,
                    'is_active' => true,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
            foreach ($definition['products'] as $productOrder => $sku) {
                DB::table('menu_item_placements')->updateOrInsert([
                    'tenant_id' => $this->tenantId,
                    'menu_section_id' => $sectionId,
                    'product_id' => $products[$sku],
                ], [
                    'sort_order' => $productOrder,
                    'is_visible' => true,
                    'updated_at' => $now,
                    'created_at' => $now,
                ]);
            }
        }

        DB::table('menu_assignments')->updateOrInsert([
            'tenant_id' => $this->tenantId,
            'menu_id' => $menuId,
            'branch_id' => $this->branchId,
            'channel' => 'pos',
        ], [
            'priority' => 0,
            'is_active' => true,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        app(MenuPublishingService::class)->publish($this->tenantId, [
            'branchId' => $this->branchId,
            'channel' => 'pos',
        ]);
    }

    /** @return array<string, int> */
    private function demoProducts(): array
    {
        $definitions = [
            ['sku' => 'DT-COFFEE-TURKISH', 'name' => 'Turkish Coffee', 'nameAr' => 'قهوة تركية', 'category' => 'Coffee', 'price' => '45000.00', 'sortOrder' => 100],
            ['sku' => 'DT-COFFEE-LATTE', 'name' => 'Cafe Latte', 'nameAr' => 'كافيه لاتيه', 'category' => 'Coffee', 'price' => '55000.00', 'sortOrder' => 101],
            ['sku' => 'DT-DRINK-LEMONADE', 'name' => 'Fresh Lemonade', 'nameAr' => 'ليموناضة طازجة', 'category' => 'Cold Drinks', 'price' => '50000.00', 'sortOrder' => 102],
            ['sku' => 'DT-DESSERT-CAKE', 'name' => 'Chocolate Cake', 'nameAr' => 'كيك شوكولا', 'category' => 'Desserts', 'price' => '60000.00', 'sortOrder' => 103],
            ['sku' => 'DT-FOOD-WRAP', 'name' => 'Chicken Wrap', 'nameAr' => 'راب دجاج', 'category' => 'Sandwiches', 'price' => '75000.00', 'sortOrder' => 104],
        ];
        $categories = DB::table('categories')
            ->where('tenant_id', $this->tenantId)
            ->whereIn('name', array_column($definitions, 'category'))
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->pluck('id', 'name');
        $products = [];
        foreach ($definitions as $definition) {
            $productId = (int) DB::table('products')
                ->where('tenant_id', $this->tenantId)
                ->where('sku', $definition['sku'])
                ->whereNull('deleted_at')
                ->value('id');
            $values = [
                'category_id' => $categories[$definition['category']],
                'name' => $definition['name'],
                'name_ar' => $definition['nameAr'],
                'name_en' => $definition['name'],
                'description' => 'Downtown demonstration product.',
                'description_ar' => 'منتج تجريبي لفرع داون تاون.',
                'price' => $definition['price'],
                'cost_price' => '0.00',
                'is_active' => true,
                'is_stock_tracked' => false,
                'inventory_controlled' => false,
                'sort_order' => $definition['sortOrder'],
                'updated_at' => now(),
            ];
            if ($productId) {
                DB::table('products')->where('id', $productId)->update($values);
            } else {
                $productId = (int) DB::table('products')->insertGetId($values + [
                    'tenant_id' => $this->tenantId,
                    'sku' => $definition['sku'],
                    'product_type' => 'standard',
                    'consumption_type' => 'bar',
                    'created_at' => now(),
                ]);
            }
            DB::table('product_variants')->updateOrInsert([
                'tenant_id' => $this->tenantId,
                'product_id' => $productId,
                'is_default' => true,
            ], [
                'name' => 'Regular',
                'name_ar' => 'عادي',
                'name_en' => 'Regular',
                'sku' => $definition['sku'].'-REG',
                'base_price' => $definition['price'],
                'cost_price' => '0.00',
                'is_active' => true,
                'sort_order' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $products[$definition['sku']] = $productId;
        }

        return $products;
    }
}
