<?php

namespace App\Support;

final class WarehousePresentation
{
    public static function isLegacy(?string $code): bool
    {
        return $code === null || str_starts_with(strtoupper($code), 'LEGACY-');
    }

    public static function typeLabel(string $type): string
    {
        return match ($type) {
            'central' => 'Central',
            'branch_main', 'main' => 'Main Store',
            'bar' => 'Bar',
            'kitchen' => 'Kitchen',
            default => 'Warehouse',
        };
    }

    public static function displayName(?string $branchName, string $type): string
    {
        if ($type === 'central') {
            return 'Central Warehouse';
        }

        return ($branchName ?: 'Branch').' — '.self::typeLabel($type);
    }
}
