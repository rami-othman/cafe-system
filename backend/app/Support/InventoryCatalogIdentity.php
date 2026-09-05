<?php

namespace App\Support;

final class InventoryCatalogIdentity
{
    public static function forValues(?string $sku, ?string $name, ?string $unit, ?string $itemType): string
    {
        $normalizedSku = self::normalize($sku);
        if ($normalizedSku !== '') {
            return 'sku:'.$normalizedSku;
        }

        return implode('|', [
            'name:'.self::normalize($name),
            'unit:'.self::normalize($unit),
            'type:'.self::normalize($itemType),
        ]);
    }

    public static function normalize(?string $value): string
    {
        $value = trim((string) $value);
        $value = preg_replace('/\s+/u', ' ', $value) ?? $value;

        return mb_strtolower($value, 'UTF-8');
    }
}
