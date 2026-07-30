<?php

namespace App\Http\Requests\Admin\Catalog;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SyncProductVariantPriceOverridesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tenantId' => ['prohibited'],
            'variantId' => ['prohibited'],
            'scopeKey' => ['prohibited'],
            'overrides' => ['present', 'array'],
            'overrides.*.tenantId' => ['prohibited'],
            'overrides.*.variantId' => ['prohibited'],
            'overrides.*.scopeKey' => ['prohibited'],
            'overrides.*.scopeType' => ['required', Rule::in(['branch', 'channel', 'branch_channel'])],
            'overrides.*.branchId' => ['nullable', 'integer'],
            'overrides.*.channel' => ['nullable', Rule::enum(SalesChannel::class)],
            'overrides.*.overridePrice' => ['required', 'numeric', 'min:0'],
            'overrides.*.isActive' => ['nullable', 'boolean'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            $keys = [];
            foreach ($this->input('overrides', []) as $index => $override) {
                $scopeType = $override['scopeType'] ?? null;
                $branchId = $override['branchId'] ?? null;
                $channel = $override['channel'] ?? null;
                $valid = match ($scopeType) {
                    'branch' => $branchId !== null && $channel === null,
                    'channel' => $branchId === null && $channel !== null,
                    'branch_channel' => $branchId !== null && $channel !== null,
                    default => false,
                };
                if (! $valid) {
                    $validator->errors()->add("overrides.$index.scopeType", 'The scope type must match the supplied branch and channel.');

                    continue;
                }
                $key = $this->scopeKey($branchId, $channel);
                if (in_array($key, $keys, true)) {
                    $validator->errors()->add("overrides.$index.scopeType", 'Duplicate price override scopes are not allowed.');
                }
                $keys[] = $key;
            }
        });
    }

    private function scopeKey(?int $branchId, ?string $channel): string
    {
        return 'branch:'.($branchId ?? '*').'|channel:'.($channel ?? '*');
    }
}
