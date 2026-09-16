<?php

namespace App\Http\Resources\CafeConfiguration;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BranchResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $effective = $this->effectivePosWarehouse();

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
                'type' => $this->posInventoryWarehouse->type,
            ] : null),
            'effectivePosInventoryWarehouseId' => $effective['warehouse']?->id,
            'effectivePosInventoryWarehouse' => $effective['warehouse'] ? [
                'id' => $effective['warehouse']->id,
                'name' => $effective['warehouse']->name,
                'type' => $effective['warehouse']->type,
            ] : null,
            'posInventoryWarehouseSource' => $effective['source'],
            'availablePosWarehouses' => $this->whenLoaded('warehouses', fn () => $this->warehouses->map(fn ($warehouse) => [
                'id' => $warehouse->id,
                'name' => $warehouse->name,
                'type' => $warehouse->type,
            ])->values()),
            'createdAt' => $this->created_at?->toISOString(),
            'updatedAt' => $this->updated_at?->toISOString(),
        ];
    }

    /** @return array{warehouse:mixed,source:string} */
    private function effectivePosWarehouse(): array
    {
        if (! $this->relationLoaded('warehouses')) {
            return ['warehouse' => null, 'source' => 'not_loaded'];
        }
        if ($this->pos_inventory_warehouse_id !== null) {
            $configured = $this->warehouses->firstWhere('id', (int) $this->pos_inventory_warehouse_id);

            return ['warehouse' => $configured, 'source' => $configured ? 'configured' : 'invalid_configured'];
        }
        $bars = $this->warehouses->where('type', 'bar')->values();
        if ($bars->count() === 1) {
            return ['warehouse' => $bars->first(), 'source' => 'bar_fallback'];
        }
        if ($bars->count() > 1) {
            return ['warehouse' => null, 'source' => 'ambiguous'];
        }
        $mainStores = $this->warehouses->where('type', 'branch_main')->values();
        if ($mainStores->count() === 1) {
            return ['warehouse' => $mainStores->first(), 'source' => 'main_fallback'];
        }

        return ['warehouse' => null, 'source' => $mainStores->count() > 1 ? 'ambiguous' : 'not_configured'];
    }
}
