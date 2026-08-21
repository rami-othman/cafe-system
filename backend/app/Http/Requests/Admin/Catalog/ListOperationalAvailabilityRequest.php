<?php

namespace App\Http\Requests\Admin\Catalog;

use App\Domain\Menu\Enums\OperationalAvailabilityStatus;
use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ListOperationalAvailabilityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'search' => ['nullable', 'string', 'max:255'], 'branchId' => ['nullable', 'integer'],
            'channel' => ['nullable', 'string', Rule::in([...array_map(fn (SalesChannel $channel) => $channel->value, SalesChannel::cases()), 'all'])],
            'status' => ['nullable', Rule::enum(OperationalAvailabilityStatus::class)],
            'level' => ['nullable', Rule::in(['product', 'variant', 'all'])],
            // Query parameters arrive as strings. Accept standard HTTP boolean
            // spellings as well as the numeric forms Laravel accepts natively.
            'includeArchived' => ['nullable', Rule::in(['true', 'false', '1', '0', true, false, 1, 0])], 'page' => ['nullable', 'integer', 'min:1'], 'perPage' => ['nullable', 'integer', 'between:1,100'],
        ];
    }
}
