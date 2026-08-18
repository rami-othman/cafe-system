<?php

namespace App\Rules;

use Brick\Math\BigDecimal;
use Brick\Math\Exception\MathException;
use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

class StrictlyPositiveMoney implements ValidationRule
{
    public function __construct(private readonly string $label) {}

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        try {
            $valid = BigDecimal::of((string) $value)->isGreaterThan(BigDecimal::zero());
        } catch (MathException) {
            $valid = false;
        }

        if (! $valid) {
            $fail("{$this->label} must be greater than zero.");
        }
    }
}
