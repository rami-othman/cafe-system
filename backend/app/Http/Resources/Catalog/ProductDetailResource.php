<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;

class ProductDetailResource extends ProductSummaryResource
{
    public function toArray(Request $request): array
    {
        return parent::toArray($request) + ['descriptionAr' => $this->description_ar, 'descriptionEn' => $this->description_en, 'preparationTimeMinutes' => $this->preparation_time_minutes, 'isStockTracked' => (bool) $this->is_stock_tracked, 'sortOrder' => $this->sort_order, 'variants' => ProductVariantResource::collection($this->whenLoaded('variants')), 'modifierGroups' => ProductModifierGroupResource::collection($this->whenLoaded('modifierGroups'))];
    }
}
