<?php

namespace App\Http\Requests\Admin\Menu;

use App\Domain\Menu\Enums\MenuStatus;
use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Validation\Rule;

class ListMenusRequest extends MenuRequest
{
    public function rules(): array
    {
        return ['search' => ['nullable', 'string'], 'status' => ['nullable', Rule::in([...array_map(fn ($e) => $e->value, MenuStatus::cases()), 'all'])], 'branchId' => ['nullable', 'integer'], 'channel' => ['nullable', Rule::enum(SalesChannel::class)], 'hasAssignments' => ['nullable', 'boolean'], 'page' => ['nullable', 'integer', 'min:1'], 'perPage' => ['nullable', 'integer', 'min:1', 'max:100'], 'sort' => ['nullable', Rule::in(['name', 'priority', 'created_at', 'updated_at'])], 'direction' => ['nullable', Rule::in(['asc', 'desc'])]];
    }
}
