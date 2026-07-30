<?php

namespace App\Http\Resources\Menu;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MenuPreviewResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return $this->resource;
    }
}
