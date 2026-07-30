<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ReportingCategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'code' => $this->code, 'description' => $this->description, 'sortOrder' => $this->sort_order, 'isActive' => (bool) $this->is_active, 'productCount' => $this->whenCounted('products'), 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
