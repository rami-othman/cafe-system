<?php

namespace App\Http\Requests\CafeConfiguration;

use Illuminate\Foundation\Http\FormRequest;

class StoreBranchRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if (is_string($this->input('name'))) {
            $this->merge(['name' => trim($this->input('name'))]);
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'address' => ['nullable', 'string', 'max:5000'],
            'phone' => ['nullable', 'string', 'max:255'],
            'timezone' => ['required', 'string', 'timezone:all'],
            'tenantId' => ['prohibited'],
            'tenant_id' => ['prohibited'],
            'ownerId' => ['prohibited'],
            'owner_id' => ['prohibited'],
            'currency' => ['prohibited'],
            'isActive' => ['prohibited'],
            'is_active' => ['prohibited'],
            'deletedAt' => ['prohibited'],
            'deleted_at' => ['prohibited'],
        ];
    }
}
