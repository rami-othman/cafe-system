<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ModifierGroupResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $previewLoaded = $this->relationLoaded('optionPreview');
        $previewCount = $previewLoaded ? $this->optionPreview->count() : 0;

        return ['id' => $this->id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'code' => $this->code, 'groupType' => $this->group_type instanceof \BackedEnum ? $this->group_type->value : $this->group_type, 'selectionType' => $this->selection_type, 'isRequired' => (bool) $this->is_required, 'minSelections' => $this->min_selections, 'maxSelections' => $this->max_selections, 'allowQuantity' => (bool) $this->allow_quantity, 'sortOrder' => $this->sort_order, 'isActive' => (bool) $this->is_active, 'optionCount' => $this->whenCounted('options'), 'activeOptionCount' => $this->when(isset($this->active_options_count), $this->active_options_count), 'optionPreview' => ModifierOptionPreviewResource::collection($this->whenLoaded('optionPreview')), 'remainingOptionCount' => $this->when($previewLoaded && isset($this->options_count), max(0, (int) $this->options_count - $previewCount)), 'options' => ModifierOptionResource::collection($this->whenLoaded('options')), 'materialImpactConfigured' => $this->when(isset($this->material_impact_configured), (bool) $this->material_impact_configured), 'archivedAt' => $this->deleted_at, 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
