<?php

namespace App\Http\Requests\Admin\Menu;

use App\Domain\Menu\Enums\SalesChannel;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ValidateMenuRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['branchId' => ['required', 'integer'], 'channel' => ['required', Rule::enum(SalesChannel::class)], 'at' => ['nullable', 'date']];
    }
}
