<?php

namespace App\Http\Requests\Api\V1\Manufacturing;

use Illuminate\Foundation\Http\FormRequest;

class ConversionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'warehouseId' => ['required', 'integer'],
            'sourceItemId' => ['required', 'integer'],
            'sourceQty' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'],
            'targetItemId' => ['required', 'integer'],
            'resultQty' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'],
            'idempotencyKey' => ['nullable', 'string', 'min:1', 'max:120'],
        ];
    }
}
