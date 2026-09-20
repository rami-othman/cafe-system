<?php

use Illuminate\Support\Facades\DB;

/**
 * Forward-only reconciliation for the optional product recipe migration.
 *
 * Recovery is roll-forward only: correct inconsistent tenant/default data, then
 * rerun this helper safely. It never mutates published, order, inventory,
 * payment, finance, or legacy recipe tables.
 */
final class ProductRecipeBackfill
{
    /** @return array<string, int> */
    public static function run(): array
    {
        $counts = [
            'productsExamined' => 0,
            'unambiguousDefaults' => 0,
            'copiedProductRecipes' => 0,
            'retainedNonEmptyOverrides' => 0,
            'removedEmptyVariantParents' => 0,
            'ambiguousOrMissingDefaults' => 0,
            'rejectedInconsistencies' => 0,
            'partialProductRecipesSkipped' => 0,
        ];

        DB::transaction(function () use (&$counts): void {
            $products = DB::table('products')->select('id', 'tenant_id')->orderBy('tenant_id')->orderBy('id')->lockForUpdate()->get();
            foreach ($products as $product) {
                ++$counts['productsExamined'];
                $variants = DB::table('product_variants')
                    ->where('tenant_id', $product->tenant_id)
                    ->where('product_id', $product->id)
                    ->orderBy('id')
                    ->lockForUpdate()
                    ->get();

                $inconsistent = false;
                $existingProductRecipes = DB::table('product_recipes')
                    ->where('product_id', $product->id)
                    ->lockForUpdate()
                    ->get();
                if ($existingProductRecipes->contains(fn ($recipe) => (int) $recipe->tenant_id !== (int) $product->tenant_id)) {
                    $inconsistent = true;
                }

                if ($variants->contains(fn ($variant) => (int) $variant->tenant_id !== (int) $product->tenant_id)) {
                    $inconsistent = true;
                }

                foreach ($variants as $variant) {
                    $variantRecipes = DB::table('variant_recipes')
                        ->where('product_variant_id', $variant->id)
                        ->lockForUpdate()
                        ->get();
                    foreach ($variantRecipes as $recipe) {
                        if ((int) $recipe->tenant_id !== (int) $product->tenant_id) {
                            $inconsistent = true;
                            continue;
                        }
                        $components = DB::table('variant_recipe_components')
                            ->where('variant_recipe_id', $recipe->id)
                            ->orderBy('sort_order')
                            ->orderBy('id')
                            ->get();
                        foreach ($components as $component) {
                            $material = DB::table('inventory_items')
                                ->where('id', $component->inventory_item_id)
                                ->first();
                            if ((int) $component->tenant_id !== (int) $product->tenant_id
                                || ! $material
                                || (int) $material->tenant_id !== (int) $product->tenant_id) {
                                $inconsistent = true;
                            }
                        }
                    }
                }

                if ($inconsistent) {
                    ++$counts['rejectedInconsistencies'];
                    continue;
                }

                foreach ($variants as $variant) {
                    if (DB::table('variant_recipes')->where('product_variant_id', $variant->id)->where('tenant_id', '!=', $product->tenant_id)->exists()) {
                        ++$counts['rejectedInconsistencies'];
                        continue 2;
                    }
                    $recipe = DB::table('variant_recipes')
                        ->where('tenant_id', $product->tenant_id)
                        ->where('product_variant_id', $variant->id)
                        ->lockForUpdate()
                        ->first();
                    if ($recipe === null) {
                        continue;
                    }
                    $componentCount = DB::table('variant_recipe_components')->where('variant_recipe_id', $recipe->id)->count();
                    if ($componentCount === 0) {
                        DB::table('variant_recipes')->where('id', $recipe->id)->delete();
                        ++$counts['removedEmptyVariantParents'];
                    } else {
                        ++$counts['retainedNonEmptyOverrides'];
                    }
                }

                $defaults = $variants->filter(fn ($variant) => (bool) $variant->is_default)->values();
                if ($defaults->count() !== 1) {
                    ++$counts['ambiguousOrMissingDefaults'];
                    continue;
                }
                ++$counts['unambiguousDefaults'];
                $default = $defaults->first();
                $source = DB::table('variant_recipes')
                    ->where('tenant_id', $product->tenant_id)
                    ->where('product_variant_id', $default->id)
                    ->lockForUpdate()
                    ->first();
                if ($source === null) {
                    continue;
                }
                $components = DB::table('variant_recipe_components')
                    ->where('variant_recipe_id', $source->id)
                    ->orderBy('sort_order')
                    ->orderBy('id')
                    ->get();
                if ($components->isEmpty()) {
                    continue;
                }
                if ($components->contains(fn ($component) => (int) $component->tenant_id !== (int) $product->tenant_id)) {
                    ++$counts['rejectedInconsistencies'];
                    continue;
                }

                $existing = DB::table('product_recipes')
                    ->where('tenant_id', $product->tenant_id)
                    ->where('product_id', $product->id)
                    ->lockForUpdate()
                    ->first();
                if ($existing === null) {
                    $now = now();
                    $productRecipeId = DB::table('product_recipes')->insertGetId([
                        'tenant_id' => $product->tenant_id,
                        'product_id' => $product->id,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                    foreach ($components as $component) {
                        DB::table('product_recipe_components')->insert([
                            'tenant_id' => $product->tenant_id,
                            'product_recipe_id' => $productRecipeId,
                            'inventory_item_id' => $component->inventory_item_id,
                            'quantity' => $component->quantity,
                            'unit_code' => $component->unit_code,
                            'sort_order' => $component->sort_order,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);
                    }
                    ++$counts['copiedProductRecipes'];
                    continue;
                }

                $existingComponents = DB::table('product_recipe_components')
                    ->where('product_recipe_id', $existing->id)
                    ->orderBy('sort_order')
                    ->orderBy('id')
                    ->get();
                if (self::fingerprints($existingComponents) !== self::fingerprints($components)) {
                    ++$counts['partialProductRecipesSkipped'];
                }
            }
        });

        return $counts;
    }

    /** @param iterable<object> $components */
    private static function fingerprints(iterable $components): array
    {
        return collect($components)
            ->map(fn (object $component): string => implode('|', [
                (int) $component->inventory_item_id,
                (string) $component->quantity,
                (string) $component->unit_code,
                (int) $component->sort_order,
            ]))
            ->values()
            ->all();
    }
}
