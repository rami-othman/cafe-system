<?php

namespace App\Http\Resources\CafeConfiguration;

use Illuminate\Support\Str;

/**
 * Not a Laravel JsonResource: both callers (ReceiptTemplateController and
 * ReceiptController) already have a plain resolved array from
 * ReceiptTemplateResolver, not an Eloquent model instance, so a static
 * array-in/array-out mapper avoids the object-vs-array friction of
 * JsonResource's magic property access.
 */
class ReceiptTemplateResource
{
    public static function fromResolved(array $resolved): array
    {
        return [
            'header' => $resolved['header'],
            'orderInfo' => $resolved['order_info'],
            'items' => $resolved['items'],
            'totals' => $resolved['totals'],
            'payment' => $resolved['payment'],
            'footer' => $resolved['footer'],
            'sectionOrder' => array_map(static fn (string $section): string => Str::camel($section), $resolved['section_order']),
        ];
    }
}
