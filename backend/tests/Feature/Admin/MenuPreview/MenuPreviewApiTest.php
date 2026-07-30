<?php

namespace Tests\Feature\Admin\MenuPreview;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class MenuPreviewApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_single_preview_resolves_context_structure_and_is_read_only(): void
    {
        [$tenant, $branch, $menu, $product] = $this->graph();
        $before = [DB::table('menus')->where('id', $menu)->value('updated_at'), DB::table('products')->where('id', $product)->value('updated_at'), DB::table('menu_audit_logs')->count(), DB::table('product_operational_availabilities')->count()];

        $this->preview($tenant, $menu, $branch)->assertOk()
            ->assertJsonPath('data.context.timezone', 'Asia/Damascus')
            ->assertJsonPath('data.context.evaluatedAt', '2026-08-01T10:00:00+03:00')
            ->assertJsonPath('data.menus.0.isAssigned', true)
            ->assertJsonPath('data.menus.0.sections.0.products.0.name', 'Latte')
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.0.effectivePrice', 4)
            ->assertJsonStructure(['data' => ['canPublish', 'validation' => ['errors', 'warnings', 'information'], 'menus' => [['sections' => [['products' => [['modifierGroups']]]]]]]]);

        $this->assertSame($before, [DB::table('menus')->where('id', $menu)->value('updated_at'), DB::table('products')->where('id', $product)->value('updated_at'), DB::table('menu_audit_logs')->count(), DB::table('product_operational_availabilities')->count()]);
        $this->assertSame(0, DB::table('menu_publications')->count());
        $this->assertSame(0, DB::table('published_menu_versions')->count());
    }

    public function test_collection_defaults_to_active_assignments_and_is_tenant_safe(): void
    {
        [$tenant, $branch, $menu] = $this->graph();
        $this->postJson('/api/v1/admin/menu-management/preview', ['branchId' => $branch, 'channel' => 'pos'], $this->headers($tenant))
            ->assertOk()->assertJsonCount(1, 'data.menus')->assertJsonPath('data.menus.0.id', $menu);
        $foreign = $this->tenant('foreign');
        [, , $foreignMenu] = $this->graph($foreign);
        $this->preview($tenant, $foreignMenu, $branch)->assertNotFound();
        $this->postJson('/api/v1/admin/menu-management/preview', ['branchId' => $branch, 'channel' => 'pos', 'menuIds' => [$foreignMenu]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menuIds');
    }

    public function test_price_overrides_and_menu_schedule_are_resolved(): void
    {
        [$tenant, $branch, $menu, $product, $variant] = $this->graph();
        DB::table('product_variant_price_overrides')->insert(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'scope_type' => 'branch_channel', 'scope_key' => "branch:{$branch}|channel:pos", 'branch_id' => $branch, 'channel' => 'pos', 'override_price' => 5.5, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_availability_rules')->insert(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => 'pos', 'day_of_week' => 6, 'start_time' => '09:00', 'end_time' => '11:00', 'priority' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $response = $this->preview($tenant, $menu, $branch)->assertOk();
        $response->assertJsonPath('data.menus.0.isScheduledAvailable', true)->assertJsonPath('data.menus.0.sections.0.products.0.variants.0.effectivePrice', 5.5)->assertJsonPath('data.menus.0.sections.0.products.0.variants.0.matchedPriceScope', 'branch_channel');
        $this->assertSame('4.00', DB::table('product_variants')->where('id', $variant)->value('base_price'));
        $this->assertSame('4.00', DB::table('products')->where('id', $product)->value('price'));
    }

    public function test_hidden_and_unavailable_products_can_be_included_for_diagnosis(): void
    {
        [$tenant, $branch, $menu, $product, $variant, $section, $placement] = $this->graph();
        DB::table('menu_item_placements')->where('id', $placement)->update(['is_visible' => false]);
        DB::table('product_variant_operational_availabilities')->insert(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'branch_id' => $branch, 'channel' => 'pos', 'status' => 'sold_out', 'created_at' => now(), 'updated_at' => now()]);
        $this->preview($tenant, $menu, $branch)->assertOk()->assertJsonCount(0, 'data.menus.0.sections.0.products');
        $this->preview($tenant, $menu, $branch, ['includeHidden' => true])->assertOk()
            ->assertJsonPath('data.menus.0.sections.0.products.0.isSellable', false)
            ->assertJsonFragment(['hidden'])
            ->assertJsonFragment(['variant_sold_out']);
        $this->preview($tenant, $menu, $branch, ['includeHidden' => true, 'includeUnavailable' => false])->assertOk()->assertJsonCount(0, 'data.menus.0.sections.0.products');
    }

    public function test_variant_schedule_precedence_and_expired_operational_state_are_resolved(): void
    {
        [$tenant, $branch, $menu, $product, $variant] = $this->graph();
        DB::table('product_availability_rules')->insert([
            ['tenant_id' => $tenant, 'product_id' => $product, 'product_variant_id' => null, 'branch_id' => $branch, 'channel' => 'pos', 'day_of_week' => 6, 'start_time' => '00:00', 'end_time' => '01:00', 'priority' => 0, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()],
            ['tenant_id' => $tenant, 'product_id' => $product, 'product_variant_id' => $variant, 'branch_id' => $branch, 'channel' => 'pos', 'day_of_week' => 6, 'start_time' => '09:00', 'end_time' => '11:00', 'priority' => 0, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()],
        ]);
        DB::table('product_variant_operational_availabilities')->insert(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'branch_id' => $branch, 'channel' => 'pos', 'status' => 'temporarily_unavailable', 'unavailable_until' => '2026-08-01 05:00:00+00:00', 'created_at' => now(), 'updated_at' => now()]);

        $this->preview($tenant, $menu, $branch)->assertOk()
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.0.isScheduledAvailable', true)
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.0.isOperationallyAvailable', true)
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.0.isSellable', true);
    }

    public function test_validation_remains_when_filtered_preview_has_no_products(): void
    {
        [$tenant, $branch, $menu, $product, $variant, $section, $placement] = $this->graph();
        DB::table('menu_assignments')->where('menu_id', $menu)->delete();
        DB::table('menu_item_placements')->where('id', $placement)->update(['is_visible' => false]);

        $this->preview($tenant, $menu, $branch, ['includeUnavailable' => false])->assertOk()
            ->assertJsonPath('data.canPublish', false)
            ->assertJsonCount(0, 'data.menus.0.sections.0.products')
            ->assertJsonFragment(['code' => 'MENU_MISSING_ASSIGNMENT']);
    }

    public function test_localization_modifier_overrides_and_option_availability_are_preserved(): void
    {
        [$tenant, $branch, $menu, $product, $variant] = $this->graph();
        DB::table('products')->where('id', $product)->update(['name_ar' => 'لاتيه', 'description_ar' => 'قهوة']);
        DB::table('product_variants')->where('id', $variant)->update(['name_ar' => 'عادي']);
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Milk', 'name_ar' => 'حليب', 'group_type' => 'choice', 'selection_type' => 'single', 'is_required' => false, 'min_selections' => 0, 'max_selections' => 1, 'allow_quantity' => false, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('modifier_options')->insert(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Oat', 'name_ar' => 'شوفان', 'price_delta' => 1, 'is_active' => true, 'is_available' => false, 'sort_order' => 2, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'sort_order' => 4, 'is_required_override' => true, 'min_selections_override' => 1, 'max_selections_override' => 1, 'allow_quantity_override' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->preview($tenant, $menu, $branch, ['language' => 'ar'])->assertOk()
            ->assertJsonPath('data.menus.0.sections.0.products.0.name', 'لاتيه')
            ->assertJsonPath('data.menus.0.sections.0.products.0.variants.0.name', 'عادي')
            ->assertJsonPath('data.menus.0.sections.0.products.0.modifierGroups.0.name', 'حليب')
            ->assertJsonPath('data.menus.0.sections.0.products.0.modifierGroups.0.isRequired', true)
            ->assertJsonPath('data.menus.0.sections.0.products.0.modifierGroups.0.allowQuantity', true)
            ->assertJsonPath('data.menus.0.sections.0.products.0.modifierGroups.0.options.0.isAvailable', false);
    }

    private function preview(int $tenant, int $menu, int $branch, array $extra = []): TestResponse
    {
        return $this->postJson('/api/v1/admin/menus/'.$menu.'/preview', array_replace(['branchId' => $branch, 'channel' => 'pos', 'at' => '2026-08-01T10:00:00+03:00'], $extra), $this->headers($tenant));
    }

    private function graph(?int $tenant = null): array
    {
        $tenant ??= $this->tenant('alpha');
        $branch = $this->branch($tenant);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Latte', 'description' => 'Coffee', 'price' => 4, 'cost_price' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => 4, 'cost_price' => 1, 'is_default' => true, 'is_active' => true, 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'status' => 'draft', 'priority' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'sort_order' => 0, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $placement = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'sort_order' => 0, 'is_visible' => true, 'is_featured' => false, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_assignments')->insert(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => 'pos', 'priority' => 0, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return [$tenant, $branch, $menu, $product, $variant, $section, $placement];
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
