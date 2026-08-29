<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use App\Support\InventoryUnitCatalog;

class StockMovementRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['warehouseId' => ['required', 'integer'], 'itemId' => ['required', 'integer'], 'branchId' => ['nullable', 'integer'], 'type' => ['required', Rule::in(['opening_balance', 'stock_in', 'stock_out', 'adjustment_in', 'adjustment_out', 'waste', 'stock_count_variance', 'transfer_out', 'transfer_in', 'sale_consumption', 'return_in', 'return_out'])], 'quantity' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'], 'unit' => ['nullable', 'string', Rule::in(InventoryUnitCatalog::codes())], 'unitCost' => ['nullable', 'regex:/^\d+(\.\d{1,4})?$/'], 'idempotencyKey' => ['nullable', 'string', 'min:1', 'max:120'], 'reason' => ['nullable', 'string', 'max:4000'], 'referenceType' => ['nullable', 'string', 'max:80'], 'referenceId' => ['nullable', 'integer'], 'occurredAt' => ['nullable', 'date']];
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('unit')) $this->merge(['unit' => InventoryUnitCatalog::normalize($this->input('unit'))]);
    }
}
