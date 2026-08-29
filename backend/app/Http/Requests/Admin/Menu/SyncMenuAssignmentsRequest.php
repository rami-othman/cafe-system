<?php

namespace App\Http\Requests\Admin\Menu;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Validation\Rule;

class SyncMenuAssignmentsRequest extends MenuRequest
{
    public function rules(): array
    {
        return ['assignments' => ['required', 'array'], 'assignments.*.branchId' => ['required', 'integer'], 'assignments.*.channel' => ['required', Rule::enum(SalesChannel::class)], 'assignments.*.priority' => ['nullable', 'integer'], 'assignments.*.isActive' => ['nullable', 'boolean']];
    }
}
