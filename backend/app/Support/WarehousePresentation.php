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
            'branch_main', 'main' => 'رئيسي',
            'bar' => 'البار',
            'kitchen' => 'المطبخ',
            default => 'مخزن',
        };
    }

    public static function displayName(?string $branchName, string $type): string
    {
        return ($branchName ?: 'الفرع').' — مخزن '.self::typeLabel($type);
    }
}
