<?php

namespace App\Http\Resources\Menu;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductMenuUsageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['productId' => $this->resource['productId'], 'activePlacementCount' => $this->resource['activePlacementCount'], 'menus' => $this->resource['menus']];
    }
}
