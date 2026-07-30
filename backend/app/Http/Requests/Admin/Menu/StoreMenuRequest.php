<?php

namespace App\Http\Requests\Admin\Menu;

class StoreMenuRequest extends MenuRequest
{
    public function rules(): array
    {
        return $this->menuRules(true);
    }
}
