<?php

namespace App\Support;

use Illuminate\Validation\ValidationException;

final class Money
{
    public static function cents(mixed $value, string $field = 'amount'): int
    {
        $decimal = trim((string) $value);
        if (! preg_match('/^(\d+)(?:\.(\d{1,2}))?$/', $decimal, $matches)) {
            throw ValidationException::withMessages([$field => 'The amount must use no more than two decimal places.']);
        }

        return ((int) $matches[1] * 100) + (int) str_pad($matches[2] ?? '', 2, '0');
    }

    public static function decimal(int $cents): string
    {
        return number_format($cents / 100, 2, '.', '');
    }
}
