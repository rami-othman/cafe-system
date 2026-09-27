<?php

namespace App\Http\Requests\Api\V1\Manufacturing;

use Illuminate\Foundation\Http\FormRequest;

class ProductionDraftRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'recipeId' => ['required', 'integer'],
            'qty' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'],
            'warehouseId' => ['required', 'integer'],
            'branchId' => ['required', 'integer'],
            'date' => ['nullable', 'date'],
            'idempotencyKey' => ['nullable', 'string', 'min:1', 'max:120'],
        ];
    }
}
