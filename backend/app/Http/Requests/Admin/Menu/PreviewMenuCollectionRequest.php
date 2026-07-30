<?php

namespace App\Http\Requests\Admin\Menu;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PreviewMenuCollectionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'branchId' => ['required', 'integer'], 'channel' => ['required', Rule::enum(SalesChannel::class)],
            'menuIds' => ['nullable', 'array'], 'menuIds.*' => ['integer', 'distinct'], 'at' => ['nullable', 'date'],
            'language' => ['nullable', Rule::in(['default', 'ar', 'en'])], 'includeUnavailable' => ['nullable', 'boolean'], 'includeHidden' => ['nullable', 'boolean'],
            'tenantId' => ['prohibited'], 'menuPublicationId' => ['prohibited'], 'publishedVersionId' => ['prohibited'],
        ];
    }
}
