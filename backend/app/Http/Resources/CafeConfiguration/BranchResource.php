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

    /**
     * There is no "primary"/"bar" precedence — a branch is a flat set of
     * warehouses. An explicit `pos_inventory_warehouse_id` always wins;
     * otherwise this only resolves when the branch has exactly one
     * warehouse (mirrors PosInventoryWarehouseResolver exactly, so the UI
     * can never show a different answer than what POS actually uses).
     *
     * @return array{warehouse:mixed,source:string}
     */
    private function effectivePosWarehouse(): array
    {
        if (! $this->relationLoaded('warehouses')) {
            return ['warehouse' => null, 'source' => 'not_loaded'];
        }
        if ($this->pos_inventory_warehouse_id !== null) {
            $configured = $this->warehouses->firstWhere('id', (int) $this->pos_inventory_warehouse_id);

            return ['warehouse' => $configured, 'source' => $configured ? 'configured' : 'invalid_configured'];
        }
        if ($this->warehouses->count() === 1) {
            return ['warehouse' => $this->warehouses->first(), 'source' => 'single_warehouse'];
        }

        return ['warehouse' => null, 'source' => $this->warehouses->count() > 1 ? 'ambiguous' : 'not_configured'];
    }
}
