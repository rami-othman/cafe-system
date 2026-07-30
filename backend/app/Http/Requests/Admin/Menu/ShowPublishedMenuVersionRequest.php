<?php

namespace App\Http\Requests\Admin\Menu;

use Illuminate\Foundation\Http\FormRequest;

class ShowPublishedMenuVersionRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if ($this->has('includePayload')) {
            $this->merge(['includePayload' => filter_var($this->input('includePayload'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE)]);
        }
    }

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['includePayload' => ['nullable', 'boolean']];
    }
}
