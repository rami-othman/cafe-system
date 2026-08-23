<?php

namespace Tests\Feature\Admin\Catalog;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CatalogApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_configured_variant_selling_prices_must_be_strictly_positive_at_product_and_variant_boundaries(): void
    {
        $tenantId = $this->tenant('configured-prices');
        $headers = $this->headers($tenantId);

        foreach ([0, -1] as $price) {
            $this->postJson('/api/v1/admin/catalog/products', [
                'name' => "Invalid {$price}",
                'variants' => [['name' => 'Regular', 'basePrice' => $price, 'isDefault' => true, 'isActive' => true]],
            ], $headers)->assertUnprocessable()->assertJsonValidationErrors('variants.0.basePrice');
        }
        $this->assertDatabaseCount('products', 0);

        $productId = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => 'Valid Product',
            'variants' => [['name' => 'Regular', 'basePrice' => '0.01', 'isDefault' => true, 'isActive' => true]],
        ], $headers)->assertCreated()->json('data.id');
        $variantId = (int) DB::table('product_variants')->where('product_id', $productId)->value('id');

        foreach ([0, -1] as $price) {
            $this->postJson("/api/v1/admin/catalog/products/{$productId}/variants", [
                'name' => "Invalid {$price}", 'basePrice' => $price, 'isActive' => true,
            ], $headers)->assertUnprocessable()->assertJsonValidationErrors('basePrice');
        }
        $created = $this->postJson("/api/v1/admin/catalog/products/{$productId}/variants", [
            'name' => 'Large', 'basePrice' => '5.50', 'isActive' => true,
        ], $headers)->assertCreated();
        $largeId = $created->json('data.id');

        foreach ([0, -1] as $price) {
            $this->patchJson("/api/v1/admin/catalog/product-variants/{$variantId}", ['basePrice' => $price], $headers)
                ->assertUnprocessable()->assertJsonValidationErrors('basePrice');
            $this->assertDatabaseHas('product_variants', ['id' => $variantId, 'base_price' => 0.01]);
        }
        $this->patchJson("/api/v1/admin/catalog/product-variants/{$variantId}", ['basePrice' => '1.00'], $headers)
            ->assertOk()->assertJsonPath('data.basePrice', 1);
        $this->assertDatabaseHas('product_variants', ['id' => $largeId, 'base_price' => 5.5]);
    }

    public function test_products_are_tenant_scoped_and_default_variants_sync_the_legacy_pos_fields(): void
    {
        $tenantId = $this->tenant('alpha');
        $categoryId = $this->postJson('/api/v1/admin/catalog/categories', ['name' => 'Coffee'], $this->headers($tenantId))->assertCreated()->json('data.id');

        $created = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => 'Iced Latte', 'categoryId' => $categoryId, 'productType' => 'standard',
            'variants' => [
                ['name' => 'Small', 'sku' => 'LATTE-S', 'basePrice' => 2.5, 'costPrice' => 0.9, 'isDefault' => true, 'isActive' => true],
                ['name' => 'Large', 'sku' => 'LATTE-L', 'basePrice' => 3.5, 'costPrice' => 1.2, 'isDefault' => false, 'isActive' => true],
            ],
        ], $this->headers($tenantId))->assertCreated()->assertJsonPath('data.defaultVariant.sku', 'LATTE-S');
        $productId = $created->json('data.id');

        $this->assertDatabaseHas('products', ['id' => $productId, 'price' => 2.5, 'cost_price' => 0.9, 'sku' => 'LATTE-S']);
        $largeId = DB::table('product_variants')->where('product_id', $productId)->where('sku', 'LATTE-L')->value('id');
        $this->postJson("/api/v1/admin/catalog/product-variants/{$largeId}/set-default", [], $this->headers($tenantId))->assertOk();
        $this->assertDatabaseHas('products', ['id' => $productId, 'price' => 3.5, 'cost_price' => 1.2, 'sku' => 'LATTE-L']);
        $this->getJson("/api/v1/menu/products/{$productId}", $this->headers($tenantId))->assertOk()->assertJsonPath('data.basePrice', 3.5);

        $otherTenantId = $this->tenant('beta');
        $this->getJson("/api/v1/admin/catalog/products/{$productId}", $this->headers($otherTenantId))->assertNotFound();
        $this->assertDatabaseCount('menu_audit_logs', 3);
    }

    public function test_product_detail_optionally_includes_only_its_tenant_archived_variants(): void
    {
        $tenantId = $this->tenant('alpha');
        $otherTenantId = $this->tenant('beta');
        $productId = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => 'Iced Latte',
            'variants' => [
                ['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true],
                ['name' => 'Large', 'basePrice' => 4, 'isDefault' => false, 'isActive' => true],
            ],
        ], $this->headers($tenantId))->assertCreated()->json('data.id');
        $largeId = (int) DB::table('product_variants')->where('product_id', $productId)->where('name', 'Large')->value('id');

        $archive = $this->postJson("/api/v1/admin/catalog/product-variants/{$largeId}/archive", [], $this->headers($tenantId))
            ->assertOk()
            ->assertJsonPath('data.productId', $productId);
        $this->assertNotNull($archive->json('data.archivedAt'));

        $default = $this->getJson("/api/v1/admin/catalog/products/{$productId}", $this->headers($tenantId))
            ->assertOk()
            ->assertJsonPath('data.id', $productId)
            ->assertJsonPath('data.name', 'Iced Latte')
            ->assertJsonPath('data.defaultVariant.productId', $productId);
        $this->assertSame([$productId], array_values(array_unique(array_column($default->json('data.variants'), 'productId'))));
        $this->assertSame(['Regular'], array_column($default->json('data.variants'), 'name'));
        $this->assertNull($default->json('data.variants.0.archivedAt'));

        foreach (['false', '0'] as $value) {
            $response = $this->getJson("/api/v1/admin/catalog/products/{$productId}?includeArchived={$value}", $this->headers($tenantId))->assertOk();
            $this->assertSame(['Regular'], array_column($response->json('data.variants'), 'name'));
        }

        foreach (['true', '1'] as $value) {
            $response = $this->getJson("/api/v1/admin/catalog/products/{$productId}?includeArchived={$value}", $this->headers($tenantId))->assertOk();
            $variants = $response->json('data.variants');
            $this->assertSame(['Regular', 'Large'], array_column($variants, 'name'));
            $this->assertSame([$productId], array_values(array_unique(array_column($variants, 'productId'))));
            $archived = collect($variants)->firstWhere('id', $largeId);
            $this->assertFalse($archived['isActive']);
            $this->assertNotNull($archived['archivedAt']);
        }

        $now = now();
        $foreignArchivedId = DB::table('product_variants')->insertGetId([
            'tenant_id' => $otherTenantId, 'product_id' => $productId, 'name' => 'Foreign archived',
            'base_price' => 9, 'cost_price' => 0, 'is_default' => false, 'is_active' => false,
            'sort_order' => 99, 'created_at' => $now, 'updated_at' => $now, 'deleted_at' => $now,
        ]);
        $included = $this->getJson("/api/v1/admin/catalog/products/{$productId}?includeArchived=true", $this->headers($tenantId))->assertOk()->json('data.variants');
        $this->assertNotContains($foreignArchivedId, array_column($included, 'id'));
    }

    public function test_product_detail_returns_authoritative_variant_and_modifier_counts_and_recipe_summary(): void
    {
        $tenantId = $this->tenant('summary-counts');
        $groupId = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Extras',
            'options' => [['name' => 'Shot']],
        ], $this->headers($tenantId))->assertCreated()->json('data.id');
        $productId = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => 'Latte',
            'variants' => [
                ['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true],
                ['name' => 'Large', 'basePrice' => 4, 'isDefault' => false, 'isActive' => true],
            ],
        ], $this->headers($tenantId))->assertCreated()->json('data.id');
        $this->putJson("/api/v1/admin/catalog/products/$productId/modifier-groups", [
            'groups' => [['modifierGroupId' => $groupId, 'sortOrder' => 0]],
        ], $this->headers($tenantId))->assertOk();

        $detail = $this->getJson("/api/v1/admin/catalog/products/$productId", $this->headers($tenantId))
            ->assertOk()
            ->json('data');

        $this->assertSame(2, $detail['variantCount']);
        $this->assertSame(1, $detail['modifierGroupCount']);
        $this->assertFalse($detail['variants'][0]['recipeConfigured']);
        $this->assertSame(0, $detail['variants'][0]['recipeComponentCount']);
        $this->assertArrayNotHasKey('components', $detail['variants'][0]);

        $largeId = (int) DB::table('product_variants')->where('product_id', $productId)->where('name', 'Large')->value('id');
        $this->postJson("/api/v1/admin/catalog/product-variants/$largeId/archive", [], $this->headers($tenantId))->assertOk();
        $this->assertSame(1, $this->getJson("/api/v1/admin/catalog/products/$productId", $this->headers($tenantId))->json('data.variantCount'));
        $this->postJson("/api/v1/admin/catalog/product-variants/$largeId/restore", [], $this->headers($tenantId))->assertOk();
        $this->assertSame(2, $this->getJson("/api/v1/admin/catalog/products/$productId", $this->headers($tenantId))->json('data.variantCount'));

        $secondGroupId = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Sauces',
            'options' => [['name' => 'Vanilla']],
        ], $this->headers($tenantId))->assertCreated()->json('data.id');
        $this->putJson("/api/v1/admin/catalog/products/$productId/modifier-groups", ['groups' => [
            ['modifierGroupId' => $groupId, 'sortOrder' => 0],
            ['modifierGroupId' => $secondGroupId, 'sortOrder' => 1],
        ]], $this->headers($tenantId))->assertOk();
        $this->putJson("/api/v1/admin/catalog/products/$productId/modifier-groups", ['groups' => [
            ['modifierGroupId' => $secondGroupId, 'sortOrder' => 0],
        ]], $this->headers($tenantId))->assertOk();
        $this->assertSame(1, $this->getJson("/api/v1/admin/catalog/products/$productId", $this->headers($tenantId))->json('data.modifierGroupCount'));
    }

    public function test_product_archive_and_restore_return_the_soft_delete_timestamp(): void
    {
        $tenantId = $this->tenant('archive-product');
        $productId = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => 'Seasonal Latte',
            'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]],
        ], $this->headers($tenantId))->assertCreated()->json('data.id');

        $archived = $this->postJson("/api/v1/admin/catalog/products/{$productId}/archive", [], $this->headers($tenantId))
            ->assertOk()
            ->assertJsonPath('data.isActive', false)
            ->assertJsonPath('data.id', $productId);
        $this->assertNotNull($archived->json('data.archivedAt'));
        $this->assertSoftDeleted('products', ['id' => $productId]);

        $this->postJson("/api/v1/admin/catalog/products/{$productId}/restore", [], $this->headers($tenantId))
            ->assertOk()
            ->assertJsonPath('data.isActive', true)
            ->assertJsonPath('data.archivedAt', null);
        $this->assertDatabaseHas('products', ['id' => $productId, 'is_active' => true, 'deleted_at' => null]);
    }

    public function test_product_lifecycle_filters_keep_active_inactive_and_archived_distinct(): void
    {
        $tenant = $this->tenant('product-lifecycle');
        $headers = $this->headers($tenant);
        $active = $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Active', 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $headers)->assertCreated()->json('data.id');
        $inactive = $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Inactive', 'isActive' => false, 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $headers)->assertCreated()->json('data.id');
        $archived = $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Archived', 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/admin/catalog/products/{$archived}/archive", [], $headers)->assertOk();
        foreach (['active' => [$active], 'inactive' => [$inactive], 'archived' => [$archived], 'all' => [$active, $inactive, $archived]] as $status => $expected) {
            $ids = array_column($this->getJson("/api/v1/admin/catalog/products?status={$status}", $headers)->assertOk()->json('data'), 'id');
            sort($ids);
            sort($expected);
            $this->assertSame($expected, $ids);
        }
    }

    public function test_variant_restore_cannot_bypass_an_inactive_product(): void
    {
        $tenant = $this->tenant('variant-parent-lifecycle');
        $headers = $this->headers($tenant);
        $product = $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Latte', 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true], ['name' => 'Large', 'basePrice' => 4, 'isDefault' => false, 'isActive' => true]]], $headers)->assertCreated()->json('data.id');
        $variant = (int) DB::table('product_variants')->where('product_id', $product)->where('name', 'Large')->value('id');
        $this->postJson("/api/v1/admin/catalog/product-variants/{$variant}/archive", [], $headers)->assertOk();
        $this->patchJson("/api/v1/admin/catalog/products/{$product}", ['isActive' => false], $headers)->assertOk();
        $this->postJson("/api/v1/admin/catalog/product-variants/{$variant}/restore", [], $headers)->assertUnprocessable()->assertJsonValidationErrors('product');
        $this->assertSoftDeleted('product_variants', ['id' => $variant]);
    }

    public function test_category_archive_is_blocked_when_active_products_use_it_and_reorder_is_tenant_safe(): void
    {
        $tenantId = $this->tenant('alpha');
        $category = $this->postJson('/api/v1/admin/catalog/categories', ['name' => 'Coffee'], $this->headers($tenantId))->assertCreated()->json('data.id');
        $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Espresso', 'categoryId' => $category, 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenantId))->assertCreated();
        $this->postJson("/api/v1/admin/catalog/categories/{$category}/archive", [], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('category');

        $other = $this->postJson('/api/v1/admin/catalog/categories', ['name' => 'Tea'], $this->headers($tenantId))->assertCreated()->json('data.id');
        $this->postJson('/api/v1/admin/catalog/categories/reorder', ['items' => [['id' => $category, 'sortOrder' => 2], ['id' => $other, 'sortOrder' => 1]]], $this->headers($tenantId))->assertOk();
        $this->assertDatabaseHas('categories', ['id' => $other, 'sort_order' => 1]);
    }

    public function test_categories_persist_and_return_localized_names(): void
    {
        $tenantId = $this->tenant('localized-categories');
        $headers = $this->headers($tenantId);
        $category = $this->postJson('/api/v1/admin/catalog/categories', [
            'name' => 'Coffee',
            'nameAr' => 'قهوة',
            'nameEn' => 'Coffee',
        ], $headers)->assertCreated()
            ->assertJsonPath('data.nameAr', 'قهوة')
            ->assertJsonPath('data.nameEn', 'Coffee')
            ->json('data.id');

        $this->patchJson("/api/v1/admin/catalog/categories/{$category}", [
            'nameAr' => 'قهوة مختصة',
            'nameEn' => 'Specialty Coffee',
        ], $headers)->assertOk()
            ->assertJsonPath('data.nameAr', 'قهوة مختصة')
            ->assertJsonPath('data.nameEn', 'Specialty Coffee');
        $this->assertDatabaseHas('categories', [
            'id' => $category,
            'name_ar' => 'قهوة مختصة',
            'name_en' => 'Specialty Coffee',
        ]);
    }

    public function test_kitchen_station_contract_excludes_reporting_only_description_field(): void
    {
        $tenantId = $this->tenant('station-contract');
        $station = $this->postJson('/api/v1/admin/catalog/kitchen-stations', [
            'name' => 'Coffee Bar',
            'nameAr' => 'قهوة',
            'nameEn' => 'Coffee Bar',
            'code' => 'BAR',
            'printerName' => 'bar-printer',
            'description' => 'This is not a kitchen station field',
        ], $this->headers($tenantId))->assertCreated()
            ->assertJsonPath('data.code', 'BAR')
            ->assertJsonPath('data.printerName', 'bar-printer');

        $stationId = $station->json('data.id');
        $this->patchJson("/api/v1/admin/catalog/kitchen-stations/{$stationId}", [
            'code' => 'ESPRESSO',
            'printerName' => null,
        ], $this->headers($tenantId))->assertOk()
            ->assertJsonPath('data.code', 'ESPRESSO')
            ->assertJsonPath('data.printerName', null);
        $this->postJson("/api/v1/admin/catalog/kitchen-stations/{$stationId}/archive", [], $this->headers($tenantId))->assertOk();
        $this->postJson("/api/v1/admin/catalog/kitchen-stations/{$stationId}/restore", [], $this->headers($tenantId))->assertOk()
            ->assertJsonPath('data.isActive', true);
    }

    public function test_archived_catalog_references_remain_diagnostic_and_restore_reenables_product_management(): void
    {
        $tenantId = $this->tenant('reference-lifecycle');
        $headers = $this->headers($tenantId);
        $category = $this->postJson('/api/v1/admin/catalog/categories', ['name' => 'Coffee'], $headers)
            ->assertCreated()->json('data.id');
        $reportingCategory = $this->postJson('/api/v1/admin/catalog/reporting-categories', [
            'name' => 'Beverages', 'code' => 'BEVERAGES',
        ], $headers)->assertCreated()->json('data.id');
        $station = $this->postJson('/api/v1/admin/catalog/kitchen-stations', [
            'name' => 'Coffee Bar', 'code' => 'BAR',
        ], $headers)->assertCreated()->json('data.id');
        $product = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => 'Latte',
            'categoryId' => $category,
            'reportingCategoryId' => $reportingCategory,
            'kitchenStationId' => $station,
            'variants' => [['name' => 'Regular', 'basePrice' => 4, 'isDefault' => true, 'isActive' => true]],
        ], $headers)->assertCreated()->json('data.id');

        // Category and Kitchen Station archives are protected while an active
        // Product uses them. Once the Product is archived, every reference may
        // be archived without destructively clearing its foreign keys.
        $this->postJson("/api/v1/admin/catalog/products/{$product}/archive", [], $headers)->assertOk();
        foreach ([
            "categories/{$category}",
            "reporting-categories/{$reportingCategory}",
            "kitchen-stations/{$station}",
        ] as $path) {
            $this->postJson("/api/v1/admin/catalog/{$path}/archive", [], $headers)
                ->assertOk()
                ->assertJsonPath('data.isActive', false);
        }

        $detail = $this->getJson("/api/v1/admin/catalog/products/{$product}?includeArchived=true", $headers)
            ->assertOk()
            ->assertJsonPath('data.category.id', $category)
            ->assertJsonPath('data.reportingCategory.id', $reportingCategory)
            ->assertJsonPath('data.kitchenStation.id', $station);
        foreach (['category', 'reportingCategory', 'kitchenStation'] as $key) {
            $this->assertFalse($detail->json("data.{$key}.isActive"));
        }
        $this->assertDatabaseHas('products', [
            'id' => $product,
            'category_id' => $category,
            'reporting_category_id' => $reportingCategory,
            'kitchen_station_id' => $station,
        ]);
        $this->postJson("/api/v1/admin/catalog/products/{$product}/restore", [], $headers)
            ->assertUnprocessable();

        foreach ([
            "categories/{$category}",
            "reporting-categories/{$reportingCategory}",
            "kitchen-stations/{$station}",
        ] as $path) {
            $this->postJson("/api/v1/admin/catalog/{$path}/restore", [], $headers)
                ->assertOk()
                ->assertJsonPath('data.isActive', true)
                ->assertJsonPath('data.archivedAt', null);
        }
        $this->postJson("/api/v1/admin/catalog/products/{$product}/restore", [], $headers)
            ->assertOk()
            ->assertJsonPath('data.isActive', true);

        $foreignHeaders = $this->headers($this->tenant('reference-lifecycle-foreign'));
        $this->getJson("/api/v1/admin/catalog/reporting-categories/{$reportingCategory}?includeArchived=true", $foreignHeaders)
            ->assertNotFound();
        $this->postJson("/api/v1/admin/catalog/reporting-categories/{$reportingCategory}/archive", [], $foreignHeaders)
            ->assertNotFound();
    }

    public function test_modifier_groups_are_reusable_but_cross_tenant_assignments_are_rejected(): void
    {
        $tenantId = $this->tenant('alpha');
        $groupId = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Milk', 'groupType' => 'choice', 'selectionType' => 'single', 'isRequired' => true, 'minSelections' => 1, 'maxSelections' => 1,
            'options' => [['name' => 'Regular', 'priceDelta' => 0, 'costDelta' => 0, 'isDefault' => true, 'isActive' => true]],
        ], $this->headers($tenantId))->assertCreated()->json('data.id');
        $productId = $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Latte', 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenantId))->assertCreated()->json('data.id');
        $this->putJson("/api/v1/admin/catalog/products/{$productId}/modifier-groups", ['groups' => [['modifierGroupId' => $groupId, 'sortOrder' => 0, 'isRequiredOverride' => true, 'minSelectionsOverride' => 1, 'maxSelectionsOverride' => 1]]], $this->headers($tenantId))->assertOk()->assertJsonPath('data.0.id', $groupId);

        $foreignGroupId = $this->postJson('/api/v1/admin/catalog/modifier-groups', ['name' => 'Foreign', 'selectionType' => 'single', 'minSelections' => 0, 'maxSelections' => 1, 'options' => [['name' => 'Default', 'isActive' => true]]], $this->headers($this->tenant('beta')))->assertCreated()->json('data.id');
        $this->putJson("/api/v1/admin/catalog/products/{$productId}/modifier-groups", ['groups' => [['modifierGroupId' => $foreignGroupId, 'sortOrder' => 0]]], $this->headers($tenantId))->assertUnprocessable();
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenantId): array
    {
        return ['X-Tenant-Id' => (string) $tenantId];
    }
}
