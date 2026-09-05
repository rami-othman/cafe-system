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

    public static function factor(mixed $value, string $field = 'factor'): int
    {
        return self::scaled($value, 6, $field);
    }

    public static function conversionFactor(int $value): string
    {
        return self::decimal($value, 6);
    }

    /** Converts a quantity in 1/1000 units with a factor in 1/1,000,000. */
    public static function applyFactor(int $quantityUnits, int $factorUnits): int
    {
        $product = $quantityUnits * $factorUnits;
        if ($product % 1000000 !== 0) {
            throw ValidationException::withMessages([
                'quantity' => 'The converted quantity exceeds the supported base-unit precision.',
            ]);
        }

        return intdiv($product, 1000000);
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
        $raw = $quantityUnits * $costUnits;
        $negative = $raw < 0;
        $absolute = abs($raw);
        // Quantity has three decimal places and unit cost four; round their
        // seven-decimal product to currency cents using integer arithmetic.
        $cents = intdiv($absolute + 50000, 100000);

        return ($negative ? '-' : '').self::decimal($cents, 2);
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
        $negative = $value < 0;
        $absolute = abs($value);
        $divisor = 10 ** $scale;
        $whole = intdiv($absolute, $divisor);
        $fraction = str_pad((string) ($absolute % $divisor), $scale, '0', STR_PAD_LEFT);

        return ($negative ? '-' : '').$whole.'.'.$fraction;
    }
}
