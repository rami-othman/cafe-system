<?php

namespace App\Http\Resources\Customer;

use Illuminate\Http\Resources\Json\JsonResource;

class CustomerManagementResource extends JsonResource
{
    public function toArray($request): array
    {
        $phones = $this->relationLoaded('phones') ? $this->phones : collect();
        $groups = $this->relationLoaded('groups') ? $this->groups : collect();

        return [
            'id' => (int) $this->id,
            'customerNumber' => $this->customer_number,
            'name' => $this->name,
            'email' => $this->email,
            'birthDate' => $this->birth_date?->format('Y-m-d'),
            'notes' => $this->notes,
            'status' => $this->lifecycleState(),
            'isActive' => (bool) $this->is_active,
            'phones' => $phones->map(fn ($phone): array => ['id' => (int) $phone->id, 'rawNumber' => $phone->raw_number, 'normalizedNumber' => $phone->normalized_number, 'type' => $phone->type, 'isPrimary' => (bool) $phone->is_primary, 'validationStatus' => $phone->validation_status])->values()->all(),
            'groups' => $groups->map(fn ($group): array => ['id' => (int) $group->id, 'name' => $group->name, 'status' => $group->lifecycleState()])->values()->all(),
            'allowedActions' => $this->deleted_at !== null ? ['restore'] : ['update', 'deactivate', 'activate', 'archive'],
            'createdAt' => $this->created_at?->toISOString(),
            'updatedAt' => $this->updated_at?->toISOString(),
        ];
    }
}
