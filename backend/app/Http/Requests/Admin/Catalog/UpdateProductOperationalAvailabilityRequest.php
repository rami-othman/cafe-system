<?php

namespace App\Http\Requests\Admin\Catalog;

use App\Domain\Menu\Enums\OperationalAvailabilityStatus;
use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProductOperationalAvailabilityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return $this->availabilityRules();
    }

    protected function availabilityRules(): array
    {
        return [
            'tenantId' => ['prohibited'], 'productId' => ['prohibited'], 'productVariantId' => ['prohibited'], 'updatedBy' => ['prohibited'],
            'branchId' => ['required', 'integer'],
            'channel' => ['required', 'string', Rule::in([...array_map(fn (SalesChannel $channel) => $channel->value, SalesChannel::cases()), 'all'])],
            'status' => ['required', Rule::enum(OperationalAvailabilityStatus::class)],
            'remainingQuantity' => ['nullable', 'numeric', 'min:0'],
            // Manager-entered temporary availability is a Branch-local wall
            // clock time. Offsets are rejected so it cannot become an
            // ambiguous mixture of device instants and local times.
            'unavailableUntil' => ['nullable', 'date_format:Y-m-d\\TH:i:s'],
            'reason' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            if ($this->input('status') === OperationalAvailabilityStatus::TemporarilyUnavailable->value && ! $this->input('unavailableUntil')) {
                $validator->errors()->add('unavailableUntil', 'A future unavailable-until time is required for temporarily unavailable status.');
            }
        });
    }
}
