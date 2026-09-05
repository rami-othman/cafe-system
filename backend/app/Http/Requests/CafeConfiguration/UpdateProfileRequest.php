<?php

namespace App\Http\Requests\CafeConfiguration;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProfileRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        foreach (['name', 'email', 'phone', 'timezone'] as $field) {
            if (is_string($this->input($field))) {
                $this->merge([$field => trim($this->input($field))]);
            }
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:255'],
            'timezone' => ['required', 'string', 'timezone:all'],
            ...$this->prohibitedTenantFields(),
        ];
    }

    /** @return array<string, array<int, string>> */
    private function prohibitedTenantFields(): array
    {
        return [
            'id' => ['prohibited'],
            'tenantId' => ['prohibited'],
            'tenant_id' => ['prohibited'],
            'ownerId' => ['prohibited'],
            'owner_id' => ['prohibited'],
            'slug' => ['prohibited'],
            'status' => ['prohibited'],
            'plan' => ['prohibited'],
            'currency' => ['prohibited'],
            'taxRate' => ['prohibited'],
            'tax_rate' => ['prohibited'],
            'logoUrl' => ['prohibited'],
            'logo_url' => ['prohibited'],
            'deletedAt' => ['prohibited'],
            'deleted_at' => ['prohibited'],
        ];
    }
}
