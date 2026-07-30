<?php

namespace App\Domain\Menu\Enums;

enum MenuStatus: string
{
    case Draft = 'draft';
    case Active = 'active';
    case Paused = 'paused';
    case Archived = 'archived';
}
