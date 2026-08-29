<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductSummaryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'description' => $this->description, 'imageUrl' => $this->image_url, 'productType' => $this->product_type instanceof \BackedEnum ? $this->product_type->value : $this->product_type, 'isActive' => (bool) $this->is_active, 'archivedAt' => $this->deleted_at, 'category' => new CatalogCategoryResource($this->whenLoaded('category')), 'reportingCategory' => new ReportingCategoryResource($this->whenLoaded('reportingCategory')), 'kitchenStation' => new KitchenStationResource($this->whenLoaded('kitchenStation')), 'defaultVariant' => new ProductVariantResource($this->whenLoaded('defaultVariant')), 'variantCount' => $this->whenCounted('variants'), 'modifierGroupCount' => $this->whenCounted('modifierGroups'), 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
