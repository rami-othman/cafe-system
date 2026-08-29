<?php

namespace App\Http\Requests\Admin\Catalog;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PreviewProductAvailabilityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'productVariantId' => ['nullable', 'integer'],
            'branchId' => ['nullable', 'integer'],
            'channel' => ['nullable', Rule::enum(SalesChannel::class)],
            'dateTime' => ['required', 'date'],
            'timezone' => ['nullable', 'timezone'],
        ];
    }
}
