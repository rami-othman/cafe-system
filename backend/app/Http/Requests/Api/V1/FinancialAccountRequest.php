<?php

namespace App\Http\Requests\Api\V1;

use App\Support\TenantContext;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class FinancialAccountRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $tenantId = TenantContext::id($this);
        $accountId = (int) $this->route('account', 0);
        $code = Rule::unique('financial_accounts', 'code')->where(fn ($query) => $query->where('tenant_id', $tenantId));
        if ($accountId) {
            $code->ignore($accountId);
        }

        return [
            'code' => ['required', 'string', 'max:40', 'regex:/^[A-Za-z0-9_-]+$/', $code],
            'nameAr' => ['required', 'string', 'max:255'],
            'nameEn' => ['required', 'string', 'max:255'],
            'accountGroup' => ['required', Rule::in(['assets', 'liabilities', 'equity', 'revenue', 'cost_of_sales', 'expenses'])],
            'normalBalance' => ['required', Rule::in(['debit', 'credit'])],
            'parentAccountId' => ['nullable', 'integer'],
            'isActive' => ['required', 'boolean'],
        ];
    }
}
