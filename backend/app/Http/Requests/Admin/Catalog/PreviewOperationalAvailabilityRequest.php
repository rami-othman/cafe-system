<?php

namespace App\Http\Requests\Admin\Catalog;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PreviewOperationalAvailabilityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'productVariantId' => ['nullable', 'integer'], 'branchId' => ['required', 'integer'],
            'channel' => ['required', Rule::enum(SalesChannel::class)], 'at' => ['nullable', 'date'],
        ];
    }
}
