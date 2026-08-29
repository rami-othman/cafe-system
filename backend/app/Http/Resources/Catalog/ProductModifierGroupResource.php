<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;

class ProductModifierGroupResource extends ModifierGroupResource
{
    public function toArray(Request $request): array
    {
        return parent::toArray($request) + ['sortOrder' => $this->pivot?->sort_order, 'isRequiredOverride' => $this->pivot?->is_required_override, 'minSelectionsOverride' => $this->pivot?->min_selections_override, 'maxSelectionsOverride' => $this->pivot?->max_selections_override, 'allowQuantityOverride' => $this->pivot?->allow_quantity_override];
    }
}
