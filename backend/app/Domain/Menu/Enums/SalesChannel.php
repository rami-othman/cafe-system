<?php

namespace App\Domain\Menu\Enums;

enum SalesChannel: string
{
    case Pos = 'pos';
    case WaiterApp = 'waiter_app';
    case Kiosk = 'kiosk';
    case QrOrdering = 'qr_ordering';
    case Delivery = 'delivery';
    case OnlineOrdering = 'online_ordering';
}
