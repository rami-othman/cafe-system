<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EffectiveProductVariantPriceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return array_filter([
            'variantId' => $this['variantId'],
            'basePrice' => (float) $this['basePrice'],
            'effectivePrice' => (float) $this['effectivePrice'],
            'matchedScope' => $this['matchedScope'],
            'matchedOverrideId' => $this['matchedOverrideId'],
            'branchId' => $this['branchId'],
            'channel' => $this['channel'],
        ], fn ($value, $key) => ! in_array($key, ['branchId', 'channel'], true) || $value !== null, ARRAY_FILTER_USE_BOTH);
    }
}
