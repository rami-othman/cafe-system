<?php

namespace App\Http\Requests\Api\V1;

use App\Support\InventoryUnitCatalog;
use App\Support\InventoryDecimal;
use App\Support\TenantContext;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class InventoryItemUnitConversionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'sourceUnit' => ['required', Rule::in(InventoryUnitCatalog::codes())],
            'targetUnit' => ['required', 'different:sourceUnit', Rule::in(InventoryUnitCatalog::codes())],
            'factor' => ['required', 'regex:/^\d+(\.\d{1,6})?$/'],
            'isActive' => ['required', 'boolean'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'sourceUnit' => InventoryUnitCatalog::normalize($this->input('sourceUnit')),
            'targetUnit' => InventoryUnitCatalog::normalize($this->input('targetUnit')),
        ]);
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            if ($validator->errors()->isEmpty() && InventoryDecimal::factor($this->input('factor')) <= 0) {
                $validator->errors()->add('factor', 'The conversion factor must be greater than zero.');
            }
            if ($validator->errors()->isNotEmpty()) {
                return;
            }

            $itemId = (int) $this->route('item');
            $conversionId = (int) $this->route('conversion', 0);
            $exists = DB::table('inventory_item_unit_conversions')
                ->where('tenant_id', TenantContext::id($this))
                ->where('inventory_item_id', $itemId)
                ->where('source_unit', $this->input('sourceUnit'))
                ->where('target_unit', $this->input('targetUnit'))
                ->when($conversionId > 0, fn ($query) => $query->where('id', '!=', $conversionId))
                ->exists();
            if ($exists) {
                $validator->errors()->add('targetUnit', 'This conversion already exists for the selected item.');
            }
        });
    }
}
