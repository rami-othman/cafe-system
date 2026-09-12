<?php

namespace App\Domain\Customer;

use RuntimeException;

final class CustomerDomainException extends RuntimeException
{
    public function __construct(public readonly string $domainCode, string $message, public readonly int $status = 422)
    {
        parent::__construct($message);
    }

    public static function permissionDenied(): self
    {
        return new self('CUSTOMER_PERMISSION_DENIED', 'Customer permission denied.', 403);
    }

    public static function notOperationallyEligible(): self
    {
        return new self('CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE', 'Customer is not operationally eligible.', 422);
    }

    public static function invalidTransition(): self
    {
        return new self('CUSTOMER_INVALID_TRANSITION', 'Customer lifecycle transition is invalid.', 422);
    }

    public static function numberConflict(): self
    {
        return new self('CUSTOMER_NUMBER_CONFLICT', 'Customer number could not be allocated.', 409);
    }

    public static function writeConflict(): self
    {
        return new self('CUSTOMER_WRITE_CONFLICT', 'Customer write conflicted with another request.', 409);
    }
}
