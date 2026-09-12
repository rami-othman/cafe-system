<?php

namespace App\Domain\Customer;

final class CustomerNameNormalizer
{
    /** @return array{displayName: string, normalizedName: string} */
    public static function normalize(string $name): array
    {
        $displayName = preg_replace('/\s+/u', ' ', trim($name)) ?? trim($name);
        $normalizedName = mb_strtolower($displayName, 'UTF-8');
        $normalizedName = preg_replace('/[\x{064B}-\x{065F}\x{0670}\x{06D6}-\x{06ED}]/u', '', $normalizedName) ?? $normalizedName;
        $normalizedName = str_replace(["\u{0640}", 'أ', 'إ', 'آ', 'ٱ'], ['', 'ا', 'ا', 'ا', 'ا'], $normalizedName);

        return [
            'displayName' => $displayName,
            'normalizedName' => $normalizedName,
        ];
    }
}
