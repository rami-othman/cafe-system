<?php

namespace App\Support;

class ReceiptTemplateDefaults
{
    /**
     * Single source of truth for a branch that has never saved a receipt
     * template. Section keys and section_order use the model's snake_case
     * identifiers; the boolean/text fields inside each section use the
     * camelCase keys the API exposes directly.
     *
     * @return array{header:array,order_info:array,items:array,totals:array,payment:array,footer:array,section_order:array}
     */
    public static function array(): array
    {
        return [
            'header' => [
                'showLogo' => true,
                'showCafeName' => true,
                'showBranchName' => true,
                'showAddress' => true,
                'showPhone' => true,
            ],
            'order_info' => [
                'showOrderNumber' => true,
                'showDateTime' => true,
                'showCashier' => true,
                'showCustomer' => false,
                'showOrderType' => true,
            ],
            'items' => [
                'showProductName' => true,
                'showQuantity' => true,
                'showUnitPrice' => true,
                'showModifiers' => true,
                'showNotes' => true,
            ],
            'totals' => [
                'showSubtotal' => true,
                'showDiscount' => true,
                'showTax' => true,
                'showTotal' => true,
            ],
            'payment' => [
                'showPaymentMethod' => true,
                'showPaidAmount' => true,
                'showChange' => true,
            ],
            'footer' => [
                'enabled' => true,
                'text' => 'Thank you for visiting',
            ],
            'section_order' => ['header', 'order_info', 'items', 'totals', 'payment', 'footer'],
        ];
    }
}
