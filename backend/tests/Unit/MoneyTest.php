<?php

namespace Tests\Unit;

use App\Support\Money;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class MoneyTest extends TestCase
{
    public function test_it_normalises_zero_padded_database_numeric_values(): void
    {
        $this->assertSame(123, Money::cents('1.2300'));
        $this->assertSame(100, Money::cents('1.000000'));
    }

    public function test_it_still_rejects_precision_beyond_cents(): void
    {
        $this->expectException(ValidationException::class);

        Money::cents('1.2301');
    }
}
