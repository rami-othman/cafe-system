<?php

namespace App\Http\Requests\Admin\Menu;

use Illuminate\Foundation\Http\FormRequest;

class ApplyMenuPriceAdjustmentRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return ['previewFingerprint' => ['required', 'string', 'size:64'], 'confirmReviewedResults' => ['required', 'boolean'], 'acknowledgeOppositeDirection' => ['nullable', 'boolean'],
            'branchId' => ['prohibited'], 'channel' => ['prohibited'], 'operation' => ['prohibited'], 'amount' => ['prohibited'], 'roundingMode' => ['prohibited'], 'roundingStep' => ['prohibited'], 'items' => ['prohibited'], 'targets' => ['prohibited'], 'tenantId' => ['prohibited']];
    }
}
