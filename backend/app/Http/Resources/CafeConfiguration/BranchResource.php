<?php

namespace App\Http\Resources\CafeConfiguration;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BranchResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'address' => $this->address,
            'phone' => $this->phone,
            'timezone' => $this->timezone,
            'currency' => $this->currency,
            'isActive' => $this->is_active,
            'posInventoryWarehouseId' => $this->pos_inventory_warehouse_id,
            'posInventoryWarehouse' => $this->whenLoaded('posInventoryWarehouse', fn () => $this->posInventoryWarehouse ? [
                'id' => $this->posInventoryWarehouse->id,
                'name' => $this->posInventoryWarehouse->name,
            ] : null),
            'availablePosWarehouses' => $this->whenLoaded('warehouses', fn () => $this->warehouses->map(fn ($warehouse) => [
                'id' => $warehouse->id,
                'name' => $warehouse->name,
            ])->values()),
            'createdAt' => $this->created_at?->toISOString(),
            'updatedAt' => $this->updated_at?->toISOString(),
        ];
    }
}
