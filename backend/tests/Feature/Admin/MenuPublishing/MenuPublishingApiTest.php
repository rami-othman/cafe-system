<?php

namespace Tests\Feature\Admin\MenuPublishing;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuPublishingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_current_version_returns_null_when_the_scope_has_not_been_published(): void
    {
        [$tenant, $branch] = $this->graph();

        $this->getJson('/api/v1/admin/menu-management/current-version?branchId='.$branch.'&channel=pos', $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data', null);
    }

    public function test_publish_creates_immutable_current_snapshot_and_no_change_attempt(): void
    {
        [$tenant, $branch, $menu, $product, $variant, $section, $placement] = $this->graph();
        DB::table('product_variant_price_overrides')->insert(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'scope_type' => 'branch_channel', 'scope_key' => "branch:{$branch}|channel:pos", 'branch_id' => $branch, 'channel' => 'pos', 'override_price' => 5, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $first = $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.published', true)->assertJsonPath('data.version.versionNumber', 1);
        $version = $first->json('data.version.id');
        $payload = DB::table('published_menu_versions')->where('id', $version)->value('payload_json');
        $this->assertStringContainsString('effectivePrice', $payload);
        $this->assertStringContainsString('5.00', $payload);
        $this->assertStringNotContainsString('isOperationallyAvailable', $payload);
        $this->assertStringNotContainsString('isSellable', $payload);
        $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.published', false)->assertJsonPath('data.noChanges', true)->assertJsonPath('data.version.id', $version);
        $this->assertSame(1, DB::table('published_menu_versions')->count());
        $this->getJson('/api/v1/admin/menu-management/current-version?branchId='.$branch.'&channel=pos', $this->headers($tenant))->assertOk()->assertJsonPath('data.id', $version)->assertJsonMissing(['payloadJson']);
    }

    public function test_changed_snapshot_supersedes_previous_and_validation_failure_is_recorded(): void
    {
        [$tenant, $branch, $menu, $product, $variant, $section, $placement] = $this->graph();
        $first = $this->publish($tenant, $branch)->assertOk()->json('data.version.id');
        DB::table('products')->where('id', $product)->update(['name' => 'Changed']);
        $second = $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.version.versionNumber', 2)->json('data.version.id');
        $this->assertDatabaseHas('published_menu_versions', ['id' => $first, 'status' => 'superseded']);
        $this->assertDatabaseHas('published_menu_versions', ['id' => $second, 'status' => 'current']);
        DB::table('menu_assignments')->where('menu_id', $menu)->delete();
        $this->publish($tenant, $branch)->assertUnprocessable()->assertJsonValidationErrors('publish');
        $this->assertDatabaseHas('menu_publications', ['tenant_id' => $tenant, 'status' => 'failed']);
        $this->assertSame(2, DB::table('published_menu_versions')->count());
    }

    public function test_tenant_scoping_and_independent_scope_sequences(): void
    {
        [$tenant, $branch] = $this->graph();
        $otherBranch = $this->branch($tenant, 'Airport');
        $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.version.versionNumber', 1);
        $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $otherBranch, 'channel' => 'pos'], $this->headers($tenant))->assertUnprocessable();
        $foreign = $this->tenant('foreign');
        [, , $foreignMenu] = $this->graph($foreign);
        $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $branch, 'channel' => 'pos', 'menuIds' => [$foreignMenu]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menuIds');
        $this->getJson('/api/v1/admin/menu-management/current-version?branchId='.$branch.'&channel=pos', $this->headers($foreign))->assertUnprocessable()->assertJsonValidationErrors('branchId');
    }

    public function test_assignment_scope_order_controls_automatic_preview_and_published_snapshot_contract(): void
    {
        [$tenant, $branch, $first, $product] = $this->graph();
        $second = $this->menu($tenant, $product, 'Second', 0);
        $inactive = $this->menu($tenant, $product, 'Inactive', 50);
        DB::table('menus')->where('id', $first)->update(['priority' => 100]);
        $headers = $this->headers($tenant);

        $this->putJson('/api/v1/admin/menu-management/assignments', [
            'branchId' => $branch,
            'channel' => 'pos',
            'assignments' => [
                ['menuId' => $first, 'priority' => 0, 'isActive' => true],
                ['menuId' => $second, 'priority' => 1, 'isActive' => true],
                ['menuId' => $inactive, 'isActive' => false],
            ],
        ], $headers)->assertOk();
        $initial = $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.version.versionNumber', 1)->json('data.version');
        $initialPayload = $this->getJson("/api/v1/admin/menu-management/versions/{$initial['id']}?includePayload=true", $headers)
            ->assertOk()
            ->json('data.payload');
        $this->assertSame([$first, $second], array_column($initialPayload['menus'], 'id'));
        $this->assertSame([0, 1], array_column($initialPayload['menus'], 'scopeOrder'));
        $this->assertArrayNotHasKey('priority', $initialPayload['menus'][0]);
        $this->putJson('/api/v1/admin/menu-management/assignments', [
            'branchId' => $branch,
            'channel' => 'pos',
            'assignments' => [
                ['menuId' => $second, 'priority' => 0, 'isActive' => true],
                ['menuId' => $first, 'priority' => 1, 'isActive' => true],
                ['menuId' => $inactive, 'isActive' => false],
            ],
        ], $headers)->assertOk();

        $this->postJson('/api/v1/admin/menu-management/validate', ['branchId' => $branch, 'channel' => 'pos'], $headers)
            ->assertOk()
            ->assertJsonPath('data.menus.0.menuId', $second)
            ->assertJsonPath('data.menus.1.menuId', $first);
        $this->postJson('/api/v1/admin/menu-management/preview', ['branchId' => $branch, 'channel' => 'pos'], $headers)
            ->assertOk()
            ->assertJsonPath('data.menus.0.id', $second)
            ->assertJsonPath('data.menus.1.id', $first)
            ->assertJsonCount(2, 'data.menus');

        $version = $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.version.versionNumber', 2)->json('data.version');
        $payload = $this->getJson("/api/v1/admin/menu-management/versions/{$version['id']}?includePayload=true", $headers)
            ->assertOk()
            ->json('data.payload');
        $this->assertSame([$second, $first], array_column($payload['menus'], 'id'));
        $this->assertSame([0, 1], array_column($payload['menus'], 'scopeOrder'));
        $this->assertSame(3, $payload['context']['schemaVersion']);
        $this->assertArrayNotHasKey('priority', $payload['menus'][0]);
    }

    public function test_automatic_snapshot_order_is_independent_per_branch_channel_scope(): void
    {
        [$tenant, $downtown, $first, $product] = $this->graph();
        $second = $this->menu($tenant, $product, 'Second', 0);
        $airport = $this->branch($tenant, 'Airport');
        DB::table('menus')->where('id', $first)->update(['priority' => 100]);
        $headers = $this->headers($tenant);

        foreach ([
            [$downtown, [['menuId' => $first, 'priority' => 0, 'isActive' => true], ['menuId' => $second, 'priority' => 1, 'isActive' => true]]],
            [$airport, [['menuId' => $second, 'priority' => 0, 'isActive' => true], ['menuId' => $first, 'priority' => 1, 'isActive' => true]]],
        ] as [$branch, $assignments]) {
            $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branch, 'channel' => 'pos', 'assignments' => $assignments], $headers)->assertOk();
        }

        $downtownVersion = $this->publish($tenant, $downtown)->assertOk()->json('data.version.id');
        $airportVersion = $this->publish($tenant, $airport)->assertOk()->json('data.version.id');
        $downtownPayload = json_decode((string) DB::table('published_menu_versions')->where('id', $downtownVersion)->value('payload_json'), true);
        $airportPayload = json_decode((string) DB::table('published_menu_versions')->where('id', $airportVersion)->value('payload_json'), true);

        $this->assertSame([$first, $second], array_column($downtownPayload['menus'], 'id'));
        $this->assertSame([$second, $first], array_column($airportPayload['menus'], 'id'));
        $this->assertSame([0, 1], array_column($downtownPayload['menus'], 'scopeOrder'));
        $this->assertSame([0, 1], array_column($airportPayload['menus'], 'scopeOrder'));
    }

    public function test_explicit_menu_ids_retain_canonical_menu_order_and_publish_scope_order(): void
    {
        [$tenant, $branch, $first, $product] = $this->graph();
        $second = $this->menu($tenant, $product, 'Second', 0);
        DB::table('menus')->where('id', $first)->update(['priority' => 100]);
        DB::table('menu_assignments')->insert(['tenant_id' => $tenant, 'menu_id' => $second, 'branch_id' => $branch, 'channel' => 'pos', 'priority' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        $version = $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $branch, 'channel' => 'pos', 'menuIds' => [$first, $second]], $this->headers($tenant))
            ->assertOk()
            ->json('data.version.id');
        $payload = json_decode((string) DB::table('published_menu_versions')->where('id', $version)->value('payload_json'), true);

        $this->assertSame([$second, $first], array_column($payload['menus'], 'id'));
        $this->assertSame([0, 1], array_column($payload['menus'], 'scopeOrder'));
    }

    public function test_publish_without_active_assignments_records_the_shared_no_assigned_menu_result(): void
    {
        [$tenant, $branch, $menu] = $this->graph();
        DB::table('menu_assignments')->where('menu_id', $menu)->update(['is_active' => false]);

        $this->publish($tenant, $branch)->assertUnprocessable()->assertJsonValidationErrors('publish');
        $result = (string) DB::table('menu_publications')->where('tenant_id', $tenant)->value('validation_result');
        $this->assertStringContainsString('NO_ASSIGNED_MENU', $result);

        $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $branch, 'channel' => 'pos', 'menuIds' => [$menu]], $this->headers($tenant))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('publish');
        $explicitResult = (string) DB::table('menu_publications')->where('tenant_id', $tenant)->latest('id')->value('validation_result');
        $this->assertStringContainsString('MENU_MISSING_ASSIGNMENT', $explicitResult);
        $this->assertStringNotContainsString('NO_ASSIGNED_MENU', $explicitResult);
    }

    public function test_schema_v3_recipe_snapshot_is_immutable_ordered_and_recipe_only_change_versions_it(): void
    {
        [$tenant, $branch, , $product, $variant] = $this->graph();
        $beans = $this->material($tenant, 'BEANS', 'kilogram');
        $milk = $this->material($tenant, 'MILK', 'liter');
        $recipe = DB::table('variant_recipes')->insertGetId(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('variant_recipe_components')->insert([
            ['tenant_id' => $tenant, 'variant_recipe_id' => $recipe, 'inventory_item_id' => $milk, 'quantity' => '250', 'unit_code' => 'ml', 'sort_order' => 2, 'created_at' => now(), 'updated_at' => now()],
            ['tenant_id' => $tenant, 'variant_recipe_id' => $recipe, 'inventory_item_id' => $beans, 'quantity' => '18', 'unit_code' => 'g', 'sort_order' => 1, 'created_at' => now(), 'updated_at' => now()],
        ]);
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Extras', 'selection_type' => 'single', 'max_selections' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $option = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Shot', 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'created_at' => now(), 'updated_at' => now()]);
        $profile = DB::table('modifier_option_recipe_profiles')->insertGetId(['tenant_id' => $tenant, 'modifier_option_id' => $option, 'scope_type' => 'global', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('modifier_option_recipe_profile_components')->insert(['tenant_id' => $tenant, 'modifier_option_recipe_profile_id' => $profile, 'inventory_item_id' => $beans, 'operation' => 'add', 'quantity' => '18', 'unit_code' => 'g', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);

        $one = $this->publish($tenant, $branch)->assertOk()->json('data.version');
        $payload = json_decode((string) DB::table('published_menu_versions')->where('id', $one['id'])->value('payload_json'), true);
        $node = $payload['menus'][0]['sections'][0]['products'][0]['variants'][0];
        $this->assertSame(3, $payload['context']['schemaVersion']);
        $this->assertSame([$beans, $milk], array_column($node['baseRecipe'], 'materialId'));
        $this->assertSame('18', $node['baseRecipe'][0]['quantity']);
        $this->assertSame('g', $node['baseRecipe'][0]['unitCode']);
        $this->assertSame($option, $node['modifierRecipeAdjustments'][0]['optionId']);
        $text = json_encode($payload);
        foreach (['current_stock', 'minimum_stock', 'cost', 'warehouse', 'balance', 'movement', 'reservation', 'inventoryAvailability'] as $excluded) {
            $this->assertStringNotContainsString($excluded, $text);
        }
        DB::table('variant_recipe_components')->where('variant_recipe_id', $recipe)->where('inventory_item_id', $beans)->update(['quantity' => '20']);
        $two = $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.version.versionNumber', 2)->json('data.version');
        $this->assertNotSame($one['checksum'], $two['checksum']);
    }

    private function publish(int $tenant, int $branch)
    {
        return $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $branch, 'channel' => 'pos'], $this->headers($tenant));
    }

    private function menu(int $tenant, int $product, string $name, int $priority): int
    {
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'status' => 'draft', 'priority' => $priority, 'created_at' => now(), 'updated_at' => now()]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_item_placements')->insert(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'is_visible' => true, 'created_at' => now(), 'updated_at' => now()]);

        return $menu;
    }

    private function graph(?int $tenant = null): array
    {
        $tenant ??= $this->tenant('alpha');
        $branch = $this->branch($tenant);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Latte', 'price' => 4, 'cost_price' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => 4, 'cost_price' => 1, 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'status' => 'draft', 'created_at' => now(), 'updated_at' => now()]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $placement = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'is_visible' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_assignments')->insert(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => 'pos', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return [$tenant, $branch, $menu, $product, $variant, $section, $placement];
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenant, string $name = 'Downtown'): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }

    private function material(int $tenant, string $sku, string $unit): int
    {
        return DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => $sku, 'sku' => $sku, 'unit' => $unit, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }
}
