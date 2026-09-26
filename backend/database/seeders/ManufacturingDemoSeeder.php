<?php

namespace Database\Seeders;

use App\Domain\Manufacturing\ManufacturingRecipeService;
use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Services\InventoryItemService;
use App\Services\FinancialSetupService;
use App\Services\StockMovementService;
use App\Services\UserBranchAssignmentService;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

/**
 * Idempotent dev/demo catalog + recipes for Manufacturing. Not wired into
 * DatabaseSeeder — run explicitly: php artisan db:seed --class=ManufacturingDemoSeeder
 *
 * Every item is looked up by SKU before creating it, and every recipe by its
 * output item before creating it, so re-running this seeder is a no-op past
 * the first run. Matches Cafe618InventoryOperationsDemoSeeder's environment
 * guard — never runs automatically in production.
 */
final class ManufacturingDemoSeeder extends Seeder
{
    private int $tenantId;

    private int $branchId;

    private int $warehouseId;

    private int $ownerId;

    private Request $request;

    public function run(): void
    {
        if (! app()->environment(['local', 'development', 'testing'])) {
            throw new RuntimeException('ManufacturingDemoSeeder is restricted to local, development, and testing environments.');
        }

        DB::transaction(fn () => $this->seedDemo());
    }

    private function seedDemo(): void
    {

        $this->tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        if (! $this->tenantId) {
            throw new RuntimeException('Run the base Cafe 618 seeders first (tenant "cafe-618" not found).');
        }
        $this->ownerId = (int) DB::table('users')->where('tenant_id', $this->tenantId)->where('role', 'owner')->value('id');
        if (! $this->ownerId) {
            throw new RuntimeException('A tenant owner is required for the manufacturing demo.');
        }
        $branch = DB::table('branches')->where('tenant_id', $this->tenantId)->where('name', 'المعمل التجريبي')->first();
        if ($branch && ($branch->deleted_at !== null || ! $branch->is_active || $branch->branch_type !== 'factory')) {
            throw new RuntimeException('The demo branch name is already used by an incompatible branch.');
        }
        $this->branchId = $branch ? (int) $branch->id : (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'المعمل التجريبي', 'branch_type' => 'factory',
            'currency' => 'SYP', 'timezone' => 'Asia/Damascus', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        app(FinancialSetupService::class)->ensureForTenant($this->tenantId, $this->branchId, $this->ownerId);
        $this->warehouseId = (int) DB::table('branches')->where('id', $this->branchId)->value('pos_inventory_warehouse_id');
        \App\Support\FactoryWarehouseScope::assertDestination($this->tenantId, $this->branchId, $this->warehouseId);
        if (! $this->warehouseId) {
            throw new RuntimeException('The demo factory needs its private warehouse.');
        }
        DB::table('user_branches')->insertOrIgnore([
            'tenant_id' => $this->tenantId, 'user_id' => $this->ownerId, 'branch_id' => $this->branchId,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->request = Request::create('/', 'POST');
        $this->request->attributes->set('tenant_id', $this->tenantId);

        $items = app(InventoryItemService::class);
        $movements = app(StockMovementService::class);
        $recipes = app(ManufacturingRecipeService::class);

        $raw = [
            'flour' => ['طحين', 'Flour', 'kilogram', 18333],
            'sugar' => ['سكر', 'Sugar', 'kilogram', 15833],
            'eggs' => ['بيض', 'Eggs', 'piece', 2500],
            'milk' => ['حليب', 'Milk', 'liter', 8000],
            'chocolate' => ['شوكولا', 'Chocolate', 'gram', 78.75],
            'cream' => ['كريمة', 'Cream', 'kilogram', 35000],
            'starch' => ['نشاء', 'Starch', 'kilogram', 45000],
            'vanilla' => ['فانيليا', 'Vanilla', 'milliliter', 1200],
            'butter' => ['زبدة', 'Butter', 'kilogram', 42000],
        ];
        $packaging = [
            'cakebox' => ['علبة كيك', 'Cake Box', 'piece', 5000],
            'cakeboard' => ['قاعدة كيك', 'Cake Board', 'piece', 2000],
            'sticker' => ['ملصق', 'Sticker', 'piece', 500],
        ];
        $semi = [
            'pastrycream' => ['كريمة باتيسري', 'Pastry Cream', 'kilogram'],
            'caramel' => ['صوص كراميل', 'Caramel Sauce', 'kilogram'],
        ];
        $finished = [
            'cake' => ['كيك شوكولا', 'Chocolate Cake', 'piece'],
            'eclair' => ['إكلير', 'Eclair', 'piece'],
            'croissant' => ['كرواسون زبدة', 'Butter Croissant', 'piece'],
        ];

        $ids = [];
        foreach ($raw as $sku => [$ar, $en, $unit, $cost]) {
            $ids[$sku] = $this->ensureItem($items, $sku, 'raw_material', $ar, $en, $unit, (string) $cost);
            $qty = in_array($unit, ['gram', 'milliliter']) ? '5000' : ($unit === 'piece' ? '100' : '50');
            $this->ensureOpeningStock($movements, $ids[$sku], (string) $cost, $qty);
        }
        foreach ($packaging as $sku => [$ar, $en, $unit, $cost]) {
            $ids[$sku] = $this->ensureItem($items, $sku, 'packaging', $ar, $en, $unit, (string) $cost);
            $this->ensureOpeningStock($movements, $ids[$sku], (string) $cost, '50');
        }
        foreach ($semi as $sku => [$ar, $en, $unit]) {
            $ids[$sku] = $this->ensureItem($items, $sku, 'semi_finished_good', $ar, $en, $unit, '0');
        }
        foreach ($finished as $sku => [$ar, $en, $unit]) {
            $ids[$sku] = $this->ensureItem($items, $sku, 'finished_good', $ar, $en, $unit, '0');
        }

        // Chocolate Cake — output 4 pieces, shelf life 3 days.
        $this->ensureRecipe($recipes, $ids['cake'], '4', 'piece', [
            [$ids['flour'], '2.4', 'kilogram'], [$ids['sugar'], '1.2', 'kilogram'], [$ids['eggs'], '16', 'piece'],
            [$ids['chocolate'], '800', 'gram'], [$ids['cream'], '2', 'kilogram'], [$ids['cakebox'], '4', 'piece'],
        ], 3, 'days');

        // Pastry Cream (semi-finished) — output 8kg.
        $this->ensureRecipe($recipes, $ids['pastrycream'], '8', 'kilogram', [
            [$ids['milk'], '5', 'liter'], [$ids['sugar'], '3', 'kilogram'], [$ids['starch'], '0.8', 'kilogram'], [$ids['vanilla'], '20', 'milliliter'],
        ], 4, 'days');

        // Eclair — consumes Pastry Cream, not the raw materials that made it.
        $this->ensureRecipe($recipes, $ids['eclair'], '10', 'piece', [
            [$ids['flour'], '0.8', 'kilogram'], [$ids['eggs'], '6', 'piece'], [$ids['pastrycream'], '1.5', 'kilogram'], [$ids['chocolate'], '300', 'gram'],
        ], 2, 'days');

        // Butter Croissant — output 24 pieces.
        $this->ensureRecipe($recipes, $ids['croissant'], '24', 'piece', [
            [$ids['flour'], '6', 'kilogram'], [$ids['butter'], '3', 'kilogram'], [$ids['eggs'], '4', 'piece'], [$ids['sugar'], '0.5', 'kilogram'],
        ], 2, 'days');

        $this->ensureFactoryManagerDemoUser();

        $this->command?->info('Manufacturing demo catalog + recipes ready (idempotent).');
    }

    /**
     * Phase 1 (factory_manager role): a single demo user bound only to the
     * demo factory branch, for local acceptance testing of the new role.
     * Idempotent — reuses the existing user by email if the seeder reruns.
     */
    private function ensureFactoryManagerDemoUser(): void
    {
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($this->tenantId);
        $role = $roles[DefaultTenantRoleService::FACTORY_MANAGER];
        $email = 'factory.demo@cafe618.test';

        $user = User::query()->where('tenant_id', $this->tenantId)->where('email', $email)->first();
        if (! $user) {
            $user = User::query()->create([
                'tenant_id' => $this->tenantId,
                'tenant_role_id' => $role->id,
                'name' => 'Factory Manager (Demo)',
                'email' => $email,
                'password' => Hash::make('FactoryDemo123'),
                'role' => $role->code,
                'is_active' => true,
                'must_change_password' => false,
            ]);
        }
        app(UserBranchAssignmentService::class)->assign($user, \App\Models\Branch::query()->findOrFail($this->branchId));
    }

    private function ensureItem(InventoryItemService $items, string $sku, string $type, string $nameAr, string $nameEn, string $unit, string $cost): int
    {
        $existing = DB::table('inventory_items')->where('tenant_id', $this->tenantId)->where('sku', 'MFGDEMO-'.strtoupper($sku))->first();
        if ($existing) {
            if ($existing->deleted_at !== null || ! $existing->is_active || $existing->item_type !== $type || $existing->unit !== $unit) {
                throw new RuntimeException('An incompatible inventory item uses demo SKU '.$existing->sku);
            }
            DB::table('inventory_item_warehouses')->insertOrIgnore([
                'tenant_id' => $this->tenantId, 'inventory_item_id' => $existing->id, 'warehouse_id' => $this->warehouseId,
                'created_at' => now(), 'updated_at' => now(),
            ]);
            return (int) $existing->id;
        }

        return $items->save($this->request, $this->tenantId, [
            'nameAr' => $nameAr, 'nameEn' => $nameEn, 'sku' => 'MFGDEMO-'.strtoupper($sku), 'itemType' => $type, 'unit' => $unit,
            'minimumStock' => '1', 'reorderLevel' => '2', 'latestUnitCost' => $cost, 'isActive' => true, 'warehouseIds' => [$this->warehouseId],
        ], $this->ownerId);
    }

    private function ensureOpeningStock(StockMovementService $movements, int $itemId, string $unitCost, string $qty): void
    {
        $key = 'mfgdemo-opening-'.$itemId;
        if (DB::table('stock_movements')->where('tenant_id', $this->tenantId)->where('idempotency_key', $key)->exists()) {
            return;
        }
        $movements->record($this->request, $this->tenantId, [
            'warehouseId' => $this->warehouseId, 'itemId' => $itemId, 'type' => 'opening_balance', 'quantity' => $qty, 'unitCost' => $unitCost,
            'reason' => 'Manufacturing demo opening stock', 'idempotencyKey' => $key,
        ], $this->ownerId);
    }

    /** @param list<array{0:int,1:string,2:string}> $lines */
    private function ensureRecipe(ManufacturingRecipeService $recipes, int $productItemId, string $outputQty, string $outputUnit, array $lines, int $shelfDays, string $shelfUnit): void
    {
        if (DB::table('manufacturing_recipes')->where('tenant_id', $this->tenantId)->where('product_item_id', $productItemId)->exists()) {
            return;
        }
        $recipes->create($this->request, $this->tenantId, [
            'productItemId' => $productItemId, 'outputQuantity' => $outputQty, 'outputUnit' => $outputUnit,
            'shelfLifeValue' => $shelfDays, 'shelfLifeUnit' => $shelfUnit,
            'lines' => array_map(fn ($l) => ['inventoryItemId' => $l[0], 'quantity' => $l[1], 'unit' => $l[2]], $lines),
        ], $this->ownerId);
    }
}
