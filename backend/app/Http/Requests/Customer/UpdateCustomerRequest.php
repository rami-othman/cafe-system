<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class UpdateCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'birthDate' => ['nullable', 'date_format:Y-m-d'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'isActive' => ['sometimes', 'boolean'],
            'phones' => ['sometimes', 'array'],
            'phones.*' => ['required', 'array'],
            'phones.*.rawNumber' => ['required', 'string', 'max:50'],
            'phones.*.type' => ['sometimes', 'string', 'max:30'],
            'phones.*.isPrimary' => ['required', 'boolean'],
            'groupIds' => ['sometimes', 'array'],
            'groupIds.*' => ['integer', 'distinct'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator): void {
            $unknown = array_diff(array_keys($this->all()), ['name', 'email', 'birthDate', 'notes', 'isActive', 'phones', 'groupIds']);
            if ($unknown !== []) {
                $validator->errors()->add('payload', 'Unknown or prohibited customer fields were submitted.');
            }
            foreach ((array) $this->input('phones', []) as $phone) {
                if (array_diff(array_keys((array) $phone), ['rawNumber', 'type', 'isPrimary']) !== []) {
                    $validator->errors()->add('phones', 'Phone identity fields are server-generated.');
                }
            }
        });
    }
}
