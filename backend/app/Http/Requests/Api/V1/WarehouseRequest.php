<?php

namespace App\Http\Requests\Api\V1;

use App\Support\TenantContext;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class WarehouseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $tenantId = TenantContext::id($this);
        $warehouseId = (int) $this->route('warehouse', 0);
        $code = Rule::unique('warehouses', 'code')->where(fn ($query) => $query->where('tenant_id', $tenantId));
        if ($warehouseId) {
            $code->ignore($warehouseId);
        }

        return [
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:40', 'regex:/^[A-Za-z0-9_-]+$/', $code],
            'type' => ['required', Rule::in(['central', 'branch_main', 'bar', 'kitchen', 'other'])],
            'branchId' => ['nullable', 'integer'],
            'isActive' => ['required', 'boolean'],
            'notes' => ['nullable', 'string', 'max:4000'],
        ];
    }
}
