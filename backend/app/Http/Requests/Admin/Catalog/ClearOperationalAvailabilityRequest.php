<?php

namespace App\Http\Requests\Admin\Catalog;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ClearOperationalAvailabilityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tenantId' => ['prohibited'], 'productId' => ['prohibited'], 'productVariantId' => ['prohibited'], 'updatedBy' => ['prohibited'],
            'branchId' => ['required', 'integer'],
            'channel' => ['required', 'string', Rule::in([...array_map(fn (SalesChannel $channel) => $channel->value, SalesChannel::cases()), 'all'])],
        ];
    }
}
