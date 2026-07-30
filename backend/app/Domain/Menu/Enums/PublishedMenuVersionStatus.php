<?php

namespace App\Domain\Menu\Enums;

enum PublishedMenuVersionStatus: string
{
    case Current = 'current';
    case Superseded = 'superseded';
    case RolledBack = 'rolled_back';
}
