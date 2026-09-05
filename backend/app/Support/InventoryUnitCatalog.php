<?php

namespace App\Support;

final class InventoryUnitCatalog
{
    public const UNITS = [
        'piece' => 'Piece', 'pack' => 'Pack', 'box' => 'Box',
        'carton' => 'Carton', 'bag' => 'Bag', 'bottle' => 'Bottle',
        'can' => 'Can', 'gram' => 'Gram', 'kilogram' => 'Kilogram',
        'milliliter' => 'Milliliter', 'liter' => 'Liter',
    ];

    public static function codes(): array
    {
        return array_keys(self::UNITS);
    }

    public static function normalize(?string $unit): string
    {
        $value = mb_strtolower(trim((string) $unit));
        $aliases = [
            'pcs' => 'piece', 'pc' => 'piece', 'pieces' => 'piece', 'unit' => 'piece', 'units' => 'piece',
            'packs' => 'pack', 'boxes' => 'box', 'cartons' => 'carton', 'bags' => 'bag',
            'bottles' => 'bottle', 'cans' => 'can', 'g' => 'gram', 'grams' => 'gram',
            'kg' => 'kilogram', 'kgs' => 'kilogram', 'kilograms' => 'kilogram',
            'ml' => 'milliliter', 'milliliters' => 'milliliter', 'l' => 'liter', 'liters' => 'liter',
        ];

        return $aliases[$value] ?? $value;
    }

    public static function response(): array
    {
        return collect(self::UNITS)
            ->map(fn (string $label, string $code) => ['code' => $code, 'label' => $label])
            ->values()
            ->all();
    }
}
