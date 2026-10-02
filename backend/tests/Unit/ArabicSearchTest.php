<?php

namespace Tests\Unit;

use App\Support\ArabicSearch;
use PHPUnit\Framework\TestCase;

class ArabicSearchTest extends TestCase
{
    private function found(string $query, array $fields): bool
    {
        return ArabicSearch::score($query, $fields) > 0;
    }

    public function test_normalisation_unifies_arabic_letter_variants_digits_and_marks(): void
    {
        $this->assertSame('الاجهزه الالكترونيه', ArabicSearch::normalize('الأجهزة الإلكترونية'));
        $this->assertSame('محمد 123', ArabicSearch::normalize('مُحَمَّد ١٢٣'));
        $this->assertSame('موردين ارت', ArabicSearch::normalize('موردين › أرت'));
    }

    public function test_the_reported_typo_query_finds_the_electronics_account(): void
    {
        $fields = ['1231', 'الأجهزة الإلكترونية', 'Electronic devices', 'الموجودات الثابتة'];
        $this->assertTrue($this->found('الاجهزة الالكتزو', $fields));
        $this->assertTrue($this->found('اجهزه الكترونيه', $fields));
        $this->assertTrue($this->found('الكترونية اجهزة', $fields), 'word order does not matter');
        $this->assertTrue($this->found('اجهز', $fields), 'half typed words match');
    }

    public function test_every_word_must_match_and_unrelated_rows_are_rejected(): void
    {
        $fields = ['22321', 'محمصة ارت للبن المختص', '', 'موردين'];
        $this->assertTrue($this->found('محمصه ارت', $fields));
        $this->assertTrue($this->found('موردين ارت', $fields), 'parent path is searchable');
        $this->assertTrue($this->found('22321', $fields));
        $this->assertFalse($this->found('محمصة سويلانو', $fields));
        $this->assertFalse($this->found('مطبعة', $fields));
    }

    public function test_short_words_do_not_fuzzy_match_and_codes_match_by_prefix_only(): void
    {
        $this->assertFalse($this->found('لبن', ['9', 'لتر', '', '']));
        $this->assertTrue($this->found('223', ['22321', 'x', '', '']));
        $this->assertFalse($this->found('2233', ['22321', 'x', '', '']));
    }

    public function test_exact_and_prefix_matches_rank_above_typo_matches(): void
    {
        $exact = ArabicSearch::score('محمصة', ['1', 'محمصة سلان', '', '']);
        $typo = ArabicSearch::score('محمصة', ['2', 'محمسة سلان', '', '']);
        $this->assertGreaterThan($typo, $exact);
        $this->assertGreaterThan(0, $typo);
    }
}
