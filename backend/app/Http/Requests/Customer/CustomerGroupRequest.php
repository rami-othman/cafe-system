<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class CustomerGroupRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['name' => ['required', 'string', 'max:255'], 'isActive' => ['sometimes', 'boolean']];
    }

    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator): void {
            if (array_diff(array_keys($this->all()), ['name', 'isActive']) !== []) {
                $validator->errors()->add('payload', 'Unknown group fields were submitted.');
            }
        });
    }
}
