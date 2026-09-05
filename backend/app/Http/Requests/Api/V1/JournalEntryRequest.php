<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class JournalEntryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'entryDate' => ['required', 'date_format:Y-m-d'],
            'branchId' => ['nullable', 'integer'],
            'sourceType' => ['nullable', 'string', 'max:80'],
            'sourceId' => ['nullable', 'integer'],
            'description' => ['nullable', 'string', 'max:4000'],
            'lines' => ['required', 'array', 'min:2', 'max:100'],
            'lines.*.accountId' => ['required', 'integer'],
            'lines.*.description' => ['nullable', 'string', 'max:1000'],
            'lines.*.debit' => ['nullable', 'regex:/^\d+(\.\d{1,2})?$/'],
            'lines.*.credit' => ['nullable', 'regex:/^\d+(\.\d{1,2})?$/'],
        ];
    }
}
