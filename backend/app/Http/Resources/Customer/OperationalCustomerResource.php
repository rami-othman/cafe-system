<?php

namespace App\Http\Resources\Customer;

use Illuminate\Http\Resources\Json\JsonResource;

class OperationalCustomerResource extends JsonResource
{
    public function toArray($request): array
    {
        $totalSpent = (float) $this->total_spent;

        return [
            'id' => (int) $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email,
            'totalSpent' => $totalSpent,
            'visitsCount' => (int) $this->visits_count,
            'loyaltyPoints' => (int) round($totalSpent),
            'tier' => match (true) {
                $totalSpent >= 1000 => 'vip', $totalSpent >= 250 => 'regular', default => 'new'
            },
        ];
    }
}
