<?php

namespace App\Http\Requests\CafeConfiguration;

use Illuminate\Foundation\Http\FormRequest;

class UpdateBranchRequest extends FormRequest
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
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'address' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:255'],
            'timezone' => ['sometimes', 'required', 'string', 'timezone:all'],
            'posInventoryWarehouseId' => ['sometimes', 'nullable', 'integer'],
            'posCashFinancialLocationId' => ['sometimes', 'required', 'integer'],
            'shiftCloseDestinationFinancialLocationId' => ['sometimes', 'nullable', 'integer'],
            'shiftClosingFloatAmount' => ['sometimes', 'required', 'numeric', 'min:0'],
            'shiftCloseTime' => ['sometimes', 'nullable', 'date_format:H:i'],
            'receiptPrintingEnabled' => ['sometimes', 'boolean'],
            'defaultPaperWidth' => ['sometimes', 'required', 'in:58mm,80mm'],
            'autoPrintAfterPayment' => ['sometimes', 'boolean'],
            'defaultPrinterName' => ['sometimes', 'nullable', 'string', 'max:255'],
            'defaultPrinterIp' => ['sometimes', 'nullable', 'string', 'max:253', function (string $attribute, mixed $value, \Closure $fail): void {
                if ($value !== null && ! $this->isValidPrinterHost((string) $value)) {
                    $fail('Enter a valid printer IP address or host name.');
                }
            }],
            'defaultPrinterPort' => ['sometimes', 'nullable', 'integer', 'between:1,65535'],
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

    private function isValidPrinterHost(string $host): bool
    {
        $host = trim($host);
        if ($host === '' || preg_match('/\s/', $host)) {
            return false;
        }
        if (filter_var($host, FILTER_VALIDATE_IP) !== false) {
            return true;
        }

        return (bool) preg_match('/^(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/', $host);
    }
}
