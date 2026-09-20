<?php

namespace Tests\Feature\Admin\Catalog;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ProductRecipeBackfillTest extends TestCase
{
    use RefreshDatabase;

    public function test_representative_volume_reconciles_and_replays_without_drift(): void
    {
        $productCount = 500;
        $tenantCount = 5;
        $products = [];
        $materialsByTenant = [];

        for ($tenantIndex = 0; $tenantIndex < $tenantCount; ++$tenantIndex) {
            $slug = 'backfill-scale-'.$tenantIndex;
            $tenant = DB::table('tenants')->insertGetId([
                'name' => $slug,
                'slug' => $slug,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $category = DB::table('categories')->insertGetId([
                'tenant_id' => $tenant,
                'name' => $slug,
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $materialsByTenant[$tenant] = DB::table('inventory_items')->insertGetId([
                'tenant_id' => $tenant,
                'name' => 'SCALE-MATERIAL-'.$tenantIndex,
                'sku' => 'SCALE-MATERIAL-'.$tenantIndex,
                'item_type' => 'other',
                'unit' => 'gram',
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            for ($productIndex = 0; $productIndex < intdiv($productCount, $tenantCount); ++$productIndex) {
                $products[] = [
                    'tenant_id' => $tenant,
                    'category_id' => $category,
                    'name' => $slug.'-product-'.$productIndex,
                    'price' => 1,
                    'is_active' => true,
                    'is_stock_tracked' => true,
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
            }
        }
        DB::table('products')->insert($products);

        $productRows = DB::table('products')
            ->where('name', 'like', 'backfill-scale-%-product-%')
            ->orderBy('id')
            ->get();
        $this->assertCount($productCount, $productRows);

        $variants = [];
        foreach ($productRows as $product) {
            $variants[] = [
                'tenant_id' => $product->tenant_id,
                'product_id' => $product->id,
                'name' => 'Scale Default',
                'base_price' => 1,
                'is_default' => true,
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ];
            $variants[] = [
                'tenant_id' => $product->tenant_id,
                'product_id' => $product->id,
                'name' => ((int) $product->id % 2 === 0) ? 'Scale Override' : 'Scale Empty',
                'base_price' => 1,
                'is_default' => false,
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }
        DB::table('product_variants')->insert($variants);

        $variantRows = DB::table('product_variants')
            ->whereIn('product_id', $productRows->pluck('id')->all())
            ->orderBy('product_id')
            ->orderBy('id')
            ->get();
        $this->assertCount($productCount * 2, $variantRows);

        $variantRecipes = $variantRows->map(fn ($variant): array => [
            'tenant_id' => $variant->tenant_id,
            'product_variant_id' => $variant->id,
            'created_at' => now(),
            'updated_at' => now(),
        ])->all();
        DB::table('variant_recipes')->insert($variantRecipes);

        $recipeRows = DB::table('variant_recipes')
            ->whereIn('product_variant_id', $variantRows->pluck('id')->all())
            ->get();
        $components = [];
        foreach ($recipeRows as $recipe) {
            $variant = $variantRows->firstWhere('id', $recipe->product_variant_id);
            if ($variant->name === 'Scale Empty') {
                continue;
            }
            $components[] = [
                'tenant_id' => $recipe->tenant_id,
                'variant_recipe_id' => $recipe->id,
                'inventory_item_id' => $materialsByTenant[$recipe->tenant_id],
                'quantity' => '1.000000',
                'unit_code' => 'g',
                'sort_order' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }
        DB::table('variant_recipe_components')->insert($components);

        $expectedOverrides = intdiv($productCount, 2);
        $expectedNonEmptyParents = $productCount + $expectedOverrides;
        $first = \ProductRecipeBackfill::run();

        $this->assertSame($productCount, $first['productsExamined']);
        $this->assertSame($productCount, $first['unambiguousDefaults']);
        $this->assertSame($productCount, $first['copiedProductRecipes']);
        $this->assertSame($expectedNonEmptyParents, $first['retainedNonEmptyOverrides']);
        $this->assertSame($expectedOverrides, $first['removedEmptyVariantParents']);
        $this->assertSame(0, $first['ambiguousOrMissingDefaults']);
        $this->assertSame(0, $first['rejectedInconsistencies']);
        $this->assertSame(0, $first['partialProductRecipesSkipped']);
        $this->assertSame($productCount, DB::table('product_recipes')->count());
        $this->assertSame($productCount + $expectedOverrides, DB::table('variant_recipes')->count());

        $second = \ProductRecipeBackfill::run();

        $this->assertSame($productCount, $second['productsExamined']);
        $this->assertSame($productCount, $second['unambiguousDefaults']);
        $this->assertSame(0, $second['copiedProductRecipes']);
        $this->assertSame($expectedNonEmptyParents, $second['retainedNonEmptyOverrides']);
        $this->assertSame(0, $second['removedEmptyVariantParents']);
        $this->assertSame(0, $second['ambiguousOrMissingDefaults']);
        $this->assertSame(0, $second['rejectedInconsistencies']);
        $this->assertSame(0, $second['partialProductRecipesSkipped']);
        $this->assertSame($productCount, DB::table('product_recipes')->count());
        $this->assertSame($productCount + $expectedOverrides, DB::table('variant_recipes')->count());
    }

    public function test_unambiguous_default_is_copied_in_order_and_all_non_empty_variants_remain_overrides(): void
    {
        [$tenant, $product, $default, $other] = $this->context('backfill-copy');
        $first = $this->material($tenant, 'BEANS');
        $second = $this->material($tenant, 'MILK');
        $this->recipe($tenant, $default, [[$second, '100.000000', 'ml', 2], [$first, '18.000000', 'g', 1]]);
        $this->recipe($tenant, $other, [[$second, '200.000000', 'ml', 1]]);
        $before = DB::table('variant_recipe_components')->orderBy('id')->get()->map(fn ($row) => (array) $row)->all();

        $counts = \ProductRecipeBackfill::run();

        $recipe = DB::table('product_recipes')->where(['tenant_id' => $tenant, 'product_id' => $product])->first();
        $this->assertNotNull($recipe);
        $this->assertSame([$first, $second], DB::table('product_recipe_components')->where('product_recipe_id', $recipe->id)->orderBy('sort_order')->pluck('inventory_item_id')->all());
        $this->assertSame($before, DB::table('variant_recipe_components')->orderBy('id')->get()->map(fn ($row) => (array) $row)->all());
        $this->assertSame(2, $counts['retainedNonEmptyOverrides']);
        $this->assertSame(1, $counts['copiedProductRecipes']);
    }

    public function test_empty_variant_parents_are_removed_and_replay_is_idempotent_without_guessing_defaults(): void
    {
        [$tenant, $product, $default] = $this->context('backfill-empty');
        $emptyRecipe = DB::table('variant_recipes')->insertGetId(['tenant_id' => $tenant, 'product_variant_id' => $default, 'created_at' => now(), 'updated_at' => now()]);
        $missingDefaultProduct = $this->product($tenant, 'missing-default');
        DB::table('product_variants')->insert(['tenant_id' => $tenant, 'product_id' => $missingDefaultProduct, 'name' => 'Only', 'base_price' => 1, 'is_default' => false, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        $first = \ProductRecipeBackfill::run();
        $second = \ProductRecipeBackfill::run();

        $this->assertDatabaseMissing('variant_recipes', ['id' => $emptyRecipe]);
        $this->assertDatabaseMissing('product_recipes', ['tenant_id' => $tenant, 'product_id' => $product]);
        $this->assertSame(1, $first['removedEmptyVariantParents']);
        $this->assertSame(1, $first['ambiguousOrMissingDefaults']);
        $this->assertSame(0, $second['removedEmptyVariantParents']);
        $this->assertSame(0, DB::table('product_recipes')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('product_recipe_components')->where('tenant_id', $tenant)->count());
    }

    public function test_backfill_only_changes_recipe_configuration_tables(): void
    {
        [$tenant, $product, $default] = $this->context('backfill-history');
        $material = $this->material($tenant, 'BEANS');
        $this->recipe($tenant, $default, [[$material, '18.000000', 'g', 1]]);
        $untouched = collect(['published_menu_versions', 'orders', 'payments', 'inventory_movements', 'journal_entries', 'recipes', 'recipe_lines'])
            ->filter(fn (string $table) => DB::getSchemaBuilder()->hasTable($table))
            ->mapWithKeys(fn (string $table) => [$table => DB::table($table)->orderBy('id')->get()->map(fn ($row) => (array) $row)->all()])
            ->all();

        \ProductRecipeBackfill::run();

        foreach ($untouched as $table => $rows) {
            $this->assertSame($rows, DB::table($table)->orderBy('id')->get()->map(fn ($row) => (array) $row)->all(), $table.' must remain immutable');
        }
        $this->assertDatabaseHas('product_recipes', ['tenant_id' => $tenant, 'product_id' => $product]);
    }

    public function test_missing_and_multiple_defaults_are_counted_without_guessing_or_copying(): void
    {
        [$tenant, $missingProduct] = $this->productWithVariants('backfill-missing', [
            ['name' => 'One', 'is_default' => false],
            ['name' => 'Two', 'is_default' => false],
        ]);
        [, $multipleProduct] = $this->productWithVariants('backfill-multiple', [
            ['name' => 'One', 'is_default' => true],
            ['name' => 'Two', 'is_default' => true],
        ]);

        $counts = \ProductRecipeBackfill::run();

        $this->assertSame(2, $counts['ambiguousOrMissingDefaults']);
        $this->assertDatabaseMissing('product_recipes', ['tenant_id' => $tenant, 'product_id' => $missingProduct]);
        $this->assertDatabaseMissing('product_recipes', ['product_id' => $multipleProduct]);
    }

    public function test_foreign_tenant_variant_recipe_and_component_are_rejected_and_preserved(): void
    {
        [$tenant, $product, $default] = $this->context('backfill-foreign-parent');
        $foreign = DB::table('tenants')->insertGetId(['name' => 'Foreign', 'slug' => 'backfill-foreign-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $foreignRecipe = DB::table('variant_recipes')->insertGetId(['tenant_id' => $foreign, 'product_variant_id' => $default, 'created_at' => now(), 'updated_at' => now()]);

        $parentCounts = \ProductRecipeBackfill::run();

        $this->assertSame(1, $parentCounts['rejectedInconsistencies']);
        $this->assertDatabaseHas('variant_recipes', ['id' => $foreignRecipe]);
        $this->assertDatabaseMissing('product_recipes', ['tenant_id' => $tenant, 'product_id' => $product]);

        [$tenant, $product, $default] = $this->context('backfill-foreign-component');
        $foreign = DB::table('tenants')->insertGetId(['name' => 'Foreign Component', 'slug' => 'backfill-foreign-component-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $material = $this->material($foreign, 'FOREIGN-MATERIAL');
        $recipe = DB::table('variant_recipes')->insertGetId(['tenant_id' => $tenant, 'product_variant_id' => $default, 'created_at' => now(), 'updated_at' => now()]);
        $component = DB::table('variant_recipe_components')->insertGetId(['tenant_id' => $foreign, 'variant_recipe_id' => $recipe, 'inventory_item_id' => $material, 'quantity' => '1.000000', 'unit_code' => 'g', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);

        $counts = \ProductRecipeBackfill::run();

        $this->assertSame(2, $counts['rejectedInconsistencies']);
        $this->assertDatabaseHas('variant_recipe_components', ['id' => $component]);
        $this->assertDatabaseMissing('product_recipes', ['tenant_id' => $tenant, 'product_id' => $product]);
    }

    public function test_existing_partial_product_parent_is_skipped_and_replay_counts_are_deterministic(): void
    {
        [$tenant, $product, $default] = $this->context('backfill-partial');
        $firstMaterial = $this->material($tenant, 'FIRST');
        $secondMaterial = $this->material($tenant, 'SECOND');
        $this->recipe($tenant, $default, [
            [$firstMaterial, '1.000000', 'g', 0],
            [$secondMaterial, '2.000000', 'g', 1],
        ]);
        $productRecipe = DB::table('product_recipes')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('product_recipe_components')->insert([
            'tenant_id' => $tenant, 'product_recipe_id' => $productRecipe, 'inventory_item_id' => $firstMaterial,
            'quantity' => '1.000000', 'unit_code' => 'g', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);

        $first = \ProductRecipeBackfill::run();
        $second = \ProductRecipeBackfill::run();

        $this->assertSame(1, $first['partialProductRecipesSkipped']);
        $this->assertSame($first['partialProductRecipesSkipped'], $second['partialProductRecipesSkipped']);
        $this->assertSame(1, DB::table('product_recipe_components')->where('product_recipe_id', $productRecipe)->count());
        $this->assertSame(0, $first['copiedProductRecipes']);
        $this->assertSame(0, $second['copiedProductRecipes']);
    }

    /** @return array{int, int, int, int} */
    private function context(string $slug): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
        $product = $this->product($tenant, $slug);
        $default = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Default', 'base_price' => 1, 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $other = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Other', 'base_price' => 1, 'is_default' => false, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return [$tenant, $product, $default, $other];
    }

    /** @param list<array{name: string, is_default: bool}> $variants */
    private function productWithVariants(string $slug, array $variants): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
        $product = $this->product($tenant, $slug);
        foreach ($variants as $variant) {
            DB::table('product_variants')->insert([
                'tenant_id' => $tenant, 'product_id' => $product, 'name' => $variant['name'],
                'base_price' => 1, 'is_default' => $variant['is_default'], 'is_active' => true,
                'created_at' => now(), 'updated_at' => now(),
            ]);
        }

        return [$tenant, $product];
    }

    private function product(int $tenant, string $slug): int
    {
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => $slug, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => $slug, 'price' => 1, 'is_active' => true, 'is_stock_tracked' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function material(int $tenant, string $sku): int
    {
        return DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => $sku, 'sku' => $sku, 'item_type' => 'other', 'unit' => 'gram', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    /** @param array<int, array{int, string, string, int}> $components */
    private function recipe(int $tenant, int $variant, array $components): void
    {
        $recipe = DB::table('variant_recipes')->insertGetId(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'created_at' => now(), 'updated_at' => now()]);
        foreach ($components as [$material, $quantity, $unit, $sortOrder]) {
            DB::table('variant_recipe_components')->insert(['tenant_id' => $tenant, 'variant_recipe_id' => $recipe, 'inventory_item_id' => $material, 'quantity' => $quantity, 'unit_code' => $unit, 'sort_order' => $sortOrder, 'created_at' => now(), 'updated_at' => now()]);
        }
    }
}
