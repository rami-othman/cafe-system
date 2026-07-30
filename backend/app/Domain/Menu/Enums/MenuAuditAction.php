<?php

namespace App\Domain\Menu\Enums;

enum MenuAuditAction: string
{
    case Created = 'created';
    case Updated = 'updated';
    case Archived = 'archived';
    case Restored = 'restored';
    case Reordered = 'reordered';
    case Assigned = 'assigned';
    case Unassigned = 'unassigned';
    case Published = 'published';
    case RolledBack = 'rolled_back';
    case AvailabilityChanged = 'availability_changed';
    case Moved = 'moved';
    case Synchronized = 'synchronized';
}
