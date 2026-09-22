<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;

class PreviewCustomerImportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['file' => ['required', 'file', 'max:5120']];
    }

    protected function prepareForValidation(): void
    {
        if ($this->request->has('tenantId') || $this->headers->has('X-Tenant-Id')) {
            $this->request->remove('tenantId');
        }
    }
}
