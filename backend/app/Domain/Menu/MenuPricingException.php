<?php

namespace App\Domain\Menu;

class MenuPricingException extends \RuntimeException
{
    public function __construct(public readonly string $domainCode, public readonly int $status = 422) { parent::__construct($domainCode); }
}
