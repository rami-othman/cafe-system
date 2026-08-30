<?php

namespace App\Exceptions;

use RuntimeException;

class UnsupportedMenuSnapshotSchemaException extends RuntimeException
{
    public function __construct(public readonly mixed $schemaVersion)
    {
        parent::__construct('The current published menu uses an unsupported snapshot schema.');
    }
}
