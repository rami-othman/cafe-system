<?php

namespace App\Http\Requests\Admin\Menu;

class MoveMenuPlacementRequest extends MenuRequest
{
    public function rules(): array
    {
        return ['targetSectionId' => ['required', 'integer'], 'sortOrder' => ['nullable', 'integer']];
    }
}
