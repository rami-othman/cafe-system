<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ModifierOptionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'modifierGroupId' => $this->modifier_group_id, 'name' => $this->name, 'nameAr' => $this->name_ar, 'nameEn' => $this->name_en, 'priceDelta' => (float) $this->price_delta, 'costDelta' => (float) $this->cost_delta, 'isDefault' => (bool) $this->is_default, 'isActive' => (bool) $this->is_active, 'isAvailable' => (bool) $this->is_available, 'sortOrder' => $this->sort_order, 'archivedAt' => $this->deleted_at, 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
