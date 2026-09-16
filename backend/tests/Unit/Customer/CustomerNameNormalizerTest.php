<?php

namespace Tests\Unit\Customer;

use App\Domain\Customer\CustomerNameNormalizer;
use Tests\TestCase;

class CustomerNameNormalizerTest extends TestCase
{
    public function test_it_preserves_display_name_while_trimming_and_collapsing_whitespace(): void
    {
        $result = CustomerNameNormalizer::normalize("  Mary   Jane\tDoe  ");

        $this->assertSame('Mary Jane Doe', $result['displayName']);
        $this->assertSame('mary jane doe', $result['normalizedName']);
    }

    public function test_it_case_folds_and_removes_arabic_diacritics_tatweel_and_alef_variants(): void
    {
        $result = CustomerNameNormalizer::normalize('  أَحْمَــــد   إِبْنُ آدَم  ');

        $this->assertSame('أَحْمَــــد إِبْنُ آدَم', $result['displayName']);
        $this->assertSame('احمد ابن ادم', $result['normalizedName']);
    }
}
