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

    public function test_it_accepts_negative_amounts_for_losses_and_variances(): void
    {
        $this->assertSame(-1234, Money::cents('-12.34'));
        $this->assertSame(-100, Money::cents('-1.000000'));
        $this->assertSame(0, Money::cents('-0.00'));
    }

    public function test_it_still_rejects_precision_beyond_cents_when_negative(): void
    {
        $this->expectException(ValidationException::class);

        Money::cents('-1.2301');
    }

    public function test_decimal_round_trips_through_cents_for_negative_values(): void
    {
        $this->assertSame(-1234, Money::cents(Money::decimal(-1234)));
    }
}
