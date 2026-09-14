<?php

namespace Tests\Unit\Customer;

use App\Domain\Customer\CustomerPhoneNormalizer;
use Tests\TestCase;

class CustomerPhoneNormalizerTest extends TestCase
{
    public function test_it_preserves_trimmed_raw_value_and_normalizes_ascii_digits_and_punctuation(): void
    {
        $result = CustomerPhoneNormalizer::normalize('  +1 (555) 123-4567  ');

        $this->assertSame('+1 (555) 123-4567', $result['rawNumber']);
        $this->assertSame('+15551234567', $result['normalizedNumber']);
        $this->assertSame('valid', $result['validationStatus']);
    }

    public function test_it_translates_arabic_indic_and_eastern_arabic_digits(): void
    {
        $this->assertSame('+963991234567', CustomerPhoneNormalizer::normalize('+٩٦٣ ٩٩١٢٣٤٥٦٧')['normalizedNumber']);
        $this->assertSame('00963991234567', CustomerPhoneNormalizer::normalize('۰۰۹۶۳۹۹۱۲۳۴۵۶۷')['normalizedNumber']);
    }

    public function test_it_classifies_national_and_uncertain_values_without_discarding_them(): void
    {
        $unverified = CustomerPhoneNormalizer::normalize('091234567');
        $invalid = CustomerPhoneNormalizer::normalize('call-me');

        $this->assertSame('091234567', $unverified['rawNumber']);
        $this->assertSame('091234567', $unverified['normalizedNumber']);
        $this->assertSame('unverified', $unverified['validationStatus']);
        $this->assertNull($invalid['normalizedNumber']);
        $this->assertSame('invalid', $invalid['validationStatus']);
    }
}
