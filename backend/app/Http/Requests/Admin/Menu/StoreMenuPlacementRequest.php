<?php

namespace App\Http\Requests\Admin\Menu;

class StoreMenuPlacementRequest extends MenuRequest
{
    public function rules(): array
    {
        return $this->placementRules(true);
    }
}
