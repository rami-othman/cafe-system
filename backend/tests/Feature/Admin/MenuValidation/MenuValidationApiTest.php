<?php

namespace Tests\Feature\Admin\MenuValidation;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuValidationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_valid_menu_has_stable_read_only_response(): void
    {
        [$tenant, $branch, $menu, $product] = $this->menuGraph();
        $beforeMenu = DB::table('menus')->where('id', $menu)->value('updated_at');
        $beforeProduct = DB::table('products')->where('id', $product)->value('updated_at');
        $audits = DB::table('menu_audit_logs')->count();
        $response = $this->validateMenu($tenant, $menu, $branch)->assertOk()->assertJsonStructure(['data' => ['isValid', 'errorCount', 'warningCount', 'informationCount', 'errors', 'warnings', 'information', 'menus']]);
        $response->assertJsonPath('data.isValid', true)->assertJsonPath('data.errorCount', 0);
        $this->assertSame($beforeMenu, DB::table('menus')->where('id', $menu)->value('updated_at'));
        $this->assertSame($beforeProduct, DB::table('products')->where('id', $product)->value('updated_at'));
        $this->assertSame($audits, DB::table('menu_audit_logs')->count());
        $this->assertSame(0, DB::table('menu_publications')->count());
        $this->assertSame(0, DB::table('published_menu_versions')->count());
    }

    public function test_structural_modifier_and_availability_issues_are_reported_without_writes(): void
    {
        [$tenant, $branch, $menu, $product, $variant, $section] = $this->menuGraph();
        DB::table('product_variants')->where('id', $variant)->update(['is_default' => false]);
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Cup Size', 'selection_type' => 'single', 'is_required' => true, 'min_selections' => 0, 'max_selections' => 2, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $this->putJson('/api/v1/admin/catalog/products/'.$product.'/operational-availability', ['branchId' => $branch, 'channel' => 'pos', 'status' => 'sold_out'], $this->headers($tenant))->assertOk();
        $rows = DB::table('product_operational_availabilities')->count();
        $response = $this->validateMenu($tenant, $menu, $branch)->assertOk();
        $codes = collect($response->json('data.errors'))->pluck('code');
        $warnings = collect($response->json('data.warnings'))->pluck('code');
        $this->assertTrue($codes->contains('PRODUCT_MISSING_ACTIVE_DEFAULT_VARIANT'));
        $this->assertTrue($codes->contains('MODIFIER_GROUP_NO_ACTIVE_OPTION'));
        $this->assertTrue($codes->contains('MODIFIER_REQUIRED_MINIMUM_INVALID'));
        $this->assertTrue($codes->contains('MODIFIER_SINGLE_MAXIMUM_INVALID'));
        $this->assertTrue($warnings->contains('PRODUCT_OPERATIONALLY_UNAVAILABLE'));
        $this->assertTrue($warnings->contains('LEGACY_SIZE_MODIFIER_GROUP'));
        $this->assertSame($rows, DB::table('product_operational_availabilities')->count());
        DB::table('menu_sections')->where('id', $section)->update(['is_active' => false]);
        $this->validateMenu($tenant, $menu, $branch)->assertJsonPath('data.isValid', false)->assertJsonPath('data.errors.0.menuId', $menu);
    }

    public function test_collection_validation_is_tenant_safe_and_uses_requested_or_assigned_menus(): void
    {
        [$tenant, $branch, $menu] = $this->menuGraph();
        $this->postJson('/api/v1/admin/menu-management/validate', ['branchId' => $branch, 'channel' => 'pos'], $this->headers($tenant))->assertOk()->assertJsonCount(1, 'data.menus')->assertJsonPath('data.menus.0.menuId', $menu);
        $this->postJson('/api/v1/admin/menu-management/validate', ['branchId' => $branch, 'channel' => 'pos', 'menuIds' => [$menu]], $this->headers($tenant))->assertOk()->assertJsonCount(1, 'data.menus');
        $foreign = $this->tenant('foreign');
        [, , $foreignMenu] = $this->menuGraph($foreign);
        $this->postJson('/api/v1/admin/menu-management/validate', ['branchId' => $branch, 'channel' => 'pos', 'menuIds' => [$foreignMenu]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menuIds');
        $this->postJson('/api/v1/admin/menu-management/validate', ['branchId' => $this->branch($foreign), 'channel' => 'pos'], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $this->postJson('/api/v1/admin/menus/'.$foreignMenu.'/validate', ['branchId' => $branch, 'channel' => 'pos'], $this->headers($tenant))->assertNotFound();
    }

    public function test_combined_remove_validation_uses_bounded_group_maxima_and_runtime_resolver_remains_authoritative(): void
    {
        $cases = [
            // Single selection: below, equal to, and above the Base quantity.
            ['single-under', [['single', 1, [4]]], false],
            ['single-equal', [['single', 1, [10]]], false],
            ['single-over', [['single', 1, [11]]], true],
            // Independently selectable groups combine their bounded contributions.
            ['cross-equal', [['single', 1, [5]], ['single', 1, [5]]], false],
            ['cross-over', [['single', 1, [5]], ['single', 1, [6]]], true],
            // Multiple options in one group use only its maximum legal selection count.
            ['multi-under', [['multiple', 2, [4, 5]]], false],
            ['multi-over', [['multiple', 2, [5, 6]]], true],
            ['multi-capped', [['multiple', 1, [8, 8]]], false],
        ];

        foreach ($cases as [$slug, $groups, $expectsIssue]) {
            $caseTenant = $this->tenant('combined-'.$slug);
            [$tenant, $branch, $menu, $product, $variant] = $this->menuGraph($caseTenant);
            DB::table('products')->where('id', $product)->update(['is_stock_tracked' => true]);
            $material = DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => "Beans $slug", 'sku' => "BEANS-$slug", 'unit' => 'kilogram', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
            $headers = $this->headers($tenant);
            $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $material, 'quantity' => '10', 'unitCode' => 'g']]], $headers)->assertOk();
            $selected = [];
            foreach ($groups as $groupIndex => [$selectionType, $maximum, $removes]) {
                $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => "$slug-$groupIndex", 'selection_type' => $selectionType, 'max_selections' => $maximum, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
                DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'max_selections_override' => $maximum, 'created_at' => now(), 'updated_at' => now()]);
                foreach ($removes as $optionIndex => $remove) {
                    $option = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => "$slug-$groupIndex-$optionIndex", 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
                    $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => [['materialId' => $material, 'operation' => 'remove', 'quantity' => (string) $remove, 'unitCode' => 'g']]], $headers)->assertOk();
                    $selected[] = ['optionId' => $option];
                }
            }
            $codes = collect($this->validateMenu($tenant, $menu, $branch)->assertOk()->json('data.errors'))->pluck('code');
            $this->assertSame($expectsIssue, $codes->contains('MODIFIER_RECIPE_COMBINED_REMOVE_EXCEEDS_BASE'), $slug);

            // The resolver is the final authority for the actual submitted set:
            // equal removes remove the material; over-removes are rejected.
            $resolution = $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => $selected], $headers);
            if ($expectsIssue) {
                $resolution->assertUnprocessable();
            } elseif (array_sum(array_merge(...array_map(fn ($group) => $group[2], $groups))) === 10) {
                $resolution->assertOk()->assertJsonCount(0, 'data.components');
            }
        }
    }

    private function validateMenu(int $tenant, int $menu, int $branch)
    {
        return $this->postJson('/api/v1/admin/menus/'.$menu.'/validate', ['branchId' => $branch, 'channel' => 'pos', 'at' => '2026-08-01T10:00:00+03:00'], $this->headers($tenant));
    }

    private function menuGraph(?int $tenant = null): array
    {
        $tenant ??= $this->tenant('alpha');
        $branch = $this->branch($tenant);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Latte', 'categoryId' => $category, 'preparationTimeMinutes' => 5, 'variants' => [['name' => 'Regular', 'basePrice' => 4, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenant))->assertCreated()->json('data.id');
        $variant = DB::table('product_variants')->where('product_id', $product)->value('id');
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'status' => 'draft', 'priority' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'sort_order' => 0, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_item_placements')->insert(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'sort_order' => 0, 'is_visible' => true, 'is_featured' => false, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_assignments')->insert(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => 'pos', 'priority' => 0, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return [$tenant, $branch, $menu, $product, $variant, $section];
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenant): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Downtown', 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
