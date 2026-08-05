<?php

namespace Tests\Feature\Admin\Catalog;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CatalogApiTest extends TestCase
{
    use RefreshDatabase;

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
