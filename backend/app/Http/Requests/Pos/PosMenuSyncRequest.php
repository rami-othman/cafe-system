<?php

namespace App\Http\Requests\Pos;

use Illuminate\Foundation\Http\FormRequest;

class PosMenuSyncRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'branchId' => ['required', 'integer'],
            'knownVersionId' => ['nullable', 'integer'],
            // POS is intentionally bound to its server-side sales channel.
            'channel' => ['prohibited'],
        ];
    }
}
