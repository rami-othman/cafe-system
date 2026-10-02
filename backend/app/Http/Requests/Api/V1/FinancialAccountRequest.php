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
            // On create the code is optional: a blank or already-used code is replaced by the
            // next free one under the parent (see FinancialAccountService::resolveCreateCode()).
            'code' => $accountId
                ? ['required', 'string', 'max:40', 'regex:/^[A-Za-z0-9_-]+$/', $code]
                : ['nullable', 'string', 'max:40', 'regex:/^[A-Za-z0-9_-]+$/'],
            'nameAr' => ['required', 'string', 'max:255'],
            'nameEn' => ['required', 'string', 'max:255'],
            'accountGroup' => ['required_without:parentAccountId', Rule::in(['assets', 'liabilities', 'equity', 'revenue', 'cost_of_sales', 'expenses'])],
            'normalBalance' => ['required_without:parentAccountId', Rule::in(['debit', 'credit'])],
            'isContra' => ['sometimes', 'boolean'],
            'categoryOverride' => ['sometimes', 'boolean'],
            'parentAccountId' => ['nullable', 'integer'],
            'isActive' => ['required', 'boolean'],
        ];
    }
}
