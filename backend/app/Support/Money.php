<?php

namespace App\Support;

use Illuminate\Validation\ValidationException;

final class Money
{
    public static function cents(mixed $value, string $field = 'amount'): int
    {
        $decimal = trim((string) $value);
        if (! preg_match('/^(\d+)(?:\.(\d+))?$/', $decimal, $matches)) {
            throw ValidationException::withMessages([$field => 'The amount must use no more than two decimal places.']);
        }

        // PostgreSQL returns aggregate NUMERIC values using the column scale
        // (for example, "12.0000").  Those are still exact cent amounts and
        // are safe to normalise.  Values with a non-zero fraction past cents
        // remain invalid at every boundary, including user input.
        $fraction = $matches[2] ?? '';
        if (strlen($fraction) > 2 && trim(substr($fraction, 2), '0') !== '') {
            throw ValidationException::withMessages([$field => 'The amount must use no more than two decimal places.']);
        }

        $fraction = substr($fraction, 0, 2);

        return ((int) $matches[1] * 100) + (int) str_pad($fraction, 2, '0');
    }

    public static function decimal(int $cents): string
    {
        return number_format($cents / 100, 2, '.', '');
    }
}
