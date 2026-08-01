<?php

namespace Tests\Feature\Admin\Menu;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuSectionContractApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_menu_detail_include_archived_is_validated_tenant_safe_and_authoritatively_ordered(): void
    {
        $alpha = $this->tenant('alpha');
        $beta = $this->tenant('beta');
        $menu = $this->menu($alpha, 'Alpha');
        $first = $this->section($alpha, $menu, 'First', 4);
        $archived = $this->section($alpha, $menu, 'Archived', 1);
        $second = $this->section($alpha, $menu, 'Second', 7);
        $this->postJson("/api/v1/admin/menu-sections/{$archived}/archive", [], $this->headers($alpha))->assertOk();
        $otherMenu = $this->menu($alpha, 'Other');
        $this->section($alpha, $otherMenu, 'Other only', 0);
        DB::table('menu_sections')->insert([
            'tenant_id' => $beta, 'menu_id' => $menu, 'name' => 'Malformed foreign', 'sort_order' => 0,
            'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);

        foreach (['', 'false', '0'] as $value) {
            $suffix = $value === '' ? '' : "?includeArchived={$value}";
            $response = $this->getJson("/api/v1/admin/menus/{$menu}{$suffix}", $this->headers($alpha))->assertOk();
            $this->assertSame([$first, $second], collect($response->json('data.sections'))->pluck('id')->all());
        }
        foreach (['true', '1'] as $value) {
            $response = $this->getJson("/api/v1/admin/menus/{$menu}?includeArchived={$value}", $this->headers($alpha))->assertOk();
            $this->assertSame([$archived, $first, $second], collect($response->json('data.sections'))->pluck('id')->all());
        }
        $this->getJson("/api/v1/admin/menus/{$menu}?includeArchived=yes", $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('includeArchived');
        $this->getJson("/api/v1/admin/menus/{$menu}", $this->headers($beta))->assertNotFound();
    }

    public function test_menu_and_section_resource_lifecycle_metadata_and_placement_count_are_scoped(): void
    {
        $alpha = $this->tenant('alpha');
        $beta = $this->tenant('beta');
        $menu = $this->menu($alpha, 'Alpha');
        $section = $this->section($alpha, $menu, 'Coffee', 0);
        $unrelated = $this->section($alpha, $menu, 'Tea', 1);
        $alphaProduct = $this->product($alpha, 'Latte');
        $archivedProduct = $this->product($alpha, 'Mocha');
        $betaProduct = $this->product($beta, 'Foreign');
        $this->placement($alpha, $section, $alphaProduct, false);
        $archivedPlacement = $this->placement($alpha, $section, $archivedProduct, true);
        DB::table('menu_item_placements')->where('id', $archivedPlacement)->update(['deleted_at' => now()]);
        $this->placement($alpha, $unrelated, $archivedProduct, true);
        $this->placement($beta, $section, $betaProduct, true);

        $response = $this->getJson("/api/v1/admin/menus/{$menu}?includeArchived=true", $this->headers($alpha))->assertOk()->assertJsonPath('data.archivedAt', null);
        $resource = collect($response->json('data.sections'))->firstWhere('id', $section);
        $this->assertSame($menu, $resource['menuId']);
        $this->assertNull($resource['archivedAt']);
        $this->assertSame(1, $resource['placementCount']);
        $this->assertArrayNotHasKey('tenantId', $resource);
        $this->assertArrayNotHasKey('tenantId', $response->json('data'));

        $this->postJson("/api/v1/admin/menu-sections/{$section}/archive", [], $this->headers($alpha))->assertOk()->assertJsonPath('data.archivedAt', fn ($value) => $value !== null);
        $this->assertDatabaseHas('products', ['id' => $alphaProduct]);
        $this->postJson("/api/v1/admin/menus/{$menu}/archive", [], $this->headers($alpha))->assertOk()->assertJsonPath('data.archivedAt', fn ($value) => $value !== null);
        $this->assertDatabaseHas('menu_sections', ['id' => $section]);
        $this->assertDatabaseHas('menu_item_placements', ['menu_section_id' => $section, 'product_id' => $alphaProduct]);
    }

    public function test_archived_parent_rejects_every_section_mutation_and_restore_reenables_valid_changes(): void
    {
        $tenant = $this->tenant('alpha');
        $menu = $this->menu($tenant, 'Main');
        $first = $this->section($tenant, $menu, 'First', 3);
        $second = $this->section($tenant, $menu, 'Second', 8);
        $archived = $this->section($tenant, $menu, 'Archived', 12);
        $this->postJson("/api/v1/admin/menu-sections/{$archived}/archive", [], $this->headers($tenant))->assertOk();
        $this->postJson("/api/v1/admin/menus/{$menu}/archive", [], $this->headers($tenant))->assertOk();

        $this->postJson("/api/v1/admin/menus/{$menu}/sections", ['name' => 'Blocked'], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menu');
        $this->patchJson("/api/v1/admin/menu-sections/{$first}", ['name' => 'Blocked update'], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menu');
        $this->postJson("/api/v1/admin/menu-sections/{$first}/archive", [], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menu');
        $this->postJson("/api/v1/admin/menu-sections/{$archived}/restore", [], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menu');
        $this->postJson("/api/v1/admin/menus/{$menu}/sections/reorder", ['items' => [['id' => $second, 'sortOrder' => 0], ['id' => $first, 'sortOrder' => 1]]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menu');
        $this->assertDatabaseHas('menu_sections', ['id' => $first, 'name' => 'First', 'sort_order' => 3, 'deleted_at' => null]);
        $this->assertDatabaseHas('menu_sections', ['id' => $second, 'sort_order' => 8, 'deleted_at' => null]);
        $this->assertDatabaseMissing('menu_sections', ['name' => 'Blocked']);

        $this->postJson("/api/v1/admin/menus/{$menu}/restore", [], $this->headers($tenant))->assertOk();
        $this->patchJson("/api/v1/admin/menu-sections/{$first}", ['name' => 'Restored parent works'], $this->headers($tenant))->assertOk();
        $this->assertDatabaseHas('menu_sections', ['id' => $archived, 'is_active' => false]);
        $this->postJson("/api/v1/admin/menu-sections/{$archived}/restore", [], $this->headers($tenant))->assertOk();
        $this->assertDatabaseHas('menu_sections', ['id' => $archived, 'deleted_at' => null, 'is_active' => true]);
        $this->assertDatabaseCount('menu_assignments', 0);
        $this->assertDatabaseCount('published_menu_versions', 0);
    }

    public function test_section_routes_and_reorder_are_tenant_and_menu_isolated_and_fail_without_partial_changes(): void
    {
        $alpha = $this->tenant('alpha');
        $beta = $this->tenant('beta');
        $menu = $this->menu($alpha, 'Alpha');
        $first = $this->section($alpha, $menu, 'First', 4);
        $second = $this->section($alpha, $menu, 'Second', 9);
        $archived = $this->section($alpha, $menu, 'Archived', 12);
        $this->postJson("/api/v1/admin/menu-sections/{$archived}/archive", [], $this->headers($alpha))->assertOk();
        $foreignMenu = $this->menu($beta, 'Beta');
        $foreignSection = $this->section($beta, $foreignMenu, 'Foreign', 0);
        $otherAlphaMenu = $this->menu($alpha, 'Other alpha');
        $otherAlphaSection = $this->section($alpha, $otherAlphaMenu, 'Other alpha section', 0);

        $this->getJson("/api/v1/admin/menus/{$foreignMenu}", $this->headers($alpha))->assertNotFound();
        $this->patchJson("/api/v1/admin/menu-sections/{$foreignSection}", ['name' => 'Nope'], $this->headers($alpha))->assertNotFound();
        $this->postJson("/api/v1/admin/menu-sections/{$foreignSection}/archive", [], $this->headers($alpha))->assertNotFound();
        $this->postJson("/api/v1/admin/menu-sections/{$foreignSection}/restore", [], $this->headers($alpha))->assertNotFound();
        $this->postJson("/api/v1/admin/menus/{$foreignMenu}/sections/reorder", ['items' => [['id' => $foreignSection, 'sortOrder' => 0]]], $this->headers($alpha))->assertNotFound();

        foreach ([[['id' => $first, 'sortOrder' => 0], ['id' => $first, 'sortOrder' => 1]], [['id' => 999999, 'sortOrder' => 0]], [['id' => $foreignSection, 'sortOrder' => 0]], [['id' => $otherAlphaSection, 'sortOrder' => 0]], [['id' => $archived, 'sortOrder' => 0]], [['id' => $second, 'sortOrder' => 0], ['id' => 999999, 'sortOrder' => 1]]] as $items) {
            $this->postJson("/api/v1/admin/menus/{$menu}/sections/reorder", ['items' => $items], $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('items');
        }
        $this->assertDatabaseHas('menu_sections', ['id' => $first, 'sort_order' => 4]);
        $this->assertDatabaseHas('menu_sections', ['id' => $second, 'sort_order' => 9]);
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function menu(int $tenant, string $name): int
    {
        return $this->postJson('/api/v1/admin/menus', ['name' => $name], $this->headers($tenant))->assertCreated()->json('data.id');
    }

    private function section(int $tenant, int $menu, string $name, int $sortOrder): int
    {
        return $this->postJson("/api/v1/admin/menus/{$menu}/sections", ['name' => $name, 'sortOrder' => $sortOrder], $this->headers($tenant))->assertCreated()->json('data.id');
    }

    private function product(int $tenant, string $name): int
    {
        return $this->postJson('/api/v1/admin/catalog/products', ['name' => $name, 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenant))->assertCreated()->json('data.id');
    }

    private function placement(int $tenant, int $section, int $product, bool $visible): int
    {
        return DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'sort_order' => 0, 'is_featured' => false, 'is_visible' => $visible, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
