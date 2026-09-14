<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

final class AddCustomerGroupMembersRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['customerIds' => ['required', 'array', 'min:1'], 'customerIds.*' => ['integer', 'min:1', 'distinct']];
    }

    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator): void {
            if (array_diff(array_keys($this->all()), ['customerIds']) !== []) {
                $validator->errors()->add('payload', 'Unknown group member fields were submitted.');
            }
        });
    }
}
