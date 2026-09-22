<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class CommitCustomerImportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['createMissingGroups' => ['required', 'boolean']];
    }

    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator): void {
            $unknown = array_diff(array_keys($this->all()), ['createMissingGroups']);
            if ($unknown !== []) {
                $validator->errors()->add('payload', 'Unknown or prohibited import fields were submitted.');
            }
        });
    }
}
