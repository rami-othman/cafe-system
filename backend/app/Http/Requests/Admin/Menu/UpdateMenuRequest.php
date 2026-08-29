<?php

namespace App\Http\Requests\Admin\Menu;

class UpdateMenuRequest extends MenuRequest
{
    public function rules(): array
    {
        return $this->menuRules();
    }
}
