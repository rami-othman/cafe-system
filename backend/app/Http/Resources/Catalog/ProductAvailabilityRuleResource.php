<?php

namespace App\Http\Resources\Catalog;

use DateTimeInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductAvailabilityRuleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'productVariantId' => $this->product_variant_id,
            'branchId' => $this->branch_id,
            'channel' => $this->channel instanceof \BackedEnum ? $this->channel->value : $this->channel,
            'dayOfWeek' => $this->day_of_week,
            'startTime' => $this->time($this->start_time),
            'endTime' => $this->time($this->end_time),
            'startDate' => $this->start_date?->toDateString(),
            'endDate' => $this->end_date?->toDateString(),
            'priority' => $this->priority,
            'isActive' => (bool) $this->is_active,
        ];
    }

    private function time(mixed $value): ?string
    {
        if ($value instanceof DateTimeInterface) {
            return $value->format('H:i');
        }

        return $value === null ? null : substr((string) $value, 0, 5);
    }
}
