<?php

namespace App\Domain\Menu\Enums;

enum OperationalAvailabilityStatus: string
{
    case Available = 'available';
    case SoldOut = 'sold_out';
    case TemporarilyUnavailable = 'temporarily_unavailable';
}
