<?php

namespace App\Domain\Menu\Enums;

enum ProductType: string
{
    case Standard = 'standard';
    case OpenPrice = 'open_price';
    case Combo = 'combo';
}
