<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ModifierGroupResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'code' => $this->code, 'groupType' => $this->group_type instanceof \BackedEnum ? $this->group_type->value : $this->group_type, 'selectionType' => $this->selection_type, 'isRequired' => (bool) $this->is_required, 'minSelections' => $this->min_selections, 'maxSelections' => $this->max_selections, 'allowQuantity' => (bool) $this->allow_quantity, 'sortOrder' => $this->sort_order, 'isActive' => (bool) $this->is_active, 'optionCount' => $this->whenCounted('options'), 'options' => ModifierOptionResource::collection($this->whenLoaded('options')), 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
