<?php

namespace App\Http\Requests\Customer;

use App\Services\BranchAccessService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

final class ListCustomerOrdersRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'from' => ['sometimes', 'date_format:Y-m-d'],
            'to' => ['sometimes', 'date_format:Y-m-d', 'after_or_equal:from'],
            'branchId' => ['sometimes', 'integer'],
            'status' => ['sometimes', 'in:draft,held,paid,cancelled'],
            'paymentStatus' => ['sometimes', 'in:unpaid,paid,partially_refunded,refunded'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'perPage' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator): void {
            if (array_diff(array_keys($this->query()), ['from', 'to', 'branchId', 'status', 'paymentStatus', 'page', 'perPage']) !== []) {
                $validator->errors()->add('query', 'Unknown customer order filters were submitted.');
            }
            if ($this->filled('branchId')) {
                $actor = $this->attributes->get('auth_user');
                $allowed = $actor ? app(BranchAccessService::class)->accessibleBranchIds($actor) : [];
                if (! in_array((int) $this->query('branchId'), $allowed, true)) {
                    $validator->errors()->add('branchId', 'The selected branch is unavailable.');
                }
            }
        });
    }
}
