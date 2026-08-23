<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class StockCountLineRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['itemId' => ['required', 'integer'], 'countedQuantity' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'], 'reason' => ['nullable', 'string', 'max:4000']];
    }
}
