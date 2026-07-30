<?php

namespace App\Http\Requests\Admin\Menu;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Validation\Rule;

class SyncMenuAvailabilityRulesRequest extends MenuRequest
{
    public function rules(): array
    {
        return ['rules' => ['required', 'array'], 'rules.*.branchId' => ['nullable', 'integer'], 'rules.*.channel' => ['nullable', Rule::enum(SalesChannel::class)], 'rules.*.dayOfWeek' => ['nullable', 'integer', 'between:0,6'], 'rules.*.startTime' => ['nullable', 'date_format:H:i'], 'rules.*.endTime' => ['nullable', 'date_format:H:i'], 'rules.*.startDate' => ['nullable', 'date'], 'rules.*.endDate' => ['nullable', 'date'], 'rules.*.priority' => ['nullable', 'integer'], 'rules.*.isActive' => ['nullable', 'boolean']];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            foreach ($this->input('rules', []) as $index => $rule) {
                if (array_key_exists('startTime', $rule) !== array_key_exists('endTime', $rule) || (($rule['startTime'] ?? null) === null) !== (($rule['endTime'] ?? null) === null)) {
                    $validator->errors()->add("rules.$index.startTime", 'Start and end time must be supplied together.');
                } elseif (($rule['startTime'] ?? null) === ($rule['endTime'] ?? null) && ($rule['startTime'] ?? null) !== null) {
                    $validator->errors()->add("rules.$index.endTime", 'Start and end time must differ.');
                }
                if (! empty($rule['startDate']) && ! empty($rule['endDate']) && $rule['startDate'] > $rule['endDate']) {
                    $validator->errors()->add("rules.$index.endDate", 'The end date must be after or equal to the start date.');
                }
            }
        });
    }
}
