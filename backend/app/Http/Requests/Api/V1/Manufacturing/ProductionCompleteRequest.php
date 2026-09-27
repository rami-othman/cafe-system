<?php

namespace App\Http\Requests\Api\V1\Manufacturing;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ProductionCompleteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'actualQty' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'],
            'date' => ['nullable', 'date'],
            'consumption' => ['nullable', 'array'],
            'consumption.*.materialId' => ['required_with:consumption', 'integer', 'distinct'],
            'consumption.*.actual' => ['nullable', 'regex:/^\d+(\.\d{1,3})?$/'],
            'waste' => ['nullable', 'array'],
            'waste.qty' => ['nullable', 'regex:/^\d+(\.\d{1,3})?$/'],
            'waste.unit' => ['nullable', 'string', 'max:30'],
            'waste.reason' => ['nullable', Rule::in(['احتراق', 'كسر', 'انسكاب', 'خطأ تحضير', 'تجربة', 'جودة غير مطابقة', 'آخر'])],
            'waste.notes' => ['nullable', 'string', 'max:1000'],
            'additionalCosts' => ['nullable', 'array'],
            'additionalCosts.*.type' => ['required_with:additionalCosts', 'string', 'max:60'],
            'additionalCosts.*.amount' => ['required_with:additionalCosts', 'regex:/^\d+(\.\d{1,2})?$/'],
            'additionalCosts.*.note' => ['nullable', 'string', 'max:255'],
            'idempotencyKey' => ['nullable', 'string', 'min:1', 'max:120'],
        ];
    }
}
