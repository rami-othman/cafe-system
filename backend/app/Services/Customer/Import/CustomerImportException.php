<?php

namespace App\Services\Customer\Import;

use RuntimeException;

final class CustomerImportException extends RuntimeException
{
    public function __construct(public readonly string $domainCode, string $message, public readonly int $status = 422)
    {
        parent::__construct($message);
    }

    public static function invalidFile(string $code, string $message = 'The customer import file is invalid.'): self
    {
        return new self($code, $message);
    }

    public static function notReady(): self
    {
        return new self('CUSTOMER_IMPORT_NOT_READY', 'The customer import is not ready for this action.');
    }

    public static function alreadyCompleted(): self
    {
        return new self('CUSTOMER_IMPORT_ALREADY_COMPLETED', 'This customer import file was already completed for this tenant.', 409);
    }
}
