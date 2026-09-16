<?php

namespace App\Http\Resources\Customer;

use Illuminate\Http\Resources\Json\JsonResource;

class CustomerGroupResource extends JsonResource
{
    public function toArray($request): array
    {
        return ['id' => (int) $this->id, 'name' => $this->name, 'status' => $this->lifecycleState(), 'isActive' => (bool) $this->is_active, 'memberCount' => isset($this->member_count) ? (int) $this->member_count : $this->customers()->count(), 'createdAt' => $this->created_at?->toISOString(), 'updatedAt' => $this->updated_at?->toISOString()];
    }
}
