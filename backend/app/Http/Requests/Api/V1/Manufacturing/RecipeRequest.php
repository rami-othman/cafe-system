<?php

namespace App\Http\Requests\Api\V1\Manufacturing;

use App\Support\InventoryUnitCatalog;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RecipeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('outputUnit')) {
            $this->merge(['outputUnit' => InventoryUnitCatalog::normalize($this->input('outputUnit'))]);
        }
        if (is_array($this->input('lines'))) {
            $this->merge(['lines' => collect($this->input('lines'))->map(function ($line) {
                if (is_array($line) && array_key_exists('unit', $line)) {
                    $line['unit'] = InventoryUnitCatalog::normalize($line['unit']);
                }

                return $line;
            })->all()]);
        }
    }

    public function rules(): array
    {
        return [
            'branchId' => ['required', 'integer'],
            'productItemId' => ['required', 'integer'],
            'outputQuantity' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'],
            'outputUnit' => ['required', Rule::in(InventoryUnitCatalog::codes())],
            'shelfLifeValue' => ['nullable', 'integer', 'min:1'],
            'shelfLifeUnit' => ['nullable', Rule::in(['hours', 'days'])],
            'estimatedExtraCosts' => ['nullable', 'array'],
            'estimatedExtraCosts.*.type' => ['required_with:estimatedExtraCosts', 'string', 'max:60'],
            'estimatedExtraCosts.*.amount' => ['required_with:estimatedExtraCosts', 'regex:/^\d+(\.\d{1,2})?$/'],
            'estimatedExtraCosts.*.note' => ['nullable', 'string', 'max:255'],
            'lines' => ['required', 'array', 'min:1'],
            'lines.*.inventoryItemId' => ['required', 'integer'],
            'lines.*.quantity' => ['required', 'regex:/^\d+(\.\d{1,6})?$/'],
            'lines.*.unit' => ['required', Rule::in(InventoryUnitCatalog::codes())],
        ];
    }
}
