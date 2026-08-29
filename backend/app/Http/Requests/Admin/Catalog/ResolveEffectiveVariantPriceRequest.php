<?php

namespace App\Http\Requests\Admin\Catalog;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ResolveEffectiveVariantPriceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'branchId' => ['nullable', 'integer'],
            'channel' => ['nullable', Rule::enum(SalesChannel::class)],
        ];
    }
}
