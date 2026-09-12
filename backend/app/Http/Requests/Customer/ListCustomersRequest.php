<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class ListCustomersRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['search' => ['sometimes', 'string', 'max:255'], 'status' => ['sometimes', 'in:active,inactive,archived,all'], 'groupId' => ['sometimes', 'integer'], 'page' => ['sometimes', 'integer', 'min:1'], 'perPage' => ['sometimes', 'integer', 'min:1', 'max:100']];
    }

    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator): void {
            if (array_diff(array_keys($this->query()), ['search', 'status', 'groupId', 'page', 'perPage']) !== []) {
                $validator->errors()->add('query', 'Unknown customer list filters were submitted.');
            }
        });
    }
}
