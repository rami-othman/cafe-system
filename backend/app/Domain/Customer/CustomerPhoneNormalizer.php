<?php

namespace App\Domain\Customer;

final class CustomerPhoneNormalizer
{
    /** @return array{rawNumber: string, normalizedNumber: ?string, validationStatus: string} */
    public static function normalize(string $value): array
    {
        $rawNumber = trim($value);
        $translated = strtr($rawNumber, [
            '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
            '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
            '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
            '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
        ]);
        $hasLeadingPlus = str_starts_with($translated, '+');
        $digits = preg_replace('/\D/u', '', $translated) ?? '';
        $normalizedNumber = $digits === '' ? null : ($hasLeadingPlus ? '+'.$digits : $digits);
        $digitCount = strlen($digits);

        $validationStatus = 'invalid';
        if ($hasLeadingPlus && $digitCount >= 8 && $digitCount <= 15) {
            $validationStatus = 'valid';
        } elseif (! $hasLeadingPlus && $digitCount >= 7 && $digitCount <= 15) {
            $validationStatus = 'unverified';
        }

        return [
            'rawNumber' => $rawNumber,
            'normalizedNumber' => $normalizedNumber,
            'validationStatus' => $validationStatus,
        ];
    }
}
