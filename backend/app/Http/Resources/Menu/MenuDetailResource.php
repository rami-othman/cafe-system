<?php

namespace App\Http\Resources\Menu;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MenuDetailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'description' => $this->description, 'descriptionAr' => $this->description_ar, 'descriptionEn' => $this->description_en, 'coverImageUrl' => $this->cover_image_url, 'status' => $this->status instanceof \BackedEnum ? $this->status->value : $this->status, 'priority' => $this->priority, 'sections' => MenuSectionResource::collection($this->whenLoaded('sections')), 'assignments' => MenuAssignmentResource::collection($this->whenLoaded('assignments')), 'availabilityRules' => MenuAvailabilityRuleResource::collection($this->whenLoaded('availabilityRules')), 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
