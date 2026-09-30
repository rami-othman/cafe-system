<?php

namespace App\Http\Requests\Admin\Menu;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PreviewMenuPriceAdjustmentRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return ['branchId' => ['required', 'integer'], 'channel' => ['required', Rule::enum(SalesChannel::class)],
            'operation' => ['required', Rule::in(['manual_changes', 'percentage_increase', 'fixed_increase', 'percentage_decrease', 'fixed_decrease'])],
            'amount' => ['nullable', 'string', 'regex:/^\d+(?:\.\d{1,20})?$/'], 'roundingMode' => ['nullable', Rule::in(['no_rounding', 'round_up', 'round_down'])], 'roundingStep' => ['nullable', 'string', 'regex:/^\d+(?:\.\d{1,2})?$/'],
            'items' => ['nullable', 'array', 'min:1'], 'items.*' => ['array'], 'items.*.variantId' => ['required_with:items', 'integer', 'distinct'], 'items.*.action' => ['required_with:items', Rule::in(['set', 'reset'])], 'items.*.price' => ['nullable', 'string', 'regex:/^\d+(?:\.\d{1,2})?$/'],
            'tenantId' => ['prohibited'], 'targets' => ['prohibited'], 'variantIds' => ['prohibited']];
    }

    public function after(): array
    {
        return [function ($validator): void {
            $d = $this->all(); $manual = ($d['operation'] ?? null) === 'manual_changes';
            if ($manual) {
                foreach (['amount', 'roundingMode', 'roundingStep'] as $field) if (array_key_exists($field, $d)) $validator->errors()->add($field, 'Bulk controls are prohibited for manual changes.');
                if (empty($d['items'])) $validator->errors()->add('items', 'Manual changes require one or more items.');
                // Laravel evaluates wildcard rules separately.  Do not assume
                // a malformed item is an array while adding cross-field
                // errors, otherwise invalid JSON shapes become a 500 here.
                if (! isset($d['items']) || ! is_array($d['items'])) return;
                foreach ($d['items'] as $i => $item) {
                    if (! is_array($item)) continue;
                    if (($item['action'] ?? null) === 'set' && (! array_key_exists('price', $item) || $item['price'] === null)) $validator->errors()->add("items.$i.price", 'Price is required for set.');
                    if (($item['action'] ?? null) === 'reset' && array_key_exists('price', $item)) $validator->errors()->add("items.$i.price", 'Price is prohibited for reset.');
                }
            } else {
                if (array_key_exists('items', $d)) $validator->errors()->add('items', 'Manual items are prohibited for bulk changes.');
                if (! array_key_exists('amount', $d)) $validator->errors()->add('amount', 'Amount is required.');
                if (! array_key_exists('roundingMode', $d)) $validator->errors()->add('roundingMode', 'Rounding mode is required.');
            }
        }];
    }
}
