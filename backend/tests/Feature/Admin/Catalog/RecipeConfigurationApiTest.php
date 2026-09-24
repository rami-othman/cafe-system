<?php

namespace Tests\Feature\Admin\Catalog;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use App\Models\ProductVariant;
use App\Services\Catalog\RecipeConfigurationService;
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

    public function test_base_unit_recipe_saves_without_an_inventory_conversion(): void
    {
        [$tenant, , $variant] = $this->recipeContext('base-unit-recipe');
        $material = $this->rawMaterial($tenant, 'GROUND-COFFEE', 'gram');

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [['materialId' => $material, 'quantity' => '18.125', 'unitCode' => 'g']],
        ], $this->headers($tenant))->assertOk();
    }

    public function test_recipe_save_rejects_a_recipe_unit_without_an_active_inventory_conversion(): void
    {
        [$tenant, , $variant] = $this->recipeContext('missing-conversion');
        $material = $this->rawMaterial($tenant, 'GROUND-COFFEE', 'gram');

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [['materialId' => $material, 'quantity' => '1', 'unitCode' => 'kg']],
        ], $this->headers($tenant))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['components.0.unitCode' => 'No active Inventory conversion exists from kilogram to gram.']);
    }

    public function test_recipe_save_rejects_inactive_and_invalid_inventory_conversions(): void
    {
        [$tenant, , $variant] = $this->recipeContext('inactive-invalid-conversion');
        $material = $this->rawMaterial($tenant, 'GROUND-COFFEE', 'gram');
        $payload = ['components' => [['materialId' => $material, 'quantity' => '1', 'unitCode' => 'kg']]];
        $this->conversion($tenant, $material, 'kilogram', 'gram', '1000.000000', false);

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $payload, $this->headers($tenant))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['components.0.unitCode' => 'No active Inventory conversion exists from kilogram to gram.']);

        DB::table('inventory_item_unit_conversions')->where('tenant_id', $tenant)->where('inventory_item_id', $material)->update(['is_active' => true, 'factor' => '0.000000']);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $payload, $this->headers($tenant))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['components.0.unitCode' => 'The active Inventory conversion from kilogram to gram is invalid.']);
    }

    public function test_recipe_save_accepts_active_mass_and_volume_inventory_conversions(): void
    {
        [$tenant, , $variant] = $this->recipeContext('active-conversions');
        $beans = $this->rawMaterial($tenant, 'GROUND-COFFEE', 'gram');
        $milk = $this->rawMaterial($tenant, 'MILK', 'milliliter');

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [['materialId' => $milk, 'quantity' => '0.250', 'unitCode' => 'l']],
        ], $this->headers($tenant))->assertUnprocessable()
            ->assertJsonValidationErrors(['components.0.unitCode' => 'No active Inventory conversion exists from liter to milliliter.']);

        $this->conversion($tenant, $beans, 'kilogram', 'gram', '1000.000000');
        $this->conversion($tenant, $milk, 'liter', 'milliliter', '1000.000000');

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [
                ['materialId' => $beans, 'quantity' => '0.018', 'unitCode' => 'kg'],
                ['materialId' => $milk, 'quantity' => '0.250', 'unitCode' => 'l'],
            ],
        ], $this->headers($tenant))->assertOk();
    }

    public function test_recipe_save_rejects_a_converted_quantity_that_is_not_representable_at_inventory_precision(): void
    {
        [$tenant, , $variant] = $this->recipeContext('conversion-precision');
        $material = $this->rawMaterial($tenant, 'GROUND-COFFEE', 'gram');
        $this->conversion($tenant, $material, 'kilogram', 'gram', '0.500000');

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [['materialId' => $material, 'quantity' => '0.001', 'unitCode' => 'kg']],
        ], $this->headers($tenant))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['components.0.quantity' => 'Converted quantity cannot be represented at Inventory 3-decimal precision.']);
    }

    public function test_modifier_recipe_save_enforces_the_same_inventory_conversion_contract(): void
    {
        [$tenant, , , , $option] = $this->recipeContext('modifier-conversion');
        $material = $this->rawMaterial($tenant, 'GROUND-COFFEE', 'gram');
        $payload = ['components' => [['materialId' => $material, 'operation' => 'add', 'quantity' => '0.018', 'unitCode' => 'kg']]];

        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $payload, $this->headers($tenant))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('components.0.unitCode');

        $this->conversion($tenant, $material, 'kilogram', 'gram', '1000.000000');
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $payload, $this->headers($tenant))->assertOk();
    }

    public function test_material_catalog_exposes_only_base_and_active_inventory_recipe_units(): void
    {
        $tenant = $this->tenant('allowed-recipe-units');
        $material = $this->rawMaterial($tenant, 'GROUND-COFFEE', 'gram');
        $this->conversion($tenant, $material, 'kilogram', 'gram', '1000.000000');
        $this->conversion($tenant, $material, 'liter', 'gram', '1.000000', false);
        $this->conversion($tenant, $material, 'milliliter', 'kilogram', '1.000000');

        $this->getJson('/api/v1/admin/catalog/materials', $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.0.id', $material)
            ->assertJsonPath('data.0.allowedRecipeUnits', ['g', 'kg']);
    }

    public function test_material_catalog_keeps_a_valid_inventory_count_base_unit_available_for_recipes(): void
    {
        $tenant = $this->tenant('inventory-count-base-unit');
        $material = $this->rawMaterial($tenant, 'TEA-BAG', 'bag');

        $this->getJson('/api/v1/admin/catalog/materials', $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.0.id', $material)
            ->assertJsonPath('data.0.unitCode', 'bag')
            ->assertJsonPath('data.0.allowedRecipeUnits', ['bag'])
            ->assertJsonPath('data.0.configurationAvailable', true);
    }

    public function test_recipe_resolution_uses_the_inventory_conversion_factor_not_recipe_unit_family_scaling(): void
    {
        [$tenant, , $variant] = $this->recipeContext('inventory-factor-resolution');
        $material = $this->rawMaterial($tenant, 'GROUND-COFFEE', 'gram');
        $this->conversion($tenant, $material, 'kilogram', 'gram', '0.500000');

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [['materialId' => $material, 'quantity' => '2', 'unitCode' => 'kg']],
        ], $this->headers($tenant))->assertOk();

        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => []], $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.components.0.quantity', '1')
            ->assertJsonPath('data.components.0.unitCode', 'g');
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

    public function test_variant_recipe_material_effect_summary_is_bounded_and_tenant_scoped(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('effect-summary');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", [
            'components' => [['materialId' => $material, 'operation' => 'add', 'quantity' => '1', 'unitCode' => 'g']],
        ], $headers)->assertOk();
        $inactive = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Inactive', 'is_active' => false, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);

        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe-material-effects", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.optionId', $option)
            ->assertJsonPath('data.0.inheritedFrom', 'global')
            ->assertJsonPath('data.0.components.0.materialId', $material);
        $foreign = $this->tenant('effect-summary-foreign');
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe-material-effects", $this->headers($foreign))->assertNotFound();
        $this->assertNotSame($option, $inactive);
    }

    public function test_modifier_group_material_effect_summary_returns_global_option_components(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('global-effect-summary');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);

        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", [
            'components' => [['materialId' => $material, 'operation' => 'add', 'quantity' => '20', 'unitCode' => 'g']],
        ], $headers)->assertOk();

        $this->getJson("/api/v1/admin/catalog/modifier-groups/$group/recipe-material-effects", $headers)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.optionId', $option)
            ->assertJsonPath('data.0.components.0.materialId', $material)
            ->assertJsonPath('data.0.components.0.quantity', '20')
            ->assertJsonPath('data.0.components.0.unitCode', 'g')
            ->assertJsonPath('data.0.components.0.operation', 'add');

        $foreign = $this->tenant('global-effect-summary-foreign');
        $this->getJson("/api/v1/admin/catalog/modifier-groups/$group/recipe-material-effects", $this->headers($foreign))
            ->assertNotFound();
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

    public function test_empty_variant_put_removes_the_override_instead_of_persisting_an_empty_parent(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('clear-base');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [
            'components' => [['materialId' => $material, 'quantity' => '18', 'unitCode' => 'g']],
        ], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => []], $headers)
            ->assertOk()
            ->assertJsonPath('data.hasOverride', false)
            ->assertJsonPath('data.source', 'none')
            ->assertJsonCount(0, 'data.components');
        $this->assertDatabaseMissing('variant_recipes', ['tenant_id' => $tenant, 'product_variant_id' => $variant]);

        $summary = $this->getJson("/api/v1/admin/catalog/products/$product", $headers)->assertOk()->json('data.variants.0');
        $this->assertFalse($summary['recipeConfigured']);
        $this->assertSame(0, $summary['recipeComponentCount']);
    }

    public function test_only_consumable_inventory_types_can_be_configured_as_recipe_materials(): void
    {
        [$tenant, , $variant] = $this->recipeContext('material-eligibility');
        $headers = $this->headers($tenant);
        $rawMaterial = $this->material($tenant, 'ELIGIBLE', 'kilogram');
        $service = $this->material($tenant, 'SERVICE', 'kilogram', 'service');
        $nonStock = $this->material($tenant, 'NON-STOCK', 'kilogram', 'non_stock_item');

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $rawMaterial, 'quantity' => '1', 'unitCode' => 'kg']]], $headers)->assertOk();
        foreach ([$service, $nonStock] as $itemId) {
            $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $itemId, 'quantity' => '1', 'unitCode' => 'kg']]], $headers)
                ->assertUnprocessable()
                ->assertJsonValidationErrors('components');
        }
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

    public function test_inactive_groups_are_excluded_and_inactive_or_archived_options_cannot_be_selected(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('lifecycle-resolution');
        $headers = $this->headers($tenant);

        DB::table('modifier_groups')->where('id', $group)->update(['is_required' => true, 'min_selections' => 1, 'is_active' => false]);
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => []], $headers)->assertOk();

        DB::table('modifier_groups')->where('id', $group)->update(['is_required' => false, 'min_selections' => 0, 'is_active' => true]);
        DB::table('modifier_options')->where('id', $option)->update(['is_active' => false]);
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option]]], $headers)->assertUnprocessable();

        DB::table('modifier_options')->where('id', $option)->update(['is_active' => true, 'deleted_at' => now()]);
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option]]], $headers)->assertUnprocessable();
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
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option, 'quantity' => 2]]], $headers)->assertOk()->assertJsonPath('data.components.0.quantity', '18.375');
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option, 'quantity' => 3]]], $headers)->assertUnprocessable();
        $second = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Second Shot', 'is_active' => true, 'is_available' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->putJson("/api/v1/admin/catalog/modifier-options/$second/recipe-adjustments", ['components' => [['materialId' => $beans, 'operation' => 'add', 'quantity' => '0.125', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option, 'quantity' => 1], ['optionId' => $second, 'quantity' => 1]]], $headers)->assertOk()->assertJsonPath('data.components.0.quantity', '18.375');
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option, 'quantity' => 2], ['optionId' => $second, 'quantity' => 1]]], $headers)->assertUnprocessable();
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

    public function test_recipe_writes_are_tenant_scoped_and_inactive_resources_remain_editable(): void
    {
        [$tenant, $product, $variant, $group, $option] = $this->recipeContext('ownership');
        $foreignTenant = $this->tenant('ownership-foreign');
        $foreignMaterial = $this->material($foreignTenant, 'FOREIGN', 'kilogram');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $foreignMaterial, 'quantity' => '1', 'unitCode' => 'g']]], $headers)->assertUnprocessable();
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $this->headers($foreignTenant))->assertNotFound();
        DB::table('product_variants')->where('id', $variant)->update(['is_active' => false]);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => []], $headers)->assertOk();
        $this->assertFalse((bool) DB::table('product_variants')->where('id', $variant)->value('is_active'));
        DB::table('product_variants')->where('id', $variant)->update(['is_active' => true]);
        DB::table('products')->where('id', $product)->update(['is_active' => false]);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => []], $headers)->assertOk();
        $this->assertFalse((bool) DB::table('products')->where('id', $product)->value('is_active'));
        DB::table('products')->where('id', $product)->update(['is_active' => true]);
        DB::table('modifier_options')->where('id', $option)->update(['is_active' => false]);
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => []], $headers)->assertOk();
        $this->assertFalse((bool) DB::table('modifier_options')->where('id', $option)->value('is_active'));
        DB::table('modifier_options')->where('id', $option)->update(['is_active' => true]);
        DB::table('modifier_groups')->where('id', $group)->update(['is_active' => false]);
        $this->getJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $headers)->assertOk();
        $this->assertFalse((bool) DB::table('modifier_groups')->where('id', $group)->value('is_active'));
        DB::table('modifier_groups')->where('id', $group)->update(['deleted_at' => now()]);
        $this->getJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $headers)->assertUnprocessable();
        DB::table('product_variants')->where('id', $variant)->update(['deleted_at' => now()]);
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => []], $headers)->assertNotFound();
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
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/modifier-options/$option/recipe-adjustments", $payload, $headers)->assertOk();
        $this->assertFalse((bool) DB::table('product_variants')->where('id', $variant)->value('is_active'));
        $this->putJson("/api/v1/admin/catalog/products/$product/modifier-options/$option/recipe-adjustments", $payload, $headers)->assertOk();
        DB::table('inventory_items')->where('id', $localMaterial)->update(['is_active' => false]);
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $payload, $headers)->assertUnprocessable();
    }

    public function test_product_recipe_schema_and_component_validation_match_variant_recipes(): void
    {
        [$tenant, $product] = $this->recipeContext('product-schema');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);

        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [[
            'materialId' => $material, 'quantity' => '18.125000', 'unitCode' => 'g', 'sortOrder' => 4,
        ]]], $headers)->assertOk()
            ->assertJsonPath('data.productId', $product)
            ->assertJsonPath('data.configured', true)
            ->assertJsonPath('data.components.0.quantity', '18.125')
            ->assertJsonPath('data.components.0.sortOrder', 4);

        $this->assertDatabaseCount('product_recipes', 1);
        $this->assertDatabaseHas('product_recipe_components', ['tenant_id' => $tenant, 'inventory_item_id' => $material, 'quantity' => '18.125000']);
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [[
            'materialId' => $material, 'quantity' => '0', 'unitCode' => 'g',
        ]]], $headers)->assertUnprocessable();
    }

    public function test_product_recipe_inheritance_and_variant_override_contract_are_explicit(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('product-inheritance');
        $inherited = $this->material($tenant, 'BEANS', 'kilogram');
        $override = $this->material($tenant, 'MILK', 'liter');
        $headers = $this->headers($tenant);

        $this->getJson("/api/v1/admin/catalog/products/$product/recipe", $headers)->assertOk()
            ->assertJsonPath('data.configured', false)->assertJsonCount(0, 'data.components');
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [[
            'materialId' => $inherited, 'quantity' => '18', 'unitCode' => 'g', 'sortOrder' => 2,
        ]]], $headers)->assertOk();
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $headers)->assertOk()
            ->assertJsonPath('data.hasOverride', false)->assertJsonPath('data.source', 'product')
            ->assertJsonCount(0, 'data.components')->assertJsonCount(0, 'data.overrideComponents')
            ->assertJsonPath('data.effectiveComponents.0.materialId', $inherited);

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [[
            'materialId' => $override, 'quantity' => '250', 'unitCode' => 'ml', 'sortOrder' => 1,
        ]]], $headers)->assertOk()
            ->assertJsonPath('data.hasOverride', true)->assertJsonPath('data.source', 'variant')
            ->assertJsonPath('data.components.0.materialId', $override)
            ->assertJsonPath('data.effectiveComponents.0.materialId', $override);
    }

    public function test_resolve_uses_inherited_base_before_modifier_effects_and_variant_summary_is_effective(): void
    {
        [$tenant, $product, $variant, , $option] = $this->recipeContext('inherited-resolve');
        $base = $this->material($tenant, 'BEANS', 'kilogram');
        $addition = $this->material($tenant, 'MILK', 'liter');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [[
            'materialId' => $base, 'quantity' => '18', 'unitCode' => 'g',
        ]]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", ['components' => [[
            'materialId' => $addition, 'operation' => 'add', 'quantity' => '10', 'unitCode' => 'ml',
        ]]], $headers)->assertOk();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => [['optionId' => $option]]], $headers)
            ->assertOk()->assertJsonCount(2, 'data.components');

        $summary = $this->getJson("/api/v1/admin/catalog/products/$product", $headers)->assertOk()->json('data.variants.0');
        $this->assertTrue($summary['effectiveRecipeConfigured']);
        $this->assertSame(1, $summary['effectiveRecipeComponentCount']);
        $this->assertSame('product', $summary['recipeSource']);
        $this->assertFalse($summary['hasRecipeOverride']);
        $this->assertTrue($summary['recipeConfigured']);
    }

    public function test_batch_effective_recipe_resolution_does_not_grow_recipe_queries_per_variant(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('batch-effective-recipes');
        $second = DB::table('product_variants')->insertGetId([
            'tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Large', 'base_price' => 5,
            'is_default' => false, 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [[
            'materialId' => $material, 'quantity' => '18', 'unitCode' => 'g',
        ]]], $this->headers($tenant))->assertOk();

        DB::enableQueryLog();
        app(RecipeConfigurationService::class)->effectiveRecipes(ProductVariant::query()->whereIn('id', [$variant, $second])->get());
        $queries = DB::getQueryLog();
        DB::disableQueryLog();

        $recipeQueries = collect($queries)->filter(fn (array $query) => str_contains($query['query'], 'recipe'))->count();
        $this->assertLessThanOrEqual(4, $recipeQueries);
    }

    public function test_product_clear_and_delete_are_idempotent_and_do_not_touch_variant_overrides(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('product-clear');
        $base = $this->material($tenant, 'BEANS', 'kilogram');
        $override = $this->material($tenant, 'MILK', 'liter');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [['materialId' => $base, 'quantity' => '18', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $override, 'quantity' => '100', 'unitCode' => 'ml']]], $headers)->assertOk();
        $before = DB::table('variant_recipe_components')->where('tenant_id', $tenant)->get()->map(fn ($row) => (array) $row)->all();
        $auditCount = DB::table('menu_audit_logs')->where('tenant_id', $tenant)->where('entity_id', $product)->count();

        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => []], $headers)
            ->assertOk()->assertJsonPath('data.configured', false)->assertJsonCount(0, 'data.components');
        $this->deleteJson("/api/v1/admin/catalog/products/$product/recipe", [], $headers)
            ->assertOk()->assertJsonPath('data.configured', false);

        $this->assertDatabaseMissing('product_recipes', ['tenant_id' => $tenant, 'product_id' => $product]);
        $this->assertSame($before, DB::table('variant_recipe_components')->where('tenant_id', $tenant)->get()->map(fn ($row) => (array) $row)->all());
        $this->assertSame($auditCount + 1, DB::table('menu_audit_logs')->where('tenant_id', $tenant)->where('entity_id', $product)->count());
    }

    public function test_variant_clear_and_delete_return_inheritance_and_are_idempotent(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('variant-clear');
        $base = $this->material($tenant, 'BEANS', 'kilogram');
        $override = $this->material($tenant, 'MILK', 'liter');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [['materialId' => $base, 'quantity' => '18', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $override, 'quantity' => '100', 'unitCode' => 'ml']]], $headers)->assertOk();

        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => []], $headers)
            ->assertOk()->assertJsonPath('data.hasOverride', false)->assertJsonPath('data.source', 'product')
            ->assertJsonPath('data.effectiveComponents.0.materialId', $base);
        $this->deleteJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [], $headers)
            ->assertOk()->assertJsonPath('data.hasOverride', false)->assertJsonPath('data.source', 'product');
        $this->assertDatabaseMissing('variant_recipes', ['tenant_id' => $tenant, 'product_variant_id' => $variant]);
    }

    public function test_recipe_writes_are_atomic_and_archived_records_are_read_only_but_diagnosable(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('recipe-lifecycle');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);
        $payload = ['components' => [['materialId' => $material, 'quantity' => '18', 'unitCode' => 'g']]];
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $payload, $headers)->assertOk();
        $before = DB::table('variant_recipe_components')->where('tenant_id', $tenant)->get()->map(fn ($row) => (array) $row)->all();
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $material, 'quantity' => '0', 'unitCode' => 'g']]], $headers)->assertUnprocessable();
        $this->assertSame($before, DB::table('variant_recipe_components')->where('tenant_id', $tenant)->get()->map(fn ($row) => (array) $row)->all());

        DB::table('product_variants')->where('id', $variant)->update(['deleted_at' => now()]);
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe?includeArchived=true", $headers)->assertOk();
        $this->deleteJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [], $headers)->assertNotFound();
        $this->assertSame($before, DB::table('variant_recipe_components')->where('tenant_id', $tenant)->get()->map(fn ($row) => (array) $row)->all());
        $this->assertNotSame($product, 0);
    }

    public function test_recipe_replace_rejects_invalid_components_and_preserves_the_previous_complete_recipe(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('invalid-components');
        $good = $this->material($tenant, 'BEANS', 'kilogram');
        $foreignTenant = $this->tenant('invalid-components-foreign');
        $foreignMaterial = $this->material($foreignTenant, 'FOREIGN', 'kilogram');
        $inactiveMaterial = $this->material($tenant, 'INACTIVE', 'kilogram');
        DB::table('inventory_items')->where('id', $inactiveMaterial)->update(['is_active' => false]);
        $archivedMaterial = $this->material($tenant, 'ARCHIVED', 'kilogram');
        DB::table('inventory_items')->where('id', $archivedMaterial)->update(['deleted_at' => now()]);
        $ineligibleMaterial = $this->rawMaterial($tenant, 'SERVICE', 'gram', 'service');
        $headers = $this->headers($tenant);

        $baseline = ['components' => [['materialId' => $good, 'quantity' => '18', 'unitCode' => 'g', 'sortOrder' => 0]]];
        foreach (['products/'.$product, 'product-variants/'.$variant] as $path) {
            $this->putJson("/api/v1/admin/catalog/$path/recipe", $baseline, $headers)->assertOk();
            $before = $path === 'products/'.$product ? $this->getJson("/api/v1/admin/catalog/$path/recipe", $headers)->json('data') : $this->getJson("/api/v1/admin/catalog/$path/recipe", $headers)->json('data');

            $invalidPayloads = [
                'foreign material' => ['components' => [['materialId' => $foreignMaterial, 'quantity' => '1', 'unitCode' => 'g']]],
                'inactive material' => ['components' => [['materialId' => $inactiveMaterial, 'quantity' => '1', 'unitCode' => 'g']]],
                'archived material' => ['components' => [['materialId' => $archivedMaterial, 'quantity' => '1', 'unitCode' => 'g']]],
                'ineligible item type' => ['components' => [['materialId' => $ineligibleMaterial, 'quantity' => '1', 'unitCode' => 'g']]],
                'duplicate material' => ['components' => [['materialId' => $good, 'quantity' => '1', 'unitCode' => 'g'], ['materialId' => $good, 'quantity' => '2', 'unitCode' => 'g']]],
                'zero quantity' => ['components' => [['materialId' => $good, 'quantity' => '0', 'unitCode' => 'g']]],
                'negative quantity' => ['components' => [['materialId' => $good, 'quantity' => '-1', 'unitCode' => 'g']]],
                'too many decimal places' => ['components' => [['materialId' => $good, 'quantity' => '1.1234567', 'unitCode' => 'g']]],
                'unknown unit' => ['components' => [['materialId' => $good, 'quantity' => '1', 'unitCode' => 'not-a-unit']]],
            ];

            foreach ($invalidPayloads as $case => $payload) {
                $this->putJson("/api/v1/admin/catalog/$path/recipe", $payload, $headers)->assertUnprocessable();
                $after = $this->getJson("/api/v1/admin/catalog/$path/recipe", $headers)->json('data');
                $this->assertSame($before, $after, "Recipe changed after a rejected write: $case ($path)");
            }
        }
    }

    public function test_recipe_routes_enforce_tenant_isolation_and_catalog_management_authorization(): void
    {
        [$tenant, $product, $variant, , $option] = $this->recipeContext('authz-matrix');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [['materialId' => $material, 'quantity' => '18', 'unitCode' => 'g']]], $headers)->assertOk();

        $foreignTenant = $this->tenant('authz-matrix-foreign');
        $foreignHeaders = $this->headers($foreignTenant);
        $foreignMaterialPayload = ['components' => [['materialId' => $material, 'quantity' => '1', 'unitCode' => 'g']]];

        // A different tenant must never see, mutate, or resolve this
        // tenant's product/variant recipes, and must never learn whether the
        // nested material id belongs to someone else.
        $this->getJson("/api/v1/admin/catalog/products/$product/recipe", $foreignHeaders)->assertNotFound();
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", $foreignMaterialPayload, $foreignHeaders)->assertNotFound();
        $this->deleteJson("/api/v1/admin/catalog/products/$product/recipe", [], $foreignHeaders)->assertNotFound();
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $foreignHeaders)->assertNotFound();
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $foreignMaterialPayload, $foreignHeaders)->assertNotFound();
        $this->deleteJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [], $foreignHeaders)->assertNotFound();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => []], $foreignHeaders)->assertNotFound();

        // The product recipe must still be intact for the owning tenant.
        $this->getJson("/api/v1/admin/catalog/products/$product/recipe", $headers)->assertOk()->assertJsonPath('data.configured', true);

        // An authenticated actor without Catalog recipe authority (an
        // employee, not owner/manager) must be denied on every recipe route,
        // not silently scoped down by the Flutter client.
        $employee = \App\Models\User::query()->create([
            'tenant_id' => $tenant,
            'name' => 'Line Cook',
            'email' => 'line-cook-authz-matrix@example.test',
            'password' => 'testing-password',
            'role' => 'employee',
            'is_active' => true,
            'must_change_password' => false,
        ]);
        $employeeHeaders = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $employee)];

        $this->getJson("/api/v1/admin/catalog/products/$product/recipe", $employeeHeaders)->assertForbidden();
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", $foreignMaterialPayload, $employeeHeaders)->assertForbidden();
        $this->deleteJson("/api/v1/admin/catalog/products/$product/recipe", [], $employeeHeaders)->assertForbidden();
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $employeeHeaders)->assertForbidden();
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $foreignMaterialPayload, $employeeHeaders)->assertForbidden();
        $this->deleteJson("/api/v1/admin/catalog/product-variants/$variant/recipe", [], $employeeHeaders)->assertForbidden();
        $this->postJson("/api/v1/admin/catalog/product-variants/$variant/recipe/resolve", ['selectedOptions' => []], $employeeHeaders)->assertForbidden();
        $this->getJson("/api/v1/admin/catalog/modifier-options/$option/recipe-adjustments", $employeeHeaders)->assertForbidden();

        $this->getJson("/api/v1/admin/catalog/products/$product/recipe", $headers)->assertOk()->assertJsonPath('data.configured', true);
    }

    public function test_stored_unavailable_material_remains_diagnosable_but_cannot_be_resaved_until_replaced(): void
    {
        [$tenant, $product, $variant] = $this->recipeContext('diagnose-unavailable');
        $material = $this->material($tenant, 'BEANS', 'kilogram');
        $headers = $this->headers($tenant);
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [['materialId' => $material, 'quantity' => '18', 'unitCode' => 'g']]], $headers)->assertOk();
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $material, 'quantity' => '9', 'unitCode' => 'g']]], $headers)->assertOk();

        DB::table('inventory_items')->where('id', $material)->update(['is_active' => false]);

        // The stored reference is still readable so a manager can diagnose
        // why the recipe became invalid, for both the product base recipe
        // and the variant override.
        $this->getJson("/api/v1/admin/catalog/products/$product/recipe", $headers)->assertOk()
            ->assertJsonPath('data.configured', true)
            ->assertJsonPath('data.components.0.materialId', $material);
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $headers)->assertOk()
            ->assertJsonPath('data.hasOverride', true)
            ->assertJsonPath('data.components.0.materialId', $material);

        // Resubmitting the very same stored component as new configuration
        // must still be rejected until it is replaced with an eligible one.
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [['materialId' => $material, 'quantity' => '18', 'unitCode' => 'g']]], $headers)->assertUnprocessable();
        $this->putJson("/api/v1/admin/catalog/product-variants/$variant/recipe", ['components' => [['materialId' => $material, 'quantity' => '9', 'unitCode' => 'g']]], $headers)->assertUnprocessable();

        // Prior stored state must remain untouched by the rejected resave.
        $this->getJson("/api/v1/admin/catalog/products/$product/recipe", $headers)->assertOk()->assertJsonPath('data.components.0.materialId', $material);
        $this->getJson("/api/v1/admin/catalog/product-variants/$variant/recipe", $headers)->assertOk()->assertJsonPath('data.components.0.materialId', $material);

        $replacement = $this->material($tenant, 'REPLACEMENT', 'kilogram');
        $this->putJson("/api/v1/admin/catalog/products/$product/recipe", ['components' => [['materialId' => $replacement, 'quantity' => '18', 'unitCode' => 'g']]], $headers)
            ->assertOk()->assertJsonPath('data.components.0.materialId', $replacement);
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

    private function material(int $tenant, string $sku, string $unit, string $itemType = 'other'): int
    {
        $inventoryUnit = match ($unit) {
            'kilogram' => 'gram',
            'liter' => 'milliliter',
            default => $unit,
        };
        $id = $this->rawMaterial($tenant, $sku, $inventoryUnit, $itemType);

        if ($unit === 'kilogram') {
            $this->conversion($tenant, $id, 'kilogram', 'gram', '1000.000000');
        }
        if ($unit === 'liter') {
            $this->conversion($tenant, $id, 'liter', 'milliliter', '1000.000000');
        }

        return $id;
    }

    private function rawMaterial(int $tenant, string $sku, string $unit, string $itemType = 'other'): int
    {
        return DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => $sku, 'sku' => $sku, 'item_type' => $itemType, 'unit' => $unit, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function conversion(int $tenant, int $material, string $source, string $target, string $factor, bool $active = true): void
    {
        DB::table('inventory_item_unit_conversions')->insert([
            'tenant_id' => $tenant,
            'inventory_item_id' => $material,
            'source_unit' => $source,
            'target_unit' => $target,
            'factor' => $factor,
            'is_active' => $active,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
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
