<?php

namespace Tests\Feature\Admin\MenuManagement;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FullMenuManagementLifecycleApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_complete_menu_management_lifecycle_publishes_compares_and_rolls_back_real_data(): void
    {
        $tenant = $this->tenant();
        $branch = $this->branch($tenant);
        $headers = $this->headers($tenant);

        $category = $this->postJson('/api/v1/admin/catalog/categories', [
            'name' => 'Coffee',
            'description' => 'Espresso-based drinks',
        ], $headers)->assertCreated()->json('data.id');
        $reportingCategory = $this->postJson('/api/v1/admin/catalog/reporting-categories', [
            'name' => 'Beverages',
            'nameAr' => 'مشروبات',
            'nameEn' => 'Beverages',
            'code' => 'BEVERAGES',
        ], $headers)->assertCreated()->json('data.id');
        $kitchenStation = $this->postJson('/api/v1/admin/catalog/kitchen-stations', [
            'name' => 'Coffee Bar',
            'nameAr' => 'بار القهوة',
            'nameEn' => 'Coffee Bar',
            'code' => 'COFFEE-BAR',
            'branchId' => $branch,
        ], $headers)->assertCreated()->json('data.id');

        $product = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => 'Latte',
            'nameAr' => 'لاتيه',
            'nameEn' => 'Latte',
            'description' => 'Espresso with steamed milk',
            'categoryId' => $category,
            'reportingCategoryId' => $reportingCategory,
            'kitchenStationId' => $kitchenStation,
            'productType' => 'standard',
            'isStockTracked' => true,
            'variants' => [
                ['name' => 'Small', 'basePrice' => '3.50', 'costPrice' => '1.10', 'isDefault' => false, 'isActive' => true, 'sortOrder' => 0],
                ['name' => 'Medium', 'basePrice' => '4.00', 'costPrice' => '1.30', 'isDefault' => true, 'isActive' => true, 'sortOrder' => 1],
                ['name' => 'Large', 'basePrice' => '4.50', 'costPrice' => '1.50', 'isDefault' => false, 'isActive' => true, 'sortOrder' => 2],
            ],
        ], $headers)->assertCreated()
            ->assertJsonPath('data.nameAr', 'لاتيه')
            ->assertJsonPath('data.isStockTracked', true)
            ->assertJsonCount(3, 'data.variants')
            ->json('data.id');

        $variants = DB::table('product_variants')
            ->where('tenant_id', $tenant)
            ->where('product_id', $product)
            ->pluck('id', 'name');
        $small = (int) $variants['Small'];
        $medium = (int) $variants['Medium'];
        $large = (int) $variants['Large'];

        $beans = $this->material($tenant, 'Espresso Beans', 'BEANS', 'kilogram');
        $milk = $this->material($tenant, 'Regular Milk', 'MILK', 'liter');
        $oatMilk = $this->material($tenant, 'Oat Milk', 'OAT-MILK', 'liter');
        foreach ([
            $small => ['beans' => '16', 'milk' => '200'],
            $medium => ['beans' => '18', 'milk' => '250'],
            $large => ['beans' => '20', 'milk' => '300'],
        ] as $variant => $amounts) {
            $this->putJson("/api/v1/admin/catalog/product-variants/{$variant}/recipe", [
                'components' => [
                    ['materialId' => $beans, 'quantity' => $amounts['beans'], 'unitCode' => 'g', 'sortOrder' => 0],
                    ['materialId' => $milk, 'quantity' => $amounts['milk'], 'unitCode' => 'ml', 'sortOrder' => 1],
                ],
            ], $headers)->assertOk()->assertJsonCount(2, 'data.components');
        }

        $milkGroup = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Milk Type',
            'selectionType' => 'single',
            'isRequired' => true,
            'minSelections' => 1,
            'maxSelections' => 1,
            'allowQuantity' => false,
            'options' => [
                ['name' => 'Regular Milk', 'priceDelta' => '0', 'isDefault' => true, 'isActive' => true, 'isAvailable' => true],
                ['name' => 'Oat Milk', 'priceDelta' => '0.75', 'isDefault' => false, 'isActive' => true, 'isAvailable' => true],
            ],
        ], $headers)->assertCreated()->json('data.id');
        $shotsGroup = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Extra Shots',
            'groupType' => 'add_on',
            'selectionType' => 'multiple',
            'isRequired' => false,
            'minSelections' => 0,
            'maxSelections' => 2,
            'allowQuantity' => true,
            'options' => [
                ['name' => 'Extra Shot', 'priceDelta' => '0.80', 'isDefault' => false, 'isActive' => true, 'isAvailable' => true],
            ],
        ], $headers)->assertCreated()->json('data.id');
        $regularMilk = $this->option($tenant, $milkGroup, 'Regular Milk');
        $oatMilkOption = $this->option($tenant, $milkGroup, 'Oat Milk');
        $extraShot = $this->option($tenant, $shotsGroup, 'Extra Shot');

        $this->putJson("/api/v1/admin/catalog/modifier-options/{$extraShot}/recipe-adjustments", [
            'components' => [
                ['materialId' => $beans, 'operation' => 'add', 'quantity' => '18', 'unitCode' => 'g', 'sortOrder' => 0],
            ],
        ], $headers)->assertOk()->assertJsonPath('data.scope', 'global');
        $this->putJson("/api/v1/admin/catalog/products/{$product}/modifier-groups", [
            'groups' => [
                ['modifierGroupId' => $milkGroup, 'sortOrder' => 0],
                ['modifierGroupId' => $shotsGroup, 'sortOrder' => 1],
            ],
        ], $headers)->assertOk()->assertJsonCount(2, 'data');
        foreach ([$small => '200', $medium => '250', $large => '300'] as $variant => $milkQuantity) {
            $this->putJson("/api/v1/admin/catalog/product-variants/{$variant}/modifier-options/{$oatMilkOption}/recipe-adjustments", [
                'components' => [
                    ['materialId' => $milk, 'operation' => 'remove', 'quantity' => $milkQuantity, 'unitCode' => 'ml', 'sortOrder' => 0],
                    ['materialId' => $oatMilk, 'operation' => 'add', 'quantity' => $milkQuantity, 'unitCode' => 'ml', 'sortOrder' => 1],
                ],
            ], $headers)->assertOk()->assertJsonPath('data.scope', 'variant');
        }

        $simulation = $this->postJson("/api/v1/admin/catalog/product-variants/{$medium}/recipe/resolve", [
            'selectedOptions' => [
                ['optionId' => $oatMilkOption],
                ['optionId' => $extraShot, 'quantity' => 2],
            ],
        ], $headers)->assertOk();
        $simulated = collect($simulation->json('data.components'))->keyBy('materialId');
        $this->assertSame('54', $simulated[$beans]['quantity']);
        $this->assertSame('250', $simulated[$oatMilk]['quantity']);
        $this->assertArrayNotHasKey($milk, $simulated->all());

        $menu = $this->postJson('/api/v1/admin/menus', [
            'name' => 'All Day Menu',
            'nameAr' => 'قائمة طوال اليوم',
            'nameEn' => 'All Day Menu',
            'status' => 'draft',
        ], $headers)->assertCreated()->json('data.id');
        $coffeeSection = $this->postJson("/api/v1/admin/menus/{$menu}/sections", [
            'name' => 'Coffee',
            'nameAr' => 'قهوة',
            'nameEn' => 'Coffee',
            'sortOrder' => 0,
        ], $headers)->assertCreated()->json('data.id');
        $seasonalSection = $this->postJson("/api/v1/admin/menus/{$menu}/sections", [
            'name' => 'Seasonal',
            'nameAr' => 'موسمي',
            'nameEn' => 'Seasonal',
            'sortOrder' => 1,
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/admin/menus/{$menu}/sections/reorder", [
            'items' => [
                ['id' => $coffeeSection, 'sortOrder' => 0],
                ['id' => $seasonalSection, 'sortOrder' => 1],
            ],
        ], $headers)->assertOk();
        $placement = $this->postJson("/api/v1/admin/menu-sections/{$coffeeSection}/placements", [
            'productId' => $product,
            'sortOrder' => 0,
            'isVisible' => true,
        ], $headers)->assertCreated()->json('data.id');

        $this->putJson('/api/v1/admin/menu-management/assignments', [
            'branchId' => $branch,
            'channel' => 'pos',
            'assignments' => [
                ['menuId' => $menu, 'priority' => 0, 'isActive' => true],
            ],
        ], $headers)->assertOk()->assertJsonPath('data.0.menuId', $menu);
        $this->putJson("/api/v1/admin/menus/{$menu}/availability-rules", [
            'rules' => [
                ['branchId' => $branch, 'channel' => 'pos', 'startDate' => '2020-01-01', 'endDate' => '2099-12-31', 'priority' => 0, 'isActive' => true],
            ],
        ], $headers)->assertOk()->assertJsonCount(1, 'data');
        $this->putJson("/api/v1/admin/catalog/product-variants/{$medium}/price-overrides", [
            'overrides' => [
                ['scopeType' => 'branch_channel', 'branchId' => $branch, 'channel' => 'pos', 'overridePrice' => '5.25', 'isActive' => true],
            ],
        ], $headers)->assertOk()->assertJsonPath('data.overrides.0.overridePrice', 5.25);
        $this->putJson("/api/v1/admin/catalog/products/{$product}/availability-rules", [
            'rules' => [
                ['branchId' => $branch, 'channel' => 'pos', 'startDate' => '2020-01-01', 'endDate' => '2099-12-31', 'priority' => 0, 'isActive' => true],
            ],
        ], $headers)->assertOk()->assertJsonCount(1, 'data.rules');
        $this->putJson("/api/v1/admin/catalog/product-variants/{$medium}/operational-availability", [
            'branchId' => $branch,
            'channel' => 'pos',
            'status' => 'available',
            'remainingQuantity' => '12',
        ], $headers)->assertOk()->assertJsonPath('data.status', 'available');

        $context = ['branchId' => $branch, 'channel' => 'pos', 'menuIds' => [$menu]];
        $validation = $this->postJson('/api/v1/admin/menu-management/validate', $context, $headers)
            ->assertOk()
            ->assertJsonPath('data.isValid', true);
        $this->assertSame([], $validation->json('data.errors'));
        $this->assertGreaterThan(0, $validation->json('data.warningCount'));

        $preview = $this->postJson('/api/v1/admin/menu-management/preview', $context + [
            'at' => '2026-08-14T12:00:00+03:00',
            'language' => 'en',
            'includeHidden' => true,
            'includeUnavailable' => true,
        ], $headers)->assertOk()
            ->assertJsonPath('data.context.timezone', 'Asia/Damascus')
            ->assertJsonPath('data.menus.0.sections.0.products.0.productId', $product)
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.1.id', $medium)
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.1.effectivePrice', 5.25)
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.1.recipeConfigured', true)
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.1.recipeComponentCount', 2)
            ->assertJsonCount(2, 'data.menus.0.sections.0.products.0.modifierGroups');
        $this->assertArrayNotHasKey('baseRecipe', $preview->json('data.menus.0.sections.0.products.0.variants.1'));

        $versionOne = $this->postJson('/api/v1/admin/menu-management/publish', $context, $headers)
            ->assertOk()
            ->assertJsonPath('data.published', true)
            ->assertJsonPath('data.version.versionNumber', 1)
            ->json('data.version');
        $payloadOne = (string) DB::table('published_menu_versions')->where('id', $versionOne['id'])->value('payload_json');
        $snapshotOne = json_decode($payloadOne, true);
        $this->assertSame(2, $snapshotOne['context']['schemaVersion']);
        $this->assertSame('5.25', $snapshotOne['menus'][0]['sections'][0]['products'][0]['variants'][1]['effectivePrice']);
        $this->assertStringNotContainsString('remainingQuantity', $payloadOne);
        $this->assertStringNotContainsString('operational', strtolower($payloadOne));

        $this->putJson("/api/v1/admin/catalog/product-variants/{$medium}/price-overrides", [
            'overrides' => [
                ['scopeType' => 'branch_channel', 'branchId' => $branch, 'channel' => 'pos', 'overridePrice' => '5.75', 'isActive' => true],
            ],
        ], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/product-variants/{$medium}/recipe", [
            'components' => [
                ['materialId' => $beans, 'quantity' => '20', 'unitCode' => 'g', 'sortOrder' => 0],
                ['materialId' => $milk, 'quantity' => '250', 'unitCode' => 'ml', 'sortOrder' => 1],
            ],
        ], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/modifier-options/{$extraShot}/recipe-adjustments", [
            'components' => [
                ['materialId' => $beans, 'operation' => 'add', 'quantity' => '20', 'unitCode' => 'g', 'sortOrder' => 0],
            ],
        ], $headers)->assertOk();

        $this->postJson('/api/v1/admin/menu-management/validate', $context, $headers)
            ->assertOk()
            ->assertJsonPath('data.isValid', true);
        $versionTwo = $this->postJson('/api/v1/admin/menu-management/publish', $context, $headers)
            ->assertOk()
            ->assertJsonPath('data.published', true)
            ->assertJsonPath('data.version.versionNumber', 2)
            ->json('data.version');
        $payloadTwo = (string) DB::table('published_menu_versions')->where('id', $versionTwo['id'])->value('payload_json');

        $comparison = $this->getJson(
            "/api/v1/admin/menu-management/versions/{$versionOne['id']}/compare?againstVersionId={$versionTwo['id']}",
            $headers,
        )->assertOk()->assertJsonPath('data.sameChecksum', false);
        $this->assertContains($medium, $comparison->json('data.changes.priceChanges'));
        $recipeChanges = collect($comparison->json('data.changes.recipeChanges'));
        $this->assertTrue($recipeChanges->contains(fn (array $change) => $change['variantId'] === $medium && $change['type'] === 'base_component_changed'));
        $this->assertTrue($recipeChanges->contains(fn (array $change) => $change['variantId'] === $medium && $change['type'] === 'modifier_adjustment_changed'));

        $rollback = $this->postJson(
            "/api/v1/admin/menu-management/versions/{$versionOne['id']}/rollback",
            ['reason' => 'Restore the verified Latte menu'],
            $headers,
        )->assertOk()
            ->assertJsonPath('data.rolledBack', true)
            ->assertJsonPath('data.version.versionNumber', 3)
            ->json('data.version');

        $this->getJson("/api/v1/admin/menu-management/current-version?branchId={$branch}&channel=pos", $headers)
            ->assertOk()
            ->assertJsonPath('data.id', $rollback['id'])
            ->assertJsonPath('data.versionNumber', 3);
        $this->assertSame($versionOne['checksum'], $rollback['checksum']);
        $this->assertSame($payloadOne, (string) DB::table('published_menu_versions')->where('id', $versionOne['id'])->value('payload_json'));
        $this->assertSame($payloadTwo, (string) DB::table('published_menu_versions')->where('id', $versionTwo['id'])->value('payload_json'));
        $this->assertSame($payloadOne, (string) DB::table('published_menu_versions')->where('id', $rollback['id'])->value('payload_json'));
        $this->assertDatabaseHas('published_menu_versions', ['id' => $versionOne['id'], 'status' => 'superseded']);
        $this->assertDatabaseHas('published_menu_versions', ['id' => $versionTwo['id'], 'status' => 'rolled_back']);
        $this->assertDatabaseHas('published_menu_versions', ['id' => $rollback['id'], 'status' => 'current']);
        $this->assertDatabaseHas('menu_item_placements', ['id' => $placement, 'product_id' => $product, 'deleted_at' => null]);
        $this->assertDatabaseHas('modifier_options', ['id' => $regularMilk, 'deleted_at' => null]);

        // Material archival is Inventory-owned, but recipe references and old
        // snapshots must remain diagnostic while new recipe writes are blocked.
        DB::table('inventory_items')->where('id', $beans)->update([
            'is_active' => false,
            'deleted_at' => now(),
        ]);
        $this->getJson("/api/v1/admin/catalog/product-variants/{$medium}/recipe", $headers)
            ->assertOk()
            ->assertJsonPath('data.components.0.materialId', $beans);
        $this->putJson("/api/v1/admin/catalog/product-variants/{$medium}/recipe", [
            'components' => [['materialId' => $beans, 'quantity' => '20', 'unitCode' => 'g']],
        ], $headers)->assertUnprocessable();
        $historical = $this->getJson(
            "/api/v1/admin/menu-management/versions/{$versionOne['id']}?includePayload=true",
            $headers,
        )->assertOk()->json('data.payload.menus.0.sections.0.products.0.variants');
        $historicalMedium = collect($historical)->firstWhere('id', $medium);
        $this->assertSame($beans, $historicalMedium['baseRecipe'][0]['materialId']);
        $this->assertSame('18', $historicalMedium['baseRecipe'][0]['quantity']);
        DB::table('inventory_items')->where('id', $beans)->update([
            'is_active' => true,
            'deleted_at' => null,
        ]);
        $this->putJson("/api/v1/admin/catalog/product-variants/{$medium}/recipe", [
            'components' => [
                ['materialId' => $beans, 'quantity' => '20', 'unitCode' => 'g'],
                ['materialId' => $milk, 'quantity' => '250', 'unitCode' => 'ml'],
            ],
        ], $headers)->assertOk();
    }

    private function tenant(): int
    {
        return DB::table('tenants')->insertGetId([
            'name' => 'Integrated Cafe',
            'slug' => 'integrated-cafe',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function branch(int $tenant): int
    {
        return DB::table('branches')->insertGetId([
            'tenant_id' => $tenant,
            'name' => 'Downtown',
            'timezone' => 'Asia/Damascus',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function material(int $tenant, string $name, string $sku, string $unit): int
    {
        return DB::table('inventory_items')->insertGetId([
            'tenant_id' => $tenant,
            'name' => $name,
            'sku' => $sku,
            'unit' => $unit,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function option(int $tenant, int $group, string $name): int
    {
        return (int) DB::table('modifier_options')
            ->where('tenant_id', $tenant)
            ->where('modifier_group_id', $group)
            ->where('name', $name)
            ->value('id');
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
