<?php

namespace App\Services\Catalog;

use App\Models\Product;
use App\Models\ProductVariant;
use Illuminate\Validation\ValidationException;

class LegacyProductVariantCompatibilityService
{
    public function sync(Product $product): void
    {
        $variant = $product->variants()->where('is_default', true)->where('is_active', true)->first();
        if (! $variant instanceof ProductVariant) {
            throw ValidationException::withMessages(['variants' => 'An active default variant is required.']);
        }

        $product->forceFill(['price' => $variant->base_price, 'cost_price' => $variant->cost_price, 'sku' => $variant->sku, 'barcode' => $variant->barcode])->save();
    }
}
