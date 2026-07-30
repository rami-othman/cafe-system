<?php

namespace App\Http\Requests\Admin\Menu;

use App\Domain\Menu\Enums\MenuStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

abstract class MenuRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function menuRules(bool $create = false): array
    {
        return ['name' => [$create ? 'required' : 'sometimes', 'string', 'max:255'], 'nameAr' => ['nullable', 'string'], 'nameEn' => ['nullable', 'string'], 'description' => ['nullable', 'string'], 'descriptionAr' => ['nullable', 'string'], 'descriptionEn' => ['nullable', 'string'], 'coverImageUrl' => ['nullable', 'string', 'max:255'], 'status' => ['nullable', Rule::enum(MenuStatus::class)], 'priority' => ['nullable', 'integer']];
    }

    protected function sectionRules(bool $create = false): array
    {
        return ['name' => [$create ? 'required' : 'sometimes', 'string', 'max:255'], 'nameAr' => ['nullable', 'string'], 'nameEn' => ['nullable', 'string'], 'description' => ['nullable', 'string'], 'imageUrl' => ['nullable', 'string', 'max:255'], 'sortOrder' => ['nullable', 'integer'], 'isActive' => ['nullable', 'boolean']];
    }

    protected function placementRules(bool $create = false): array
    {
        return ($create ? ['productId' => ['required', 'integer']] : []) + ['displayNameOverride' => ['nullable', 'string', 'max:255'], 'displayDescriptionOverride' => ['nullable', 'string'], 'displayImageOverride' => ['nullable', 'string', 'max:255'], 'sortOrder' => ['nullable', 'integer'], 'isFeatured' => ['nullable', 'boolean'], 'isVisible' => ['nullable', 'boolean']];
    }
}
