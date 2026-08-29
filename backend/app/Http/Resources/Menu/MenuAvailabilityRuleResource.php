<?php

namespace App\Http\Resources\Menu;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MenuAvailabilityRuleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'branchId' => $this->branch_id, 'channel' => $this->channel instanceof \BackedEnum ? $this->channel->value : $this->channel, 'dayOfWeek' => $this->day_of_week, 'startTime' => $this->start_time?->format('H:i'), 'endTime' => $this->end_time?->format('H:i'), 'startDate' => $this->start_date?->toDateString(), 'endDate' => $this->end_date?->toDateString(), 'priority' => $this->priority, 'isActive' => (bool) $this->is_active, 'createdAt' => $this->created_at, 'updatedAt' => $this->updated_at];
    }
}
