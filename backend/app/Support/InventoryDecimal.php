<?php

namespace App\Support;

use Illuminate\Validation\ValidationException;

final class InventoryDecimal
{
    public static function units(mixed $value, string $field = 'quantity'): int
    {
        return self::scaled($value, 3, $field);
    }

    public static function signedUnits(mixed $value, string $field = 'quantity'): int
    {
        $decimal = trim((string) $value);
        $negative = str_starts_with($decimal, '-');

        return ($negative ? -1 : 1) * self::units($negative ? substr($decimal, 1) : $decimal, $field);
    }

    public static function cost(mixed $value, string $field = 'unitCost'): int
    {
        return self::scaled($value, 4, $field);
    }

    public static function quantity(int $value): string
    {
        return self::decimal($value, 3);
    }

    public static function unitCost(int $value): string
    {
        return self::decimal($value, 4);
    }

    public static function totalCost(int $quantityUnits, int $costUnits): string
    {
        return number_format(($quantityUnits * $costUnits) / 10000000, 2, '.', '');
    }

    private static function scaled(mixed $value, int $scale, string $field): int
    {
        $decimal = trim((string) $value);
        if (! preg_match('/^(\d+)(?:\.(\d{1,'.$scale.'}))?$/', $decimal, $matches)) {
            throw ValidationException::withMessages([$field => 'يجب إدخال رقم موجب بدقة صحيحة.']);
        }

        return ((int) $matches[1] * (10 ** $scale)) + (int) str_pad($matches[2] ?? '', $scale, '0');
    }

    private static function decimal(int $value, int $scale): string
    {
        return number_format($value / (10 ** $scale), $scale, '.', '');
    }
}
