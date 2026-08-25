<?php

namespace Tests\Feature\Admin\Menu;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuCompositionApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_menu_sections_placements_assignments_schedules_and_usage_are_tenant_scoped(): void
    {
        $tenantId = $this->tenant('alpha');
        $productId = $this->product($tenantId, 'Iced Latte');
        $this->postJson('/api/v1/admin/menus', ['name' => 'Invalid', 'status' => 'active'], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('status');
        $menuId = $this->postJson('/api/v1/admin/menus', ['name' => 'Main Menu', 'nameAr' => 'الرئيسية'], $this->headers($tenantId))->assertCreated()->assertJsonPath('data.status', 'draft')->json('data.id');
        $this->postJson('/api/v1/admin/menus', ['name' => 'Main Menu'], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('name');
        $this->getJson("/api/v1/admin/menus/{$menuId}", $this->headers($this->tenant('beta')))->assertNotFound();

        $sectionId = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Cold Coffee'], $this->headers($tenantId))->assertCreated()->json('data.id');
        $placementId = $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $productId, 'isFeatured' => true], $this->headers($tenantId))->assertCreated()->assertJsonPath('data.productId', $productId)->json('data.id');
        $this->getJson("/api/v1/admin/menus/{$menuId}", $this->headers($tenantId))->assertOk()
            ->assertJsonPath('data.sectionCount', 1)
            ->assertJsonPath('data.visibleProductCount', 1);
        $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $productId], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('productId');
        $this->patchJson("/api/v1/admin/menu-item-placements/{$placementId}", ['displayNameOverride' => 'Cold Latte'], $this->headers($tenantId))->assertOk()->assertJsonPath('data.displayNameOverride', 'Cold Latte');

        $branchId = $this->branch($tenantId);
        $this->putJson("/api/v1/admin/menus/{$menuId}/assignments", ['assignments' => [['branchId' => $branchId, 'channel' => 'pos', 'priority' => 0, 'isActive' => true]]], $this->headers($tenantId))->assertOk()->assertJsonPath('data.0.channel', 'pos');
        $this->putJson("/api/v1/admin/menus/{$menuId}/availability-rules", ['rules' => [['branchId' => $branchId, 'channel' => 'pos', 'dayOfWeek' => 0, 'startTime' => '22:00', 'endTime' => '02:00']]], $this->headers($tenantId))->assertOk()->assertJsonPath('data.0.startTime', '22:00');
        $this->getJson("/api/v1/admin/catalog/products/{$productId}/menu-usage", $this->headers($tenantId))->assertOk()->assertJsonPath('data.activePlacementCount', 1)->assertJsonPath('data.menus.0.menuId', $menuId);

        $this->postJson("/api/v1/admin/menus/{$menuId}/archive", [], $this->headers($tenantId))->assertOk();
        $this->assertDatabaseHas('menu_sections', ['id' => $sectionId]);
        $this->assertDatabaseHas('menu_item_placements', ['id' => $placementId]);
        $this->getJson("/api/v1/admin/catalog/products/{$productId}/menu-usage", $this->headers($tenantId))->assertOk()->assertJsonPath('data.activePlacementCount', 0)->assertJsonCount(0, 'data.menus');
        $this->getJson("/api/v1/admin/catalog/products/{$productId}/menu-usage?includeArchived=true", $this->headers($tenantId))->assertOk()->assertJsonPath('data.activePlacementCount', 0)->assertJsonCount(1, 'data.menus');
        $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Blocked'], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('menu');
        $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/archive", [], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('menu');
        $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $productId], $this->headers($tenantId))->assertUnprocessable();
        $this->postJson("/api/v1/admin/menus/{$menuId}/restore", [], $this->headers($tenantId))->assertOk()->assertJsonPath('data.status', 'draft');
        $this->assertDatabaseHas('menu_audit_logs', ['tenant_id' => $tenantId]);
    }

    public function test_placement_move_sync_and_reorder_are_transactional(): void
    {
        $tenantId = $this->tenant('alpha');
        $firstProduct = $this->product($tenantId, 'Espresso');
        $secondProduct = $this->product($tenantId, 'Tea');
        $menuId = $this->postJson('/api/v1/admin/menus', ['name' => 'Main'], $this->headers($tenantId))->json('data.id');
        $source = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Hot'], $this->headers($tenantId))->json('data.id');
        $target = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Cold'], $this->headers($tenantId))->json('data.id');
        $placement = $this->postJson("/api/v1/admin/menu-sections/{$source}/placements", ['productId' => $firstProduct], $this->headers($tenantId))->json('data.id');
        $this->postJson("/api/v1/admin/menu-item-placements/{$placement}/move", ['targetSectionId' => $target], $this->headers($tenantId))->assertOk()->assertJsonPath('data.sectionId', $target);
        $this->putJson("/api/v1/admin/menu-sections/{$target}/placements", ['placements' => [['id' => $placement, 'productId' => $firstProduct, 'sortOrder' => 0, 'isFeatured' => true], ['productId' => $secondProduct, 'sortOrder' => 1, 'isVisible' => true]]], $this->headers($tenantId))->assertOk()->assertJsonCount(2, 'data');
        $this->postJson("/api/v1/admin/menu-sections/{$target}/placements/reorder", ['items' => [['id' => $placement, 'sortOrder' => 1], ['id' => 999999, 'sortOrder' => 0]]], $this->headers($tenantId))->assertUnprocessable();
        $this->assertDatabaseHas('menu_item_placements', ['id' => $placement, 'sort_order' => 0, 'is_featured' => true]);
    }

    public function test_section_placement_listing_includes_archived_metadata_only_when_requested(): void
    {
        $tenantId = $this->tenant('alpha');
        $productId = $this->product($tenantId, 'Archived listing product');
        $menuId = $this->postJson('/api/v1/admin/menus', ['name' => 'Placement listing'], $this->headers($tenantId))->json('data.id');
        $sectionId = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Coffee'], $this->headers($tenantId))->json('data.id');
        $placementId = $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $productId], $this->headers($tenantId))->json('data.id');

        $this->postJson("/api/v1/admin/menu-item-placements/{$placementId}/archive", [], $this->headers($tenantId))->assertOk();
        $this->getJson("/api/v1/admin/menu-sections/{$sectionId}/placements", $this->headers($tenantId))->assertOk()->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/admin/menu-sections/{$sectionId}/placements?includeArchived=true", $this->headers($tenantId))->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $placementId)->assertJsonPath('data.0.archivedAt', fn ($value) => $value !== null);
    }

    public function test_foreign_products_inactive_variants_and_invalid_schedule_or_assignment_data_are_rejected(): void
    {
        $tenantId = $this->tenant('alpha');
        $menuId = $this->postJson('/api/v1/admin/menus', ['name' => 'Main'], $this->headers($tenantId))->json('data.id');
        $sectionId = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Coffee'], $this->headers($tenantId))->json('data.id');
        $foreignProduct = $this->product($this->tenant('beta'), 'Foreign Product');
        $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $foreignProduct], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('productId');

        $inactiveProduct = $this->product($tenantId, 'Inactive Variant');
        DB::table('product_variants')->where('product_id', $inactiveProduct)->update(['is_active' => false]);
        $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $inactiveProduct], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('productId');

        $foreignBranch = $this->branch($this->tenant('gamma'));
        $this->putJson("/api/v1/admin/menus/{$menuId}/assignments", ['assignments' => [['branchId' => $foreignBranch, 'channel' => 'pos']]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $this->putJson("/api/v1/admin/menus/{$menuId}/availability-rules", ['rules' => [['startTime' => '08:00']]], $this->headers($tenantId))->assertUnprocessable();
        $this->putJson("/api/v1/admin/menus/{$menuId}/availability-rules", ['rules' => [['startDate' => '2026-08-02', 'endDate' => '2026-08-01']]], $this->headers($tenantId))->assertUnprocessable();
    }

    public function test_synchronization_rejects_foreign_rows_and_rolls_back_prior_changes(): void
    {
        $tenantId = $this->tenant('alpha');
        $firstProduct = $this->product($tenantId, 'Latte');
        $secondProduct = $this->product($tenantId, 'Tea');
        $menuId = $this->postJson('/api/v1/admin/menus', ['name' => 'Main'], $this->headers($tenantId))->json('data.id');
        $firstSection = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Coffee'], $this->headers($tenantId))->json('data.id');
        $secondSection = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Tea'], $this->headers($tenantId))->json('data.id');
        $firstPlacement = $this->postJson("/api/v1/admin/menu-sections/{$firstSection}/placements", ['productId' => $firstProduct], $this->headers($tenantId))->json('data.id');
        $secondPlacement = $this->postJson("/api/v1/admin/menu-sections/{$secondSection}/placements", ['productId' => $secondProduct], $this->headers($tenantId))->json('data.id');
        $this->putJson("/api/v1/admin/menu-sections/{$firstSection}/placements", ['placements' => [['id' => $firstPlacement, 'productId' => $firstProduct, 'isFeatured' => true], ['id' => $secondPlacement, 'productId' => $secondProduct]]], $this->headers($tenantId))->assertUnprocessable();
        $this->assertDatabaseHas('menu_item_placements', ['id' => $firstPlacement, 'is_featured' => false]);
        $this->putJson("/api/v1/admin/menu-sections/{$firstSection}/placements", ['placements' => [['productId' => $firstProduct], ['productId' => $firstProduct]]], $this->headers($tenantId))->assertUnprocessable();

        $branchId = $this->branch($tenantId);
        $this->putJson("/api/v1/admin/menus/{$menuId}/assignments", ['assignments' => [['branchId' => $branchId, 'channel' => 'pos', 'priority' => 1]]], $this->headers($tenantId))->assertOk();
        $foreignBranch = $this->branch($this->tenant('beta'));
        $this->putJson("/api/v1/admin/menus/{$menuId}/assignments", ['assignments' => [['branchId' => $branchId, 'channel' => 'pos', 'priority' => 9], ['branchId' => $foreignBranch, 'channel' => 'kiosk']]], $this->headers($tenantId))->assertUnprocessable();
        $this->assertDatabaseHas('menu_assignments', ['menu_id' => $menuId, 'branch_id' => $branchId, 'priority' => 1]);
        $this->putJson("/api/v1/admin/menus/{$menuId}/assignments", ['assignments' => [['branchId' => $branchId, 'channel' => 'pos'], ['branchId' => $branchId, 'channel' => 'pos']]], $this->headers($tenantId))->assertUnprocessable();

        $this->putJson("/api/v1/admin/menus/{$menuId}/availability-rules", ['rules' => [['branchId' => null, 'channel' => null, 'dayOfWeek' => null]]], $this->headers($tenantId))->assertOk()->assertJsonCount(1, 'data');
        $this->putJson("/api/v1/admin/menus/{$menuId}/availability-rules", ['rules' => [['branchId' => null, 'channel' => null, 'dayOfWeek' => null], ['branchId' => null, 'channel' => null, 'dayOfWeek' => null]]], $this->headers($tenantId))->assertUnprocessable();
        $this->assertDatabaseCount('menu_availability_rules', 1);
    }

    public function test_section_names_are_menu_scoped_and_menus_can_share_branch_channel_assignments(): void
    {
        $tenantId = $this->tenant('alpha');
        $firstMenu = $this->postJson('/api/v1/admin/menus', ['name' => 'Breakfast'], $this->headers($tenantId))->json('data.id');
        $secondMenu = $this->postJson('/api/v1/admin/menus', ['name' => 'Evening'], $this->headers($tenantId))->json('data.id');
        $firstSection = $this->postJson("/api/v1/admin/menus/{$firstMenu}/sections", ['name' => 'Drinks', 'sortOrder' => 4], $this->headers($tenantId))->json('data.id');
        $secondSection = $this->postJson("/api/v1/admin/menus/{$secondMenu}/sections", ['name' => 'Drinks'], $this->headers($tenantId))->assertCreated()->json('data.id');
        $this->postJson("/api/v1/admin/menus/{$firstMenu}/sections", ['name' => 'Drinks'], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('name');
        $this->postJson("/api/v1/admin/menu-sections/{$secondSection}/archive", [], $this->headers($tenantId))->assertOk();
        $this->postJson("/api/v1/admin/menus/{$firstMenu}/sections/reorder", ['items' => [['id' => $firstSection, 'sortOrder' => 0], ['id' => $secondSection, 'sortOrder' => 1]]], $this->headers($tenantId))->assertUnprocessable();
        $this->assertDatabaseHas('menu_sections', ['id' => $firstSection, 'sort_order' => 4]);

        $branchId = $this->branch($tenantId);
        foreach ([$firstMenu, $secondMenu] as $menuId) {
            $this->putJson("/api/v1/admin/menus/{$menuId}/assignments", ['assignments' => [['branchId' => $branchId, 'channel' => 'pos']]], $this->headers($tenantId))->assertOk();
        }
        $this->assertDatabaseCount('menu_assignments', 2);
    }

    public function test_assignment_scope_sync_is_tenant_scoped_and_reorders_atomically(): void
    {
        $tenantId = $this->tenant('alpha');
        $branchId = $this->branch($tenantId);
        $first = $this->postJson('/api/v1/admin/menus', ['name' => 'Breakfast'], $this->headers($tenantId))->json('data.id');
        $second = $this->postJson('/api/v1/admin/menus', ['name' => 'Evening'], $this->headers($tenantId))->json('data.id');

        $this->putJson('/api/v1/admin/menu-management/assignments', [
            'branchId' => $branchId,
            'channel' => 'pos',
            'assignments' => [
                ['menuId' => $first, 'priority' => 0, 'isActive' => true],
                ['menuId' => $second, 'priority' => 1, 'isActive' => false],
            ],
        ], $this->headers($tenantId))->assertOk()->assertJsonPath('data.0.menuId', $first)->assertJsonPath('data.0.menu.name', 'Breakfast');

        $this->getJson("/api/v1/admin/menu-management/assignments?branchId={$branchId}&channel=pos", $this->headers($tenantId))
            ->assertOk()->assertJsonCount(2, 'data')->assertJsonPath('data.1.isActive', false);

        $this->putJson('/api/v1/admin/menu-management/assignments', [
            'branchId' => $branchId,
            'channel' => 'pos',
            'assignments' => [
                ['menuId' => $second, 'priority' => 0, 'isActive' => true],
            ],
        ], $this->headers($tenantId))->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.menuId', $second);
        $this->assertDatabaseMissing('menu_assignments', ['menu_id' => $first, 'branch_id' => $branchId, 'channel' => 'pos']);
        $this->assertDatabaseHas('menu_assignments', ['menu_id' => $second, 'branch_id' => $branchId, 'channel' => 'pos', 'priority' => 0, 'is_active' => true]);

        $foreignMenu = $this->postJson('/api/v1/admin/menus', ['name' => 'Foreign'], $this->headers($this->tenant('beta')))->json('data.id');
        $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branchId, 'channel' => 'pos', 'assignments' => [['menuId' => $foreignMenu]]], $this->headers($tenantId))
            ->assertUnprocessable()->assertJsonValidationErrors('assignments');
        $this->assertDatabaseHas('menu_assignments', ['menu_id' => $second, 'branch_id' => $branchId, 'priority' => 0]);
    }

    public function test_menu_detail_can_include_archived_sections_for_diagnostics(): void
    {
        $tenantId = $this->tenant('alpha');
        $menuId = $this->postJson('/api/v1/admin/menus', ['name' => 'Main'], $this->headers($tenantId))->json('data.id');
        $sectionId = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Coffee'], $this->headers($tenantId))->json('data.id');
        $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/archive", [], $this->headers($tenantId))->assertOk();

        $this->getJson("/api/v1/admin/menus/{$menuId}?includeArchived=true", $this->headers($tenantId))
            ->assertOk()
            ->assertJsonPath('data.sections.0.id', $sectionId)
            ->assertJsonPath('data.sections.0.archivedAt', fn ($value) => $value !== null);

        $this->postJson("/api/v1/admin/menus/{$menuId}/archive", [], $this->headers($tenantId))->assertOk()
            ->assertJsonPath('data.archivedAt', fn ($value) => $value !== null);
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenantId): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Downtown', 'created_at' => now(), 'updated_at' => now()]);
    }

    private function product(int $tenantId, string $name): int
    {
        return $this->postJson('/api/v1/admin/catalog/products', ['name' => $name, 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenantId))->assertCreated()->json('data.id');
    }

    private function headers(int $tenantId): array
    {
        return ['X-Tenant-Id' => (string) $tenantId];
    }
}
