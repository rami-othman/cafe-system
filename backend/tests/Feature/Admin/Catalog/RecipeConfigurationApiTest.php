<?php

namespace Tests\Feature\Admin\Catalog;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RecipeConfigurationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_recipe_is_tenant_scoped_uses_decimal_strings_and_resolves_additions(): void
    {
        $tenant = $this->tenant('recipes');
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Latte', 'price' => 4, 'is_active' => true, 'is_stock_tracked' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Medium', 'base_price' => 4, 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $beans = $this->material($tenant, 'BEANS', 'kilogram');
        $milk = $this->material($tenant, 'MILK', 'liter');
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $beans, 'quantity' => '18', 'unitCode' => 'g'], ['materialId' => $milk, 'quantity' => '250', 'unitCode' => 'ml']]], $this->headers($tenant))->assertOk()->assertJsonPath('data.components.0.quantity', '18');
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Extras', 'selection_type' => 'multiple', 'max_selections' => 2, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $option = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Shot', 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'created_at' => now(), 'updated_at' => now()]);
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'add', 'quantity' => '18', 'unitCode' => 'g']]], $this->headers($tenant))->assertOk();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option]]], $this->headers($tenant))->assertOk()->assertJsonPath('data.components.0.quantity', '36');
    }

    public function test_unmapped_material_unit_is_not_configurable(): void
    {
        $tenant = $this->tenant('units');
        $id = $this->material($tenant, 'UNKNOWN', 'bucket');
        $this->getJson('/api/v1/admin/catalog/materials', $this->headers($tenant))->assertOk()->assertJsonFragment(['id' => $id, 'configurationAvailable' => false, 'unavailabilityReason' => 'unit_unmapped']);
    }

    public function test_nearest_profile_fully_replaces_inheritance_and_empty_override_suppresses_it(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('inheritance');
        $beans = $this->material($tenant, 'BEANS', 'kilogram');
        $milk = $this->material($tenant, 'MILK', 'liter');
        $headers = $this->headers($tenant);

        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'add', 'quantity' => '18', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->getJson("/api/v1/admin/catalog/products/$product/modifier-options/$option/recipe-adjustments", $headers)->assertOk()
            ->assertJsonPath('data.hasOverride', false)->assertJsonPath('data.inheritedFrom', 'global')->assertJsonPath('data.components.0.materialId', $beans);

        $this->putJson("/api/v1/admin/catalog/products/$product/modifier-options/$option/recipe-adjustments", ['components' => [['materialId' => $milk, 'operation' => 'add', 'quantity' => '50', 'unitCode' => 'ml']]], $headers)->assertOk();
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/modifier-options/$option/recipe-adjustments", $headers)->assertOk()
            ->assertJsonPath('data.inheritedFrom', 'product')->assertJsonPath('data.components.0.materialId', $milk);

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/modifier-options/$option/recipe-adjustments", ['components' => []], $headers)->assertOk()
            ->assertJsonPath('data.hasOverride', true)->assertJsonCount(0, 'data.components');
        $this->deleteJson("/api/v1/admin/catalog/product-variants/$variant/modifier-options/$option/recipe-adjustments", [], $headers)->assertOk();
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/modifier-options/$option/recipe-adjustments", $headers)->assertOk()
            ->assertJsonPath('data.hasOverride', false)->assertJsonPath('data.inheritedFrom', 'product')->assertJsonPath('data.components.0.materialId', $milk);
        $this->deleteJson("/api/v1/admin/catalog/products/$product/modifier-options/$option/recipe-adjustments", [], $headers)->assertOk();
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/modifier-options/$option/recipe-adjustments", $headers)->assertOk()
            ->assertJsonPath('data.inheritedFrom', 'global')->assertJsonPath('data.components.0.materialId', $beans);
    }

    public function test_product_modifier_assignment_summary_uses_effective_profile_without_exposing_profiles(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('assignment-summary');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);

        $this->getJson("/api/v1/admin/catalog/products/$product/modifier-groups", $headers)
            ->assertOk()
            ->assertJsonPath('data.0.materialImpactConfigured', false)
            ->assertJsonMissingPath('data.0.recipeProfiles');

        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", [
            'components' => [['materialId' => $material, 'operation' => 'add', 'quantity' => '1', 'unitCode' => 'g']],
        ], $headers)->assertOk();

        $this->getJson("/api/v1/admin/catalog/products/$product/modifier-groups", $headers)
            ->assertOk()
            ->assertJsonPath('data.0.materialImpactConfigured', true);

        $this->putJson("/api/v1/admin/catalog/products/$product/modifier-options/$option/recipe-adjustments", ['components' => []], $headers)
            ->assertOk();
        $this->getJson("/api/v1/admin/catalog/products/$product/modifier-groups", $headers)
            ->assertOk()
            ->assertJsonPath('data.0.materialImpactConfigured', false);
    }

    public function test_variant_list_summary_reports_recipe_configuration_and_component_count(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('variant-summary');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);

        $before = $this->getJson("/api/v1/admin/catalog/products/$product", $headers)
            ->assertOk()
            ->json('data.variants.0');
        $this->assertFalse($before['recipeConfigured']);
        $this->assertSame(0, $before['recipeComponentCount']);

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [
                ['materialId' => $material, 'quantity' => '1', 'unitCode' => 'g'],
                ['materialId' => $material + 1, 'quantity' => '2', 'unitCode' => 'g'],
            ],
        ], $headers)->assertUnprocessable();

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [['materialId' => $material, 'quantity' => '1', 'unitCode' => 'g']],
        ], $headers)->assertOk();
        $after = $this->getJson("/api/v1/admin/catalog/products/$product", $headers)
            ->assertOk()
            ->json('data.variants.0');

        $this->assertTrue($after['recipeConfigured']);
        $this->assertSame(1, $after['recipeComponentCount']);
        $this->assertArrayNotHasKey('components', $after);
    }

    public function test_resolver_uses_exact_add_remove_quantity_and_group_constraints(): void
    {
        [$tenant, $product, $variant, $group, $shot] = $this->recipeContext('resolver');
        $beans = $this->material($tenant, 'BEANS', 'kilogram');
        $regularMilk = $this->material($tenant, 'MILK', 'liter');
        $oatMilk = $this->material($tenant, 'OAT', 'liter');
        $headers = $this->headers($tenant);
        $oat = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Oat', 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [
            ['materialId' => $beans, 'quantity' => '18', 'unitCode' => 'g'], ['materialId' => $regularMilk, 'quantity' => '250', 'unitCode' => 'ml'],
        ]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/modifier-options/$shot/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'add', 'quantity' => '18', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/modifier-options/$oat/recipe-adjustments", ['components' => [
            ['materialId' => $regularMilk, 'operation' => 'remove', 'quantity' => '250', 'unitCode' => 'ml'], ['materialId' => $oatMilk, 'operation' => 'add', 'quantity' => '250', 'unitCode' => 'ml'],
        ]], $headers)->assertOk();

        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $shot], ['optionId' => $oat]]], $headers)->assertOk()
            ->assertJsonPath('data.components.0.quantity', '36')->assertJsonPath('data.components.1.materialId', $oatMilk)->assertJsonCount(2, 'data.components');
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $shot], ['optionId' => $oat], ['optionId' => $shot]]], $headers)->assertUnprocessable();
    }

    public function test_resolver_aggregates_removes_and_is_deterministic_for_selection_order(): void
    {
        [$tenant, $product, $variant, $group, $first] = $this->recipeContext('remove-order');
        $beans = $this->material($tenant, 'BEANS', 'kilogram');
        $second = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Less Beans', 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $beans, 'quantity' => '18', 'unitCode' => 'g']]], $headers)->assertOk();
        foreach ([$first, $second] as $option) {
            $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'remove', 'quantity' => '9', 'unitCode' => 'g']]], $headers)->assertOk();
        }
        $forward = $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $first], ['optionId' => $second]]], $headers)->assertOk()->json('data');
        $reverse = $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $second], ['optionId' => $first]]], $headers)->assertOk()->json('data');
        $this->assertSame($forward, $reverse);
        $this->assertSame([], $forward['components']);

        $this->putJson("/api/v1/admin/catalog/modifier-options/$second/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'remove', 'quantity' => '10', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $first], ['optionId' => $second]]], $headers)->assertUnprocessable();
    }

    public function test_quantity_enabled_adds_are_exact_and_remove_profiles_are_rejected(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('quantity-add');
        DB::table('product_modifier_group')->where('product_id', $product)->where('modifier_group_id', $group)->update(['allow_quantity_override' => true]);
        $beans = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $beans, 'quantity' => '18.125', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'add', 'quantity' => '0.125', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option, 'quantity' => 1]]], $headers)->assertOk()->assertJsonPath('data.components.0.quantity', '18.25');
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option, 'quantity' => 3]]], $headers)->assertOk()->assertJsonPath('data.components.0.quantity', '18.5');
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'remove', 'quantity' => '1', 'unitCode' => 'g']]], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option, 'quantity' => 0]]], $headers)->assertUnprocessable();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option, 'quantity' => -1]]], $headers)->assertUnprocessable();
    }

    public function test_resolver_aggregates_adds_in_a_canonical_order_and_preserves_decimal_strings(): void
    {
        [$tenant, $product, $variant, $group, $first] = $this->recipeContext('add-order');
        $beans = $this->material($tenant, 'BEANS', 'kilogram');
        $milk = $this->material($tenant, 'MILK', 'liter');
        $second = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Double shot', 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [
            ['materialId' => $milk, 'quantity' => '250.125', 'unitCode' => 'ml'],
            ['materialId' => $beans, 'quantity' => '18.125', 'unitCode' => 'g'],
        ]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/modifier-options/$first/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'add', 'quantity' => '0.125', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/modifier-options/$second/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'add', 'quantity' => '0.25', 'unitCode' => 'g']]], $headers)->assertOk();

        $forward = $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $first], ['optionId' => $second]]], $headers)->assertOk()->json('data');
        $reverse = $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $second], ['optionId' => $first]]], $headers)->assertOk()->json('data');

        $this->assertSame($forward, $reverse);
        $this->assertSame([$beans, $milk], array_column($forward['components'], 'materialId'));
        $this->assertSame('18.5', $forward['components'][0]['quantity']);
        $this->assertSame('250.125', $forward['components'][1]['quantity']);
    }

    public function test_recipe_writes_are_tenant_scoped_and_archived_resources_are_read_only(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('ownership');
        $foreignTenant = $this->tenant('ownership-foreign');
        $foreignMaterial = $this->material($foreignTenant, 'FOREIGN', 'kilogram');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $foreignMaterial, 'quantity' => '1', 'unitCode' => 'g']]], $headers)->assertUnprocessable();
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $this->headers($foreignTenant))->assertNotFound();
        DB::table('product_variants')->where('id', $variant)->update(['is_active' => false]);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => []], $headers)->assertUnprocessable();
        DB::table('product_variants')->where('id', $variant)->update(['is_active' => true]);
        DB::table('modifier_options')->where('id', $option)->update(['is_active' => false]);
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => []], $headers)->assertUnprocessable();
        DB::table('modifier_options')->where('id', $option)->update(['is_active' => true]);
        DB::table('modifier_groups')->where('id', $group)->update(['is_active' => false]);
        $this->getJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $headers)->assertUnprocessable();
    }

    public function test_profile_scope_rejects_foreign_materials_unassigned_products_and_archived_variants(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('profile-ownership');
        $foreignTenant = $this->tenant('profile-ownership-foreign');
        $foreignMaterial = $this->material($foreignTenant, 'FOREIGN', 'kilogram');
        $localMaterial = $this->material($tenant, 'LOCAL', 'kilogram');
        $headers = $this->headers($tenant);

        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => [['materialId' => $foreignMaterial, 'operation' => 'add', 'quantity' => '1', 'unitCode' => 'g']]], $headers)->assertUnprocessable();
        $this->getJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $this->headers($foreignTenant))->assertNotFound();

        $otherCategory = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Tea', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $otherProduct = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $otherCategory, 'name' => 'Tea', 'price' => 2, 'is_active' => true, 'is_stock_tracked' => true, 'created_at' => now(), 'updated_at' => now()]);
        $otherVariant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $otherProduct, 'name' => 'Small', 'base_price' => 2, 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $payload = ['components' => [['materialId' => $localMaterial, 'operation' => 'add', 'quantity' => '1', 'unitCode' => 'g']]];
        $this->putJson("/api/v1/admin/catalog/products/$otherProduct/modifier-options/$option/recipe-adjustments", $payload, $headers)->assertUnprocessable();
        $this->putJson("/api/v1/admin/catalog/product-variants/$otherVariant/modifier-options/$option/recipe-adjustments", $payload, $headers)->assertUnprocessable();

        DB::table('product_variants')->where('id', $variant)->update(['is_active' => false]);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/modifier-options/$option/recipe-adjustments", $payload, $headers)->assertUnprocessable();
        $this->putJson("/api/v1/admin/catalog/products/$product/modifier-options/$option/recipe-adjustments", $payload, $headers)->assertOk();
        DB::table('inventory_items')->where('id', $localMaterial)->update(['is_active' => false]);
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $payload, $headers)->assertUnprocessable();
    }

    /** @return array{int, int, int, int, int} */
    private function recipeContext(string $slug): array
    {
        $tenant = $this->tenant($slug);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Latte', 'price' => 4, 'is_active' => true, 'is_stock_tracked' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Medium', 'base_price' => 4, 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Extras', 'selection_type' => 'multiple', 'max_selections' => 2, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $option = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Shot', 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'created_at' => now(), 'updated_at' => now()]);

        return [$tenant, $product, $variant, $group, $option];
    }

    private function material(int $tenant, string $sku, string $unit): int
    {
        return DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => $sku, 'sku' => $sku, 'unit' => $unit, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
