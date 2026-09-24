<?php

namespace App\Http\Requests\CafeConfiguration;

use Closure;
use Illuminate\Foundation\Http\FormRequest;

class UpdateReceiptTemplateRequest extends FormRequest
{
    private const SECTIONS = ['header', 'orderInfo', 'items', 'totals', 'payment', 'footer'];

    public function rules(): array
    {
        return [
            'header' => ['required', 'array'],
            'header.showLogo' => ['required', 'boolean'],
            'header.showCafeName' => ['required', 'boolean'],
            'header.showBranchName' => ['required', 'boolean'],
            'header.showAddress' => ['required', 'boolean'],
            'header.showPhone' => ['required', 'boolean'],

            'orderInfo' => ['required', 'array'],
            'orderInfo.showOrderNumber' => ['required', 'boolean'],
            'orderInfo.showDateTime' => ['required', 'boolean'],
            'orderInfo.showCashier' => ['required', 'boolean'],
            'orderInfo.showCustomer' => ['required', 'boolean'],
            'orderInfo.showOrderType' => ['required', 'boolean'],

            'items' => ['required', 'array'],
            'items.showProductName' => ['required', 'boolean'],
            'items.showQuantity' => ['required', 'boolean'],
            'items.showUnitPrice' => ['required', 'boolean'],
            'items.showModifiers' => ['required', 'boolean'],
            'items.showNotes' => ['required', 'boolean'],

            'totals' => ['required', 'array'],
            'totals.showSubtotal' => ['required', 'boolean'],
            'totals.showDiscount' => ['required', 'boolean'],
            'totals.showTax' => ['required', 'boolean'],
            'totals.showTotal' => ['required', 'boolean'],

            'payment' => ['required', 'array'],
            'payment.showPaymentMethod' => ['required', 'boolean'],
            'payment.showPaidAmount' => ['required', 'boolean'],
            'payment.showChange' => ['required', 'boolean'],

            'footer' => ['required', 'array'],
            'footer.enabled' => ['required', 'boolean'],
            'footer.text' => ['nullable', 'string', 'max:500', function (string $attribute, mixed $value, Closure $fail): void {
                if ($value !== null && strip_tags($value) !== $value) {
                    $fail('Footer text cannot contain HTML markup.');
                }
            }],

            'sectionOrder' => ['required', 'array', 'size:6', function (string $attribute, mixed $value, Closure $fail): void {
                if (! is_array($value)) {
                    return;
                }
                $expected = self::SECTIONS;
                sort($expected);
                $actual = $value;
                sort($actual);
                if ($actual !== $expected) {
                    $fail('Section order must contain each receipt section exactly once.');

                    return;
                }
                if (array_search('items', $value, true) > array_search('totals', $value, true)) {
                    $fail('Items must appear before totals in the section order.');
                }
            }],
        ];
    }
}
