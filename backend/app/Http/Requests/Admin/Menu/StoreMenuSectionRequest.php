<?php

namespace App\Http\Requests\Admin\Menu;

class StoreMenuSectionRequest extends MenuRequest
{
    public function rules(): array
    {
        return $this->sectionRules(true);
    }
}
