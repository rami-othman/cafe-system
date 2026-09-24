<?php

namespace App\Support;

use App\Models\ReceiptTemplate;

/**
 * Merges a branch's saved receipt template (if any) over
 * ReceiptTemplateDefaults, so a template saved before a future new toggle
 * was added still resolves that key, and a branch that never configured a
 * template prints exactly like the default. Shared by
 * ReceiptTemplateController and ReceiptController so both endpoints can
 * never disagree about what an order's receipt looks like.
 */
class ReceiptTemplateResolver
{
    public static function resolve(int $tenantId, int $branchId, string $type = 'receipt'): array
    {
        $defaults = ReceiptTemplateDefaults::array();
        $saved = ReceiptTemplate::query()
            ->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)
            ->where('type', $type)
            ->first();

        if (! $saved) {
            return $defaults;
        }

        return [
            'header' => array_merge($defaults['header'], $saved->header ?? []),
            'order_info' => array_merge($defaults['order_info'], $saved->order_info ?? []),
            'items' => array_merge($defaults['items'], $saved->items ?? []),
            'totals' => array_merge($defaults['totals'], $saved->totals ?? []),
            'payment' => array_merge($defaults['payment'], $saved->payment ?? []),
            'footer' => array_merge($defaults['footer'], $saved->footer ?? []),
            'section_order' => $saved->section_order ?: $defaults['section_order'],
        ];
    }
}
