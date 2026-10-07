<?php

namespace App\Services;

use RuntimeException;

final class WhatsAppDeliveryException extends RuntimeException
{
    public function __construct(string $message, public readonly string $failureCode = 'whatsapp_failed')
    {
        parent::__construct($message);
    }
}
