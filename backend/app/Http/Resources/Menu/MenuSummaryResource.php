<?php

namespace App\Http\Resources\Menu;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MenuSummaryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'description' => $this->description, 'coverImageUrl' => $this->cover_image_url, 'status' => $this->status instanceof \BackedEnum ? $this->status->value : $this->status, 'priority' => $this->priority, 'sectionCount' => $this->sections_count ?? 0, 'visibleProductCount' => $this->visible_placements_count ?? 0, 'assignmentCount' => $this->assignments_count ?? 0, 'scheduleRuleCount' => $this->availability_rules_count ?? 0, 'archivedAt' => $this->deleted_at, 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
