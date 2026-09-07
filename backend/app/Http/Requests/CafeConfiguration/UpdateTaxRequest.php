<?php

namespace App\Http\Requests\CafeConfiguration;

use Illuminate\Foundation\Http\FormRequest;

class UpdateTaxRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            // decimal:0,6 matches tenants.tax_rate decimal(8,6). The API is
            // deliberately fractional: 1 is 100%, while 8 is invalid.
            'taxRate' => ['required', 'numeric', 'decimal:0,6', 'between:0,1'],
            'tax_rate' => ['prohibited'],
            'tenantId' => ['prohibited'],
            'tenant_id' => ['prohibited'],
            'ownerId' => ['prohibited'],
            'owner_id' => ['prohibited'],
            'id' => ['prohibited'],
            'slug' => ['prohibited'],
            'status' => ['prohibited'],
            'plan' => ['prohibited'],
            'currency' => ['prohibited'],
            'logoUrl' => ['prohibited'],
            'logo_url' => ['prohibited'],
            'deletedAt' => ['prohibited'],
            'deleted_at' => ['prohibited'],
        ];
    }
}
