<?php

namespace App\Http\Controllers\Api\CafeConfiguration;

use App\Domain\Discount\DiscountAccess;
use App\Http\Controllers\Controller;
use App\Services\DiscountSettingsService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class DiscountSettingsController extends Controller
{
    public function __construct(private readonly DiscountAccess $access, private readonly DiscountSettingsService $settings) {}

    public function show(Request $request): JsonResponse
    {
        if (! $this->access->allows($request, DiscountAccess::SETTINGS_MANAGE)) {
            return $this->error('DISCOUNT_SETTINGS_FORBIDDEN', 403);
        }

        return response()->json(['data' => $this->settings->read(TenantContext::id($request))]);
    }

    public function update(Request $request): JsonResponse
    {
        if (! $this->access->allows($request, DiscountAccess::SETTINGS_MANAGE)) {
            return $this->error('DISCOUNT_SETTINGS_FORBIDDEN', 403);
        }
        $rules = [
            'expectedVersion' => ['required', 'integer', 'min:0', 'max:2147483646'],
            'automaticEnabled' => ['required', 'boolean'],
            'selectionStrategy' => ['required', Rule::in(['highest_saving', 'lowest_saving', 'priority'])],
            'combinationMode' => ['required', Rule::in(['single', 'disjoint_items'])],
            'orderDiscountBehavior' => ['required', Rule::in(['exclusive', 'after_items'])],
            'couponBehavior' => ['required', Rule::in(['exclusive', 'follow_combination_rules'])],
            'manualBehavior' => ['required', Rule::in(['exclusive', 'follow_combination_rules'])],
            'maximumTotalDiscountPercent' => ['present', 'nullable', 'numeric', 'gt:0', 'max:100', 'decimal:0,4'],
            'allowAutomaticSuppression' => ['required', 'boolean'],
            // Discount V3 Cafe Policy: optional so existing clients keep working.
            'allowMultipleDiscounts' => ['sometimes', 'required', 'boolean'],
            'stackingMode' => ['sometimes', 'required', Rule::in(DiscountSettingsService::STACKING_MODES)],
            'allowMultipleCoupons' => ['sometimes', 'required', 'boolean'],
            'allowCouponWithConfigured' => ['sometimes', 'required', 'boolean'],
            'allowOrderAfterItemDiscounts' => ['sometimes', 'required', 'boolean'],
            'maximumDiscountsPerOrder' => ['sometimes', 'required', 'integer', 'min:1', 'max:'.DiscountSettingsService::MAX_DISCOUNTS_PER_ORDER_LIMIT],
            'conflictResolution' => ['sometimes', 'required', Rule::in(DiscountSettingsService::CONFLICT_RESOLUTIONS)],
        ];
        $validator = Validator::make($request->all(), $rules);
        $validator->after(function ($validator) use ($request, $rules): void {
            foreach (array_diff(array_keys($request->all()), array_keys($rules)) as $field) {
                $validator->errors()->add($field, 'Unknown or read-only field.');
            }
            foreach (['automaticEnabled', 'allowAutomaticSuppression'] as $field) {
                if (! is_bool($request->input($field))) {
                    $validator->errors()->add($field, 'A JSON boolean is required.');
                }
            }
            foreach (['allowMultipleDiscounts', 'allowMultipleCoupons', 'allowCouponWithConfigured', 'allowOrderAfterItemDiscounts'] as $field) {
                if ($request->has($field) && ! is_bool($request->input($field))) {
                    $validator->errors()->add($field, 'A JSON boolean is required.');
                }
            }
            if (! is_int($request->input('expectedVersion'))) {
                $validator->errors()->add('expectedVersion', 'A JSON integer is required.');
            }
            if ($request->has('maximumDiscountsPerOrder') && ! is_int($request->input('maximumDiscountsPerOrder'))) {
                $validator->errors()->add('maximumDiscountsPerOrder', 'A JSON integer is required.');
            }
            if ($request->input('orderDiscountBehavior') === 'after_items' && $request->input('combinationMode') !== 'disjoint_items') {
                $validator->errors()->add('orderDiscountBehavior', 'after_items requires disjoint_items.');
            }
        });
        if ($validator->fails()) {
            return response()->json(['message' => 'Discount settings request is invalid.', 'code' => 'DISCOUNT_SETTINGS_VALIDATION_FAILED', 'errors' => $validator->errors()], 422);
        }
        $data = $validator->validated();
        try {
            return response()->json(['data' => $this->settings->save($request, TenantContext::id($request), $data)]);
        } catch (HttpException $exception) {
            if ($exception->getStatusCode() !== 409) {
                throw $exception;
            }

            return $this->error('DISCOUNT_SETTINGS_VERSION_CONFLICT', 409);
        }
    }

    private function error(string $code, int $status): JsonResponse
    {
        return response()->json(['message' => 'Discount settings request could not be completed.', 'code' => $code], $status);
    }
}
