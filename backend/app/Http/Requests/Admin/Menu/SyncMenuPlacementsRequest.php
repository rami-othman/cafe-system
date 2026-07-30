<?php

namespace App\Http\Requests\Admin\Menu;

class SyncMenuPlacementsRequest extends MenuRequest
{
    public function rules(): array
    {
        return ['placements' => ['required', 'array'], 'placements.*.id' => ['nullable', 'integer'], 'placements.*.productId' => ['required', 'integer'], 'placements.*.sortOrder' => ['nullable', 'integer'], 'placements.*.isFeatured' => ['nullable', 'boolean'], 'placements.*.isVisible' => ['nullable', 'boolean'], 'placements.*.displayNameOverride' => ['nullable', 'string', 'max:255'], 'placements.*.displayDescriptionOverride' => ['nullable', 'string'], 'placements.*.displayImageOverride' => ['nullable', 'string', 'max:255']];
    }
}
