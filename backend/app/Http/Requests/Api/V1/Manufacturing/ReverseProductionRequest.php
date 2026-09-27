<?php

namespace App\Http\Requests\Api\V1\Manufacturing;

use Illuminate\Foundation\Http\FormRequest;

class ReverseProductionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'min:3', 'max:1000'],
            'idempotencyKey' => ['nullable', 'string', 'min:1', 'max:120'],
        ];
    }
}
