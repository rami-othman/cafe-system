<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductVariantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $recipeLoaded = $this->relationLoaded('recipe');
        $recipe = $recipeLoaded ? $this->recipe : null;
        $productRecipeLoaded = $this->relationLoaded('product') && $this->product?->relationLoaded('recipe');
        $productRecipe = $productRecipeLoaded ? $this->product->recipe : null;
        $hasOverride = $recipe !== null && (int) ($recipe->components_count ?? $recipe->components?->count() ?? 0) > 0;
        $productCount = (int) ($productRecipe?->components_count ?? $productRecipe?->components?->count() ?? 0);
        $effectiveCount = $hasOverride ? (int) ($recipe->components_count ?? $recipe->components?->count() ?? 0) : $productCount;
        $source = $hasOverride ? 'variant' : ($productCount > 0 ? 'product' : 'none');

        return ['id' => $this->id, 'productId' => $this->product_id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'sku' => $this->sku, 'barcode' => $this->barcode, 'basePrice' => (float) $this->base_price, 'costPrice' => (float) $this->cost_price, 'isDefault' => (bool) $this->is_default, 'isActive' => (bool) $this->is_active, 'sortOrder' => $this->sort_order, 'effectiveRecipeConfigured' => $this->when($recipeLoaded && $productRecipeLoaded, $effectiveCount > 0), 'effectiveRecipeComponentCount' => $this->when($recipeLoaded && $productRecipeLoaded, $effectiveCount), 'recipeSource' => $this->when($recipeLoaded && $productRecipeLoaded, $source), 'hasRecipeOverride' => $this->when($recipeLoaded, $hasOverride), 'recipeConfigured' => $this->when($recipeLoaded && $productRecipeLoaded, $effectiveCount > 0), 'recipeComponentCount' => $this->when($recipeLoaded && $productRecipeLoaded, $effectiveCount), 'archivedAt' => $this->deleted_at, 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
