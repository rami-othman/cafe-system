<?php

namespace App\Http\Requests\Admin\Menu;

class UpdateMenuSectionRequest extends MenuRequest
{
    public function rules(): array
    {
        return $this->sectionRules();
    }
}
