<?php

namespace App\Domain\Inventory;

use App\Support\InventoryDecimal;
use App\Support\InventoryUnitCatalog;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class UnitConversionResolver
{
    /** @return array{inputUnit: string, factor: int, baseQuantity: int} */
    public function resolve(int $tenantId, object $item, string $quantity, ?string $unit): array
    {
        $baseUnit = InventoryUnitCatalog::normalize($item->unit);
        $inputUnit = $unit === null || trim($unit) === ''
            ? $baseUnit
            : InventoryUnitCatalog::normalize($unit);
        $quantityUnits = InventoryDecimal::units($quantity);

        if ($inputUnit === $baseUnit) {
            return ['inputUnit' => $inputUnit, 'factor' => 1000000, 'baseQuantity' => $quantityUnits];
        }

        $conversion = DB::table('inventory_item_unit_conversions')
            ->where('tenant_id', $tenantId)
            ->where('inventory_item_id', $item->id)
            ->where('source_unit', $inputUnit)
            ->where('target_unit', $baseUnit)
            ->where('is_active', true)
            ->first();
        if (! $conversion) {
            throw ValidationException::withMessages([
                'unit' => 'No active conversion exists from the entered unit to this item\'s base unit.',
            ]);
        }

        $factor = InventoryDecimal::factor($conversion->factor);
        if ($factor <= 0) {
            throw ValidationException::withMessages(['unit' => 'The active unit conversion is invalid.']);
        }

        return [
            'inputUnit' => $inputUnit,
            'factor' => $factor,
            'baseQuantity' => InventoryDecimal::applyFactor($quantityUnits, $factor),
        ];
    }
}
