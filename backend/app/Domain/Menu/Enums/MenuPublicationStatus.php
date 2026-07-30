<?php

namespace App\Domain\Menu\Enums;

enum MenuPublicationStatus: string
{
    case Pending = 'pending';
    case Published = 'published';
    case Failed = 'failed';
}
