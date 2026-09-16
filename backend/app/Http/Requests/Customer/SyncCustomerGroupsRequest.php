<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class SyncCustomerGroupsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['groupIds' => ['present', 'array'], 'groupIds.*' => ['integer', 'distinct']];
    }

    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator): void {
            if (array_diff(array_keys($this->all()), ['groupIds']) !== []) {
                $validator->errors()->add('payload', 'Unknown membership fields were submitted.');
            }
        });
    }
}
