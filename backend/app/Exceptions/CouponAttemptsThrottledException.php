<?php

namespace App\Exceptions;

use RuntimeException;

/** Raised when failed coupon redemptions exceed the guessing budget. Rendered as HTTP 429 with Retry-After. */
class CouponAttemptsThrottledException extends RuntimeException
{
    public const CODE = 'COUPON_ATTEMPTS_THROTTLED';

    public function __construct(public readonly int $retryAfterSeconds)
    {
        parent::__construct('Too many invalid coupon attempts.', 429);
    }
}
