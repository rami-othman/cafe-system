<?php

namespace App\Services\Catalog;

use Brick\Math\BigDecimal;
use Illuminate\Validation\ValidationException;

class RecipeUnitRegistry
{
    private const UNITS = ['g' => ['mass', 'g', '1'], 'kg' => ['mass', 'g', '1000'], 'ml' => ['volume', 'ml', '1'], 'l' => ['volume', 'ml', '1000'], 'pc' => ['count', 'pc', '1']];

    private const INVENTORY = ['g' => 'g', 'gram' => 'g', 'grams' => 'g', 'kg' => 'kg', 'kilogram' => 'kg', 'kilograms' => 'kg', 'ml' => 'ml', 'milliliter' => 'ml', 'milliliters' => 'ml', 'l' => 'l', 'liter' => 'l', 'litre' => 'l', 'liters' => 'l', 'litres' => 'l', 'pc' => 'pc', 'piece' => 'pc', 'pieces' => 'pc'];

    public function inventoryUnit(?string $unit): ?string
    {
        return self::INVENTORY[strtolower(trim((string) $unit))] ?? null;
    }

    public function known(string $unit): bool
    {
        return isset(self::UNITS[$unit]);
    }

    public function family(string $unit): string
    {
        if (! $this->known($unit)) {
            throw ValidationException::withMessages(['unitCode' => 'Unsupported recipe unit.']);
        }

        return self::UNITS[$unit][0];
    }

    public function normalize(string $quantity, string $unit): array
    {
        $this->family($unit);

        return ['quantity' => BigDecimal::of($quantity)->multipliedBy(self::UNITS[$unit][2])->__toString(), 'unitCode' => self::UNITS[$unit][1], 'family' => self::UNITS[$unit][0]];
    }

    /** Canonical, lossless decimal representation for API and snapshot values. */
    public function quantityString(BigDecimal|string $quantity): string
    {
        $value = (string) $quantity;

        return str_contains($value, '.') ? rtrim(rtrim($value, '0'), '.') : $value;
    }

    public function compatible(string $materialUnit, string $recipeUnit): bool
    {
        return $this->known($materialUnit) && $this->known($recipeUnit) && $this->family($materialUnit) === $this->family($recipeUnit);
    }
}
