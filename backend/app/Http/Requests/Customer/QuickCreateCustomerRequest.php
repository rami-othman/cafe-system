<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class QuickCreateCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:50'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'groupIds' => ['sometimes', 'array'],
            'groupIds.*' => ['integer', 'distinct', 'min:1'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator): void {
            if (array_diff(array_keys($this->all()), ['name', 'phone', 'notes', 'groupIds']) !== []) {
                $validator->errors()->add('payload', 'Quick-create accepts only its operational fields.');
            }
        });
    }
}
