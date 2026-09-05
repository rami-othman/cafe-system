<?php

namespace App\Domain\Inventory;

final readonly class MovementPostingResult
{
    public function __construct(public int $movementId, public bool $replayed = false) {}
}
