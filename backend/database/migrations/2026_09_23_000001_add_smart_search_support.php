<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Foundation for application-wide smart search: pg_trgm for typo-tolerant
 * fuzzy matching, plus an IMMUTABLE `smart_search_normalize` SQL function
 * (Arabic alef/yeh variant folding, diacritic/tatweel stripping, whitespace
 * collapse, Latin lowercasing) so query-time normalization and indexed
 * expressions always agree. Keep this in sync with
 * App\Support\Search\SearchNormalizer::text().
 *
 * GIN trigram indexes are added only for the columns the first wave of
 * smart-search endpoints actually searches (products, product variants,
 * customers, suppliers, inventory items) — see App\Support\Search\SmartSearch
 * call sites. Add more as later modules adopt smart search, not preemptively.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('CREATE EXTENSION IF NOT EXISTS pg_trgm');

        DB::unprepared(<<<'SQL'
            CREATE OR REPLACE FUNCTION smart_search_normalize(input text)
            RETURNS text
            LANGUAGE sql
            IMMUTABLE
            PARALLEL SAFE
            AS $$
                SELECT lower(
                    trim(
                        regexp_replace(
                            translate(
                                regexp_replace(coalesce($1, ''), '[ًٌٍَُِّْٰـ]', '', 'g'),
                                'أإآى', 'اااي'
                            ),
                            '\s+', ' ', 'g'
                        )
                    )
                )
            $$;
        SQL);

        foreach ($this->indexedColumns() as [$table, $column]) {
            $indexName = "{$table}_{$column}_search_trgm_idx";
            DB::statement("CREATE INDEX IF NOT EXISTS $indexName ON $table USING gin (smart_search_normalize($column) gin_trgm_ops)");
        }
    }

    public function down(): void
    {
        foreach ($this->indexedColumns() as [$table, $column]) {
            $indexName = "{$table}_{$column}_search_trgm_idx";
            DB::statement("DROP INDEX IF EXISTS $indexName");
        }

        DB::statement('DROP FUNCTION IF EXISTS smart_search_normalize(text)');
        // pg_trgm is left installed — other extensions/indexes may depend on it and it is harmless to keep.
    }

    /** @return array<int, array{0: string, 1: string}> */
    private function indexedColumns(): array
    {
        return [
            ['products', 'name'],
            ['products', 'name_ar'],
            ['products', 'name_en'],
            ['products', 'sku'],
            ['products', 'barcode'],
            ['product_variants', 'name'],
            ['product_variants', 'sku'],
            ['product_variants', 'barcode'],
            ['customers', 'name'],
            ['suppliers', 'name'],
            ['inventory_items', 'name_ar'],
            ['inventory_items', 'name_en'],
            ['inventory_items', 'sku'],
            ['inventory_items', 'barcode'],
        ];
    }
};
