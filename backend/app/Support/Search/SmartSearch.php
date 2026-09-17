<?php

namespace App\Support\Search;

use Illuminate\Database\Query\Builder;

/**
 * Shared query-builder primitives for "smart search": Arabic/Latin normalized,
 * typo-tolerant (pg_trgm), multi-token AND matching with weighted ranking.
 *
 * Domain controllers decide which fields are searchable and how they're
 * weighted; this class only knows how to turn that into SQL. Requires the
 * `smart_search_normalize` SQL function and `pg_trgm` extension (see the
 * `add_smart_search_support` migration).
 *
 * Field shape: ['column' => 'items.name_en', 'weight' => 3, 'type' => 'text'|'code'|'phone']
 *   - text: normal name/description field, full fuzzy matching applies.
 *   - code: SKU/barcode/reference — exact/prefix/contains dominate; fuzzy only for close typos.
 *   - phone: matched via trunk-stripped digit comparison, no trigram fuzz.
 */
class SmartSearch
{
    private const FUZZY_MIN_TOKEN_LENGTH = 2;
    private const TEXT_SIMILARITY_THRESHOLD = 0.30;
    private const CODE_SIMILARITY_THRESHOLD = 0.45;

    /** Restrict $query to rows matching every token of $term across the given $fields (AND-across-tokens, OR-across-fields). */
    public static function apply(Builder $query, ?string $term, array $fields): Builder
    {
        $tokens = SearchNormalizer::tokens($term);
        if ($tokens === [] || $fields === []) {
            return $query;
        }

        foreach ($tokens as $token) {
            $fuzzy = mb_strlen($token) >= self::FUZZY_MIN_TOKEN_LENGTH;
            $query->where(function (Builder $tokenQuery) use ($fields, $token, $fuzzy) {
                foreach ($fields as $field) {
                    self::matchField($tokenQuery, $field, $token, $fuzzy);
                }
            });
        }

        return $query;
    }

    private static function matchField(Builder $query, array $field, string $token, bool $fuzzy): void
    {
        $column = self::assertSafeColumn($field['column']);
        $type = $field['type'] ?? 'text';

        if ($type === 'phone') {
            $digits = SearchNormalizer::phoneDigits($token);
            if ($digits === '') {
                return;
            }
            $query->orWhereRaw(self::phoneKeyExpression($column).' LIKE ?', ['%'.$digits.'%']);

            return;
        }

        $query->orWhereRaw("smart_search_normalize($column) LIKE ?", ['%'.$token.'%']);

        if ($fuzzy) {
            $threshold = $type === 'code' ? self::CODE_SIMILARITY_THRESHOLD : self::TEXT_SIMILARITY_THRESHOLD;
            $query->orWhereRaw("similarity(smart_search_normalize($column), ?) > $threshold", [$token]);
        }
    }

    /**
     * Adds a `smart_rank` computed column to $query (via selectRaw) scoring exact >
     * prefix > contains > fuzzy matches, weighted per field. Caller should then
     * `->orderByDesc('smart_rank')` (with a stable tiebreaker after it).
     */
    public static function withRelevance(Builder $query, ?string $term, array $fields): Builder
    {
        // `selectRaw`/`addSelect` on a builder that never called `select()` replaces
        // the implicit "select *" instead of adding to it — pin it explicitly first
        // so every other column survives alongside the computed rank.
        if ($query->columns === null) {
            $query->select('*');
        }

        $tokens = SearchNormalizer::tokens($term);
        if ($tokens === [] || $fields === []) {
            return $query->selectRaw('0 as smart_rank');
        }

        $parts = [];
        $bindings = [];
        foreach ($fields as $field) {
            $column = self::assertSafeColumn($field['column']);
            $type = $field['type'] ?? 'text';
            $weight = (float) ($field['weight'] ?? 1);

            foreach ($tokens as $token) {
                if ($type === 'phone') {
                    $digits = SearchNormalizer::phoneDigits($token);
                    if ($digits === '') {
                        continue;
                    }
                    $parts[] = '(CASE WHEN '.self::phoneKeyExpression($column)." = ? THEN ".(100 * $weight).' ELSE (CASE WHEN '.self::phoneKeyExpression($column)." LIKE ? THEN ".(30 * $weight).' ELSE 0 END) END)';
                    $bindings[] = $digits;
                    $bindings[] = '%'.$digits.'%';

                    continue;
                }

                $parts[] = "(CASE WHEN smart_search_normalize($column) = ? THEN ".(100 * $weight).' ELSE 0 END)';
                $bindings[] = $token;
                $parts[] = "(CASE WHEN smart_search_normalize($column) LIKE ? THEN ".(50 * $weight).' ELSE 0 END)';
                $bindings[] = $token.'%';
                $parts[] = "(CASE WHEN smart_search_normalize($column) LIKE ? THEN ".(20 * $weight).' ELSE 0 END)';
                $bindings[] = '%'.$token.'%';
                $parts[] = "(COALESCE(similarity(smart_search_normalize($column), ?), 0) * ".(10 * $weight).')';
                $bindings[] = $token;
            }
        }

        if ($parts === []) {
            return $query->selectRaw('0 as smart_rank');
        }

        return $query->selectRaw('('.implode(' + ', $parts).') as smart_rank', $bindings);
    }

    private static function phoneKeyExpression(string $column): string
    {
        return "right(ltrim(regexp_replace($column, '[^0-9]', '', 'g'), '0'), 9)";
    }

    /** Fields are developer-supplied constants, never user input — but guard against accidental misuse anyway. */
    private static function assertSafeColumn(string $column): string
    {
        if (! preg_match('/^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)?$/', $column)) {
            throw new \InvalidArgumentException("Unsafe search column reference: $column");
        }

        return $column;
    }
}
