<?php

namespace App\Http\Requests\Admin\Menu;

class ReorderMenuPlacementsRequest extends MenuRequest
{
    public function rules(): array
    {
        return ['items' => ['required', 'array', 'min:1'], 'items.*.id' => ['required', 'integer'], 'items.*.sortOrder' => ['required', 'integer']];
    }
}
