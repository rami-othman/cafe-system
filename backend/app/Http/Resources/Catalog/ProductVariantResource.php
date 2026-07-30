<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductVariantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'sku' => $this->sku, 'barcode' => $this->barcode, 'basePrice' => (float) $this->base_price, 'costPrice' => (float) $this->cost_price, 'isDefault' => (bool) $this->is_default, 'isActive' => (bool) $this->is_active, 'sortOrder' => $this->sort_order, 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
