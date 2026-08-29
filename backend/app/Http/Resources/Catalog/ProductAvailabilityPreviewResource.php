<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductAvailabilityPreviewResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return $this->resource;
    }
}
