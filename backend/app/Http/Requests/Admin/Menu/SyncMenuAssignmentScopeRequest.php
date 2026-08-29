<?php

namespace App\Http\Requests\Admin\Menu;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Validation\Rule;

class SyncMenuAssignmentScopeRequest extends MenuRequest
{
    public function rules(): array
    {
        return [
            'branchId' => ['required', 'integer'],
            'channel' => ['required', Rule::enum(SalesChannel::class)],
            'assignments' => ['required', 'array'],
            'assignments.*.menuId' => ['required', 'integer', 'distinct'],
            'assignments.*.priority' => ['nullable', 'integer'],
            'assignments.*.isActive' => ['nullable', 'boolean'],
        ];
    }
}
