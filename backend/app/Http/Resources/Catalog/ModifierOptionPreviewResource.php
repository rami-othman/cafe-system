<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ModifierOptionPreviewResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'nameAr' => $this->name_ar,
            'nameEn' => $this->name_en,
            'priceDelta' => (float) $this->price_delta,
        ];
    }
}
