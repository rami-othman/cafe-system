<?php

namespace Tests\Feature\Admin\Menu;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuPlacementContractApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_listing_honors_include_archived_is_tenant_scoped_and_authoritatively_ordered(): void
    {
        $alpha = $this->tenant('alpha');
        $beta = $this->tenant('beta');
        $menu = $this->menu($alpha, 'Alpha');
        $section = $this->section($alpha, $menu, 'Coffee');
        $first = $this->placement($alpha, $section, $this->product($alpha, 'First'), 8);
        $second = $this->placement($alpha, $section, $this->product($alpha, 'Second'), 8);
        $archived = $this->placement($alpha, $section, $this->product($alpha, 'Archived'), 2, true);
        DB::table('menu_item_placements')->where('id', $archived)->update(['deleted_at' => now()]);
        DB::table('menu_item_placements')->insert([
            'tenant_id' => $beta, 'menu_section_id' => $section, 'product_id' => $this->product($beta, 'Malformed'),
            'sort_order' => 0, 'is_featured' => false, 'is_visible' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);

        foreach (['', 'false', '0'] as $value) {
            $suffix = $value === '' ? '' : "?includeArchived={$value}";
            $response = $this->getJson("/api/v1/admin/menu-sections/{$section}/placements{$suffix}", $this->headers($alpha))->assertOk();
            $this->assertSame([$first, $second], collect($response->json('data'))->pluck('id')->all());
            $this->assertNull($response->json('data.0.archivedAt'));
            $this->assertArrayNotHasKey('tenantId', $response->json('data.0'));
        }
        foreach (['true', '1'] as $value) {
            $response = $this->getJson("/api/v1/admin/menu-sections/{$section}/placements?includeArchived={$value}", $this->headers($alpha))->assertOk();
            $this->assertSame([$archived, $first, $second], collect($response->json('data'))->pluck('id')->all());
            $this->assertNotNull($response->json('data.0.archivedAt'));
        }
        $this->getJson("/api/v1/admin/menu-sections/{$section}/placements?includeArchived=yes", $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('includeArchived');
        $this->getJson("/api/v1/admin/menu-sections/{$section}/placements", $this->headers($beta))->assertNotFound();
    }

    public function test_parent_lifecycle_rejects_every_placement_mutation_without_partial_changes(): void
    {
        $tenant = $this->tenant('alpha');
        $menu = $this->menu($tenant, 'Main');
        $section = $this->section($tenant, $menu, 'Coffee');
        $target = $this->section($tenant, $menu, 'Tea');
        $product = $this->product($tenant, 'Latte');
        $placement = $this->placement($tenant, $section, $product, 0);
        $archived = $this->placement($tenant, $section, $this->product($tenant, 'Archived'), 1, true);
        DB::table('menu_item_placements')->where('id', $archived)->update(['deleted_at' => now()]);

        $this->postJson("/api/v1/admin/menus/{$menu}/archive", [], $this->headers($tenant))->assertOk();
        $this->assertMutationsBlocked($tenant, $section, $target, $placement, $archived, $product);
        $this->assertDatabaseHas('menu_item_placements', ['id' => $placement, 'menu_section_id' => $section, 'deleted_at' => null]);

        $this->postJson("/api/v1/admin/menus/{$menu}/restore", [], $this->headers($tenant))->assertOk();
        $this->postJson("/api/v1/admin/menu-sections/{$section}/archive", [], $this->headers($tenant))->assertOk();
        $this->assertMutationsBlocked($tenant, $section, $target, $placement, $archived, $product);
        $this->assertDatabaseHas('menu_item_placements', ['id' => $placement, 'menu_section_id' => $section, 'deleted_at' => null]);
    }

    public function test_ownership_duplicate_and_product_lifecycle_rules_are_safe(): void
    {
        $alpha = $this->tenant('alpha');
        $beta = $this->tenant('beta');
        $menu = $this->menu($alpha, 'Alpha');
        $source = $this->section($alpha, $menu, 'Source');
        $target = $this->section($alpha, $menu, 'Target');
        $otherMenuSection = $this->section($alpha, $this->menu($alpha, 'Other'), 'Elsewhere');
        $foreignSection = $this->section($beta, $this->menu($beta, 'Beta'), 'Foreign');
        $product = $this->product($alpha, 'Latte');
        $placement = $this->placement($alpha, $source, $product, 0);
        $foreignPlacement = $this->placement($beta, $foreignSection, $this->product($beta, 'Foreign product'), 0);
        $this->placement($alpha, $target, $product, 0);

        $this->patchJson("/api/v1/admin/menu-item-placements/{$foreignPlacement}", ['isVisible' => false], $this->headers($alpha))->assertNotFound();
        $this->postJson("/api/v1/admin/menu-item-placements/{$foreignPlacement}/archive", [], $this->headers($alpha))->assertNotFound();
        $this->postJson("/api/v1/admin/menu-item-placements/{$placement}/move", ['targetSectionId' => $otherMenuSection], $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('targetSectionId');
        $this->postJson("/api/v1/admin/menu-item-placements/{$placement}/move", ['targetSectionId' => $target], $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('targetSectionId');
        $this->postJson("/api/v1/admin/menu-sections/{$target}/archive", [], $this->headers($alpha))->assertOk();
        $this->postJson("/api/v1/admin/menu-item-placements/{$placement}/move", ['targetSectionId' => $target], $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('section');
        $this->postJson("/api/v1/admin/menu-sections/{$source}/placements", ['productId' => $this->product($beta, 'Other tenant')], $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('productId');

        $archivedProduct = $this->product($alpha, 'Archived product');
        DB::table('products')->where('id', $archivedProduct)->update(['deleted_at' => now()]);
        $this->postJson("/api/v1/admin/menu-sections/{$source}/placements", ['productId' => $archivedProduct], $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('productId');
        $inactive = $this->product($alpha, 'Inactive product');
        DB::table('product_variants')->where('product_id', $inactive)->update(['is_active' => false]);
        $this->postJson("/api/v1/admin/menu-sections/{$source}/placements", ['productId' => $inactive], $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('productId');
    }

    public function test_reorder_requires_the_complete_active_set_and_rolls_back_failures(): void
    {
        $tenant = $this->tenant('alpha');
        $menu = $this->menu($tenant, 'Main');
        $section = $this->section($tenant, $menu, 'Coffee');
        $other = $this->section($tenant, $menu, 'Tea');
        $first = $this->placement($tenant, $section, $this->product($tenant, 'First'), 4);
        $second = $this->placement($tenant, $section, $this->product($tenant, 'Second'), 9);
        $foreign = $this->placement($tenant, $other, $this->product($tenant, 'Other'), 0);
        $archived = $this->placement($tenant, $section, $this->product($tenant, 'Archived'), 10, true);
        DB::table('menu_item_placements')->where('id', $archived)->update(['deleted_at' => now()]);

        foreach ([[['id' => $first, 'sortOrder' => 0]], [['id' => $first, 'sortOrder' => 0], ['id' => $first, 'sortOrder' => 1]], [['id' => $first, 'sortOrder' => 0], ['id' => $foreign, 'sortOrder' => 1]], [['id' => $first, 'sortOrder' => 0], ['id' => $archived, 'sortOrder' => 1]], [['id' => $first, 'sortOrder' => 0], ['id' => $second, 'sortOrder' => 3]]] as $items) {
            $this->postJson("/api/v1/admin/menu-sections/{$section}/placements/reorder", ['items' => $items], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('items');
        }
        $this->assertDatabaseHas('menu_item_placements', ['id' => $first, 'sort_order' => 4]);
        $this->assertDatabaseHas('menu_item_placements', ['id' => $second, 'sort_order' => 9]);
        $this->postJson("/api/v1/admin/menu-sections/{$section}/placements/reorder", ['items' => [['id' => $second, 'sortOrder' => 0], ['id' => $first, 'sortOrder' => 1]]], $this->headers($tenant))->assertOk();
        $this->assertDatabaseHas('menu_item_placements', ['id' => $second, 'sort_order' => 0]);
        $this->assertDatabaseHas('menu_item_placements', ['id' => $first, 'sort_order' => 1]);
    }

    public function test_archiving_or_restoring_a_placement_never_changes_its_product(): void
    {
        $tenant = $this->tenant('alpha');
        $menu = $this->menu($tenant, 'Main');
        $section = $this->section($tenant, $menu, 'Coffee');
        $product = $this->product($tenant, 'Latte');
        $placement = $this->placement($tenant, $section, $product, 0);
        $this->postJson("/api/v1/admin/menu-item-placements/{$placement}/archive", [], $this->headers($tenant))->assertOk();
        $this->assertDatabaseHas('products', ['id' => $product, 'deleted_at' => null]);
        DB::table('products')->where('id', $product)->update(['deleted_at' => now()]);
        $this->postJson("/api/v1/admin/menu-item-placements/{$placement}/restore", [], $this->headers($tenant))->assertOk();
        $this->assertDatabaseHas('products', ['id' => $product]);
        $this->assertDatabaseHas('menu_item_placements', ['id' => $placement, 'deleted_at' => null]);
    }

    private function assertMutationsBlocked(int $tenant, int $section, int $target, int $placement, int $archived, int $product): void
    {
        $headers = $this->headers($tenant);
        $this->postJson("/api/v1/admin/menu-sections/{$section}/placements", ['productId' => $product], $headers)->assertUnprocessable();
        $this->patchJson("/api/v1/admin/menu-item-placements/{$placement}", ['isVisible' => false], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/admin/menu-item-placements/{$placement}/move", ['targetSectionId' => $target], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/admin/menu-sections/{$section}/placements/reorder", ['items' => [['id' => $placement, 'sortOrder' => 0]]], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/admin/menu-item-placements/{$placement}/archive", [], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/admin/menu-item-placements/{$archived}/restore", [], $headers)->assertUnprocessable();
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }

    private function menu(int $tenant, string $name): int
    {
        return $this->postJson('/api/v1/admin/menus', ['name' => $name], $this->headers($tenant))->assertCreated()->json('data.id');
    }

    private function section(int $tenant, int $menu, string $name): int
    {
        return $this->postJson("/api/v1/admin/menus/{$menu}/sections", ['name' => $name], $this->headers($tenant))->assertCreated()->json('data.id');
    }

    private function product(int $tenant, string $name): int
    {
        return $this->postJson('/api/v1/admin/catalog/products', ['name' => $name, 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenant))->assertCreated()->json('data.id');
    }

    private function placement(int $tenant, int $section, int $product, int $sort, bool $visible = true): int
    {
        return DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'sort_order' => $sort, 'is_featured' => false, 'is_visible' => $visible, 'created_at' => now(), 'updated_at' => now()]);
    }
}
