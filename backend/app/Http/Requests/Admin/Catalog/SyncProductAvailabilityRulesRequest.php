<?php

namespace App\Http\Requests\Admin\Catalog;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SyncProductAvailabilityRulesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tenantId' => ['prohibited'],
            'productId' => ['prohibited'],
            'rules' => ['present', 'array'],
            'rules.*.id' => ['prohibited'],
            'rules.*.tenantId' => ['prohibited'],
            'rules.*.productId' => ['prohibited'],
            'rules.*.productVariantId' => ['nullable', 'integer'],
            'rules.*.branchId' => ['nullable', 'integer'],
            'rules.*.channel' => ['nullable', Rule::enum(SalesChannel::class)],
            'rules.*.dayOfWeek' => ['nullable', 'integer', 'between:0,6'],
            'rules.*.startTime' => ['nullable', 'date_format:H:i'],
            'rules.*.endTime' => ['nullable', 'date_format:H:i'],
            'rules.*.startDate' => ['nullable', 'date_format:Y-m-d'],
            'rules.*.endDate' => ['nullable', 'date_format:Y-m-d'],
            'rules.*.priority' => ['nullable', 'integer'],
            'rules.*.isActive' => ['nullable', 'boolean'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            $keys = [];
            foreach ($this->input('rules', []) as $index => $rule) {
                $start = $rule['startTime'] ?? null;
                $end = $rule['endTime'] ?? null;
                if (($start === null) !== ($end === null)) {
                    $validator->errors()->add("rules.$index.startTime", 'Start and end time must be supplied together.');
                }
                if ($start !== null && $start === $end) {
                    $validator->errors()->add("rules.$index.endTime", 'Start and end time must differ.');
                }
                if (! empty($rule['startDate']) && ! empty($rule['endDate']) && $rule['startDate'] > $rule['endDate']) {
                    $validator->errors()->add("rules.$index.endDate", 'The end date must be after or equal to the start date.');
                }
                $key = $this->canonicalKey($rule);
                if (in_array($key, $keys, true)) {
                    $validator->errors()->add("rules.$index", 'Duplicate availability rules are not allowed.');
                }
                $keys[] = $key;
            }
        });
    }

    private function canonicalKey(array $rule): string
    {
        return implode('|', [
            $rule['productVariantId'] ?? '*',
            $rule['branchId'] ?? '*',
            $rule['channel'] ?? '*',
            $rule['dayOfWeek'] ?? '*',
            $rule['startTime'] ?? '*',
            $rule['endTime'] ?? '*',
            $rule['startDate'] ?? '*',
            $rule['endDate'] ?? '*',
        ]);
    }
}
