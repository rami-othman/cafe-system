<?php

namespace App\Http\Requests\Admin\Menu;

use Illuminate\Foundation\Http\FormRequest;

class ShowMenuPriceAdjustmentRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array { return ['tenantId' => ['prohibited']]; }
}
