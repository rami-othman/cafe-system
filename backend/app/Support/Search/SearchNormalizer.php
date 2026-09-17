<?php

namespace App\Support\Search;

class SearchNormalizer
{
    /**
     * Normalize text for search comparison only — never mutates stored data.
     * Mirrors the SQL function `smart_search_normalize` created in the
     * `add_smart_search_support` migration; keep both in sync.
     */
    public static function text(?string $value): string
    {
        $value = (string) ($value ?? '');

        // Strip Arabic diacritics (tanween/fatha/damma/kasra/shadda/sukun/superscript alef) and tatweel.
        $value = preg_replace('/[ًٌٍَُِّْٰـ]/u', '', $value) ?? $value;

        // Normalize alef/yeh variants only — do not touch ة/ه (handled via fuzzy matching instead).
        $value = strtr($value, [
            'أ' => 'ا',
            'إ' => 'ا',
            'آ' => 'ا',
            'ى' => 'ي',
        ]);

        $value = preg_replace('/\s+/u', ' ', $value) ?? $value;
        $value = trim($value);

        return mb_strtolower($value);
    }

    /** @return string[] */
    public static function tokens(?string $value): array
    {
        $normalized = self::text($value);
        if ($normalized === '') {
            return [];
        }

        return array_values(array_filter(explode(' ', $normalized), fn (string $token) => $token !== ''));
    }

    /**
     * Digits-only phone key, trunk-prefix stripped, right-anchored to 9 digits
     * so "+963 944 123 456", "0944 123456" and "944123456" all compare equal.
     */
    public static function phoneDigits(?string $value): string
    {
        $digits = preg_replace('/\D+/', '', (string) ($value ?? '')) ?? '';
        $digits = ltrim($digits, '0');

        return $digits !== '' && strlen($digits) > 9 ? substr($digits, -9) : $digits;
    }
}
