<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class StockCountRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['warehouseId' => ['required', 'integer'], 'countDate' => ['required', 'date_format:Y-m-d'], 'notes' => ['nullable', 'string', 'max:4000']];
    }
}
