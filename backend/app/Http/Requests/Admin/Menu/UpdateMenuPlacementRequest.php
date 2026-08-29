<?php

namespace App\Http\Requests\Admin\Menu;

class UpdateMenuPlacementRequest extends MenuRequest
{
    public function rules(): array
    {
        return $this->placementRules();
    }
}
