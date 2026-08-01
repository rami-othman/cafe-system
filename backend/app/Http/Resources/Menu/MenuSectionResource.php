<?php

namespace App\Http\Resources\Menu;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MenuSectionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'menuId' => $this->menu_id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'description' => $this->description, 'imageUrl' => $this->image_url, 'sortOrder' => $this->sort_order, 'isActive' => (bool) $this->is_active, 'placementCount' => $this->placements_count ?? 0, 'archivedAt' => $this->deleted_at, 'placements' => MenuItemPlacementResource::collection($this->whenLoaded('placements')), 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
