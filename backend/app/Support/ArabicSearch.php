<?php

namespace App\Support;

/**
 * Forgiving Arabic/Latin search used by list endpoints (chart of accounts, pickers…).
 *
 * The rules mirror windows_application/lib/core/utils/arabic_search.dart so the
 * server-side and client-side results are ranked the same way:
 *  - letters are normalised (أ إ آ → ا، ى → ي، ة → ه، ؤ → و، ئ → ي)، تشكيل/تطويل removed،
 *    Arabic-Indic digits become 0-9, punctuation becomes a word separator;
 *  - every typed word must match (AND) something in the searchable fields;
 *  - a word matches by exact word, prefix, contained text, or — for words of 4+
 *    letters — a small typo (one substituted/missing/extra/swapped letter, two for long words).
 */
final class ArabicSearch
{
    private const LETTER_MAP = [
        'أ' => 'ا', 'إ' => 'ا', 'آ' => 'ا', 'ٱ' => 'ا',
        'ى' => 'ي', 'ئ' => 'ي', 'ة' => 'ه', 'ؤ' => 'و', 'ء' => '',
        '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
        '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
        '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
        '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
    ];

    public static function normalize(string $text): string
    {
        $text = mb_strtolower($text, 'UTF-8');
        // Tashkeel, superscript alef, tatweel.
        $text = (string) preg_replace('/[\x{064B}-\x{065F}\x{0670}\x{0640}]/u', '', $text);
        $text = strtr($text, self::LETTER_MAP);
        $text = (string) preg_replace('/[^\p{L}\p{N}]+/u', ' ', $text);

        return trim((string) preg_replace('/\s+/u', ' ', $text));
    }

    /**
     * @return list<string> normalised words of the text, definite article removed.
     *                      With $expand, a leading conjunction "و" also yields the bare word
     *                      ("والالكترونية" is found by "الكترونية").
     */
    public static function words(string $text, bool $expand = false): array
    {
        $normalized = self::normalize($text);
        if ($normalized === '') {
            return [];
        }
        $words = [];
        foreach (explode(' ', $normalized) as $word) {
            $words[] = self::stripArticle($word);
            if ($expand && mb_strlen($word) > 4 && str_starts_with($word, 'و')) {
                $words[] = self::stripArticle(mb_substr($word, 1));
            }
        }

        return array_values(array_unique($words));
    }

    public static function stripArticle(string $word): string
    {
        return mb_strlen($word) > 3 && str_starts_with($word, 'ال') ? mb_substr($word, 2) : $word;
    }

    /**
     * @param  list<string>  $fields  searchable texts (code, Arabic name, English name, parent path…)
     * @return int 0 when the row does not match, otherwise a relevance score (higher is better)
     */
    public static function score(string $query, array $fields): int
    {
        $tokens = self::words($query);
        if ($tokens === []) {
            return 1;
        }
        $words = [];
        $normalizedFields = [];
        foreach ($fields as $index => $field) {
            $normalizedFields[$index] = self::normalize($field);
            foreach (self::words($field, true) as $word) {
                $words[] = [$word, $index];
            }
        }
        $total = 0;
        foreach ($tokens as $token) {
            $best = 0;
            foreach ($words as [$word, $index]) {
                $best = max($best, self::wordScore($token, $word, $index === 0));
                if ($best === 100) {
                    break;
                }
            }
            if ($best === 0) {
                return 0;
            }
            $total += $best;
        }
        $phrase = self::normalize($query);
        foreach ($normalizedFields as $index => $field) {
            if ($field === '') {
                continue;
            }
            if ($field === $phrase) {
                $total += 200;
            } elseif (str_starts_with($field, $phrase)) {
                $total += $index === 0 ? 120 : 80;
            } elseif (str_contains($field, $phrase)) {
                $total += 40;
            }
        }

        return max($total, 1);
    }

    private static function wordScore(string $token, string $word, bool $isCode): int
    {
        if ($word === $token) {
            return 100;
        }
        if (str_starts_with($word, $token)) {
            return $isCode ? 90 : 80;
        }
        if (mb_strlen($token) >= 2 && str_contains($word, $token)) {
            return 40;
        }
        $length = mb_strlen($token);
        if ($length < 4 || $isCode) {
            return 0;
        }
        $allowed = $length >= 8 ? 2 : 1;
        // Compare with the same-length beginning of the word so half-typed words still match.
        $head = mb_substr($word, 0, min(mb_strlen($word), $length));
        if (self::distance($token, $head, $allowed) <= $allowed || self::distance($token, $word, $allowed) <= $allowed) {
            return 25;
        }

        return 0;
    }

    /** Optimal-string-alignment distance (insert, delete, substitute, swap) with an early exit. */
    private static function distance(string $a, string $b, int $limit): int
    {
        $a = mb_str_split($a);
        $b = mb_str_split($b);
        $n = count($a);
        $m = count($b);
        if (abs($n - $m) > $limit) {
            return $limit + 1;
        }
        $previous2 = [];
        $previous = range(0, $m);
        for ($i = 1; $i <= $n; $i++) {
            $current = [$i];
            $rowMin = $i;
            for ($j = 1; $j <= $m; $j++) {
                $cost = $a[$i - 1] === $b[$j - 1] ? 0 : 1;
                $value = min($previous[$j] + 1, $current[$j - 1] + 1, $previous[$j - 1] + $cost);
                if ($i > 1 && $j > 1 && $a[$i - 1] === $b[$j - 2] && $a[$i - 2] === $b[$j - 1]) {
                    $value = min($value, $previous2[$j - 2] + 1);
                }
                $current[$j] = $value;
                $rowMin = min($rowMin, $value);
            }
            if ($rowMin > $limit) {
                return $limit + 1;
            }
            $previous2 = $previous;
            $previous = $current;
        }

        return $previous[$m];
    }
}
