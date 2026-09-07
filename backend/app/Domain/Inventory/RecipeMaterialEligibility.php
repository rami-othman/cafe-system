<?php

namespace App\Domain\Inventory;

final class RecipeMaterialEligibility
{
    public static function allows(object $item): bool
    {
        return ! in_array($item->item_type ?? null, ['non_stock_item', 'service'], true);
    }
}
