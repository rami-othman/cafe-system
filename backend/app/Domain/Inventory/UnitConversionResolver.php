<?php

namespace App\Domain\Inventory;

use App\Support\InventoryDecimal;
use App\Support\InventoryUnitCatalog;
use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class UnitConversionResolver
{
    /** @return array{inputUnit: string, factor: int, baseQuantity: int} */
    public function resolve(int $tenantId, object $item, string $quantity, ?string $unit): array
    {
        $resolved = $this->contract($tenantId, $item, $unit);
        $quantityUnits = InventoryDecimal::units($quantity);

        return $resolved + [
            'baseQuantity' => InventoryDecimal::applyFactor($quantityUnits, $resolved['factor']),
        ];
    }

    /**
     * Resolves a published recipe quantity with up to six decimals into the
     * item's three-decimal inventory base quantity. No rounding is permitted.
     *
     * @return array{inputUnit: string, baseUnit: string, factor: int, baseQuantity: int}
     */
    public function resolveRecipe(int $tenantId, object $item, string $quantity, ?string $unit): array
    {
        $resolved = $this->contract($tenantId, $item, $unit);
        if (! preg_match('/^\d+(\.\d{1,6})?$/', trim($quantity))) {
            throw ValidationException::withMessages(['quantity' => 'Recipe quantity must be a positive decimal with at most six places.']);
        }

        try {
            $baseQuantity = BigDecimal::of($quantity)
                ->multipliedBy(InventoryDecimal::conversionFactor($resolved['factor']))
                ->toScale(3, RoundingMode::UNNECESSARY);
        } catch (\Throwable) {
            throw ValidationException::withMessages(['quantity' => 'Converted quantity cannot be represented at Inventory 3-decimal precision.']);
        }

        return $resolved + ['baseQuantity' => InventoryDecimal::units((string) $baseQuantity)];
    }

    /** @return array{inputUnit: string, baseUnit: string, factor: int} */
    private function contract(int $tenantId, object $item, ?string $unit): array
    {
        $baseUnit = InventoryUnitCatalog::normalize($item->unit);
        $inputUnit = $unit === null || trim($unit) === '' ? $baseUnit : InventoryUnitCatalog::normalize($unit);

        if (! InventoryUnitCatalog::isKnown($baseUnit)) {
            throw ValidationException::withMessages(['unit' => 'The Inventory material base unit is unsupported.']);
        }
        if (! InventoryUnitCatalog::isKnown($inputUnit)) {
            throw ValidationException::withMessages(['unit' => 'The recipe unit is not an Inventory unit.']);
        }

        if ($inputUnit === $baseUnit) {
            return ['inputUnit' => $inputUnit, 'baseUnit' => $baseUnit, 'factor' => 1000000];
        }

        $conversion = DB::table('inventory_item_unit_conversions')
            ->where('tenant_id', $tenantId)->where('inventory_item_id', $item->id)
            ->where('source_unit', $inputUnit)->where('target_unit', $baseUnit)->where('is_active', true)->first();
        if (! $conversion) {
            throw ValidationException::withMessages(['unit' => "No active Inventory conversion exists from $inputUnit to $baseUnit."]);
        }

        try {
            $factor = InventoryDecimal::factor($conversion->factor);
        } catch (ValidationException) {
            throw ValidationException::withMessages(['unit' => "The active Inventory conversion from $inputUnit to $baseUnit is invalid."]);
        }
        if ($factor <= 0) {
            throw ValidationException::withMessages(['unit' => "The active Inventory conversion from $inputUnit to $baseUnit is invalid."]);
        }

        return ['inputUnit' => $inputUnit, 'baseUnit' => $baseUnit, 'factor' => $factor];
    }
}
