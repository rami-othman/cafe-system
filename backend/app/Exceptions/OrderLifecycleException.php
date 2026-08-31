<?php

namespace App\Exceptions;

use RuntimeException;

class OrderLifecycleException extends RuntimeException
{
    public function __construct(
        public readonly string $domainCode,
        string $message,
    ) {
        parent::__construct($message, 422);
    }
}
