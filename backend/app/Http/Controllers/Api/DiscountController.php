<?php

namespace App\Http\Controllers\Api;

use App\Domain\Discount\DiscountAccess;
use App\Domain\Menu\Enums\SalesChannel;
use App\Exceptions\OrderLifecycleException;
use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\CouponAttemptGuard;
use App\Services\CouponCodeGenerator;
use App\Services\DiscountBundleVariantService;
use App\Services\DiscountEligibilityService;
use App\Services\DiscountEngineProtocol;
use App\Services\DiscountProductVariantService;
use App\Services\DiscountResolutionService;
use App\Services\OperationalAuditService;
use App\Services\OrderLifecyclePolicy;
use App\Services\PosPricingService;
use App\Support\TenantContext;
use Brick\Math\BigDecimal;
use Brick\Math\Exception\MathException;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class DiscountController extends Controller
{
    /** follow_cafe_policy may combine only as the cafe policy permits; exclusive never combines. */
    public const COMBINATION_BEHAVIORS = ['follow_cafe_policy', 'exclusive'];

    public function __construct(
        private readonly PosPricingService $pricing,
        private readonly OrderLifecyclePolicy $lifecycle,
        private readonly DiscountEligibilityService $eligibility,
        private readonly DiscountAccess $access,
        private readonly OperationalAuditService $audit,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $query = $this->discountQuery($tenantId);
        $revealCodes = $this->access->canSeeCouponCodes($request);

        if ($request->filled('search')) {
            $search = '%'.strtolower((string) $request->query('search')).'%';
            $query->where(function (Builder $query) use ($search, $revealCodes): void {
                $query->whereRaw('LOWER(name) LIKE ?', [$search])
                    ->orWhereRaw('LOWER(conditions) LIKE ?', [$search]);
                // A code search by a view-only actor would be a coupon-existence oracle.
                if ($revealCodes) {
                    $query->orWhereRaw('LOWER(code) LIKE ?', [$search]);
                }
            });
        }

        $discounts = $query->orderBy('id')->get()
            ->filter(fn (object $discount) => ! $request->filled('status') || $this->status($tenantId, $discount) === $request->query('status'))
            ->map(fn (object $discount) => $this->serializeManagementDiscount($tenantId, $discount, $revealCodes))
            ->values();

        return response()->json(['data' => $discounts]);
    }

    public function metrics(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $now = now();

        // The management dashboard represents only configured Discount
        // policies that were applied to completed sales, never seeded display
        // metadata or a free-form POS discount.
        $actualSavedValue = DB::table('order_discounts')
            ->join('orders', function ($join): void {
                $join->on('orders.id', '=', 'order_discounts.order_id')
                    ->on('orders.tenant_id', '=', 'order_discounts.tenant_id');
            })
            ->where('order_discounts.tenant_id', $tenantId)
            ->whereNotNull('order_discounts.discount_id')
            ->whereIn('orders.payment_status', ['paid', 'partially_refunded', 'refunded'])
            ->where('orders.status', '!=', 'cancelled')
            ->whereNull('orders.deleted_at')
            ->whereBetween('orders.closed_at', [$now->copy()->startOfMonth(), $now->copy()->endOfMonth()])
            ->sum('order_discounts.discount_amount');

        return response()->json(['data' => [
            'actualSavedValueThisMonth' => (float) $actualSavedValue,
        ]]);
    }

    public function show(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $discount), $this->access->canSeeCouponCodes($request))]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $this->validatedManagementData($request, $tenantId);
        try {
            $id = DB::transaction(function () use ($request, $tenantId, $data): int {
                app(DiscountResolutionService::class)->lock($tenantId);
                $id = (int) DB::table('discounts')->insertGetId($this->discountPayload($tenantId, $data));
                $this->assertTenantTargets($tenantId, $data);
                $this->syncTargets($tenantId, $id, $data);
                $this->auditDiscount($request, $tenantId, 'discount.created', $id, null);

                return $id;
            });
        } catch (QueryException $exception) {
            $this->throwFriendlyCodeConflict($exception);
        }

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $id), $this->access->canSeeCouponCodes($request))], 201);
    }

    public function update(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findManagedDiscount($tenantId, $discount);
        $data = $this->validatedManagementData($request, $tenantId, $discount);

        try {
            DB::transaction(function () use ($request, $tenantId, $discount, $data): void {
                app(DiscountResolutionService::class)->lock($tenantId);
                abort_unless(DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->whereNull('deleted_at')->lockForUpdate()->first(), 404);
                if ($data['applicationMode'] === 'automatic' && ! array_key_exists('code', $data)
                    && DB::table('discounts')->where('id', $discount)->value('code') !== null) {
                    throw ValidationException::withMessages(['code' => 'Explicitly clear the coupon code when changing to Automatic.']);
                }
                $this->assertTenantTargets($tenantId, $data);
                $before = $this->lockedManagementState($tenantId, $discount);
                DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->update($this->discountPayload($tenantId, $data, false));
                $this->syncTargets($tenantId, $discount, $data);
                $this->auditDiscount($request, $tenantId, 'discount.updated', $discount, $before);
            });
        } catch (QueryException $exception) {
            $this->throwFriendlyCodeConflict($exception);
        }

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $discount), $this->access->canSeeCouponCodes($request))]);
    }

    public function updateStatus(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findManagedDiscount($tenantId, $discount);
        $data = $request->validate(['isActive' => ['required', 'boolean']]);
        DB::transaction(function () use ($request, $tenantId, $discount, $data): void {
            app(DiscountResolutionService::class)->lock($tenantId);
            $before = $this->lockedManagementState($tenantId, $discount);
            DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->update([
                'is_active' => $data['isActive'],
                'updated_at' => now(),
            ]);
            if ((bool) $before['isActive'] !== (bool) $data['isActive']) {
                $this->auditDiscount($request, $tenantId, $data['isActive'] ? 'discount.activated' : 'discount.deactivated', $discount, $before);
            }
        });

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $discount), $this->access->canSeeCouponCodes($request))]);
    }

    public function destroy(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findManagedDiscount($tenantId, $discount);
        DB::transaction(function () use ($request, $tenantId, $discount): void {
            app(DiscountResolutionService::class)->lock($tenantId);
            DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->lockForUpdate()->first();
            $before = $this->lockedManagementState($tenantId, $discount);
            DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount)->delete();
            DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $discount)->delete();
            DB::table('discount_channel_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount)->delete();
            DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->update(['deleted_at' => now(), 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'discount.archived', 'discount', $discount, $this->auditState($before), ['archived' => true], actorId: $this->actorId($request));
        });

        return response()->json([], 204);
    }

    /** Generates a short code; the unique database index remains final authority on create. */
    public function generateCode(Request $request): JsonResponse
    {
        $code = app(CouponCodeGenerator::class)->generate(TenantContext::id($request));

        return response()->json(['data' => ['code' => $code]]);
    }

    public function available(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $order = $request->filled('orderId') ? $this->findOrder($tenantId, (int) $request->query('orderId')) : null;

        // Coupon policies are redeemable only through explicit code entry;
        // returning them here would expose their secret to every POS user.
        $discounts = $this->discountQuery($tenantId)->where('is_active', true)
            ->where('application_mode', 'manual')
            ->where('type', '!=', 'bogo')->get()
            ->filter(fn (object $discount) => $this->availableNow($tenantId, $discount, $order))
            ->map(fn (object $discount) => $this->serializeDiscount($tenantId, $discount, $order))
            ->values();

        return response()->json(['data' => $discounts]);
    }

    public function apply(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        app(DiscountEngineProtocol::class)->legacyMutation($request, $tenantId, $order);
        $data = $request->validate([
            'code' => ['nullable', 'string'],
            'discountId' => ['nullable', 'integer', Rule::exists('discounts', 'id')->where(fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at'))],
            'reason' => ['nullable', 'string'],
        ]);
        if (empty($data['code']) && empty($data['discountId'])) {
            throw ValidationException::withMessages(['discount' => 'A coupon code or discountId is required.']);
        }

        $redeem = function () use ($request, $tenantId, $order, $data): array {
            $discount = $this->findDiscount($tenantId, $data);
            $this->assertApplicationMode($discount, $data);

            return DB::transaction(function () use ($request, $tenantId, $order, $discount, $data): array {
                $orderRow = $this->lockedOrder($tenantId, $order);
                app(DiscountResolutionService::class)->lock($tenantId);
                app(DiscountEngineProtocol::class)->legacyMutation($request, $tenantId, $order);
                $this->lifecycle->assertDiscountable($orderRow);
                $discount = DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount->id)->whereNull('deleted_at')->lockForUpdate()->first();
                if (! $discount) {
                    throw new OrderLifecycleException('DISCOUNT_INACTIVE', 'The configured discount is no longer available.');
                }
                $this->assertApplicationMode($discount, $data);
                if (! empty($data['code']) && strcasecmp((string) $discount->code, trim($data['code'])) !== 0) {
                    throw new OrderLifecycleException('DISCOUNT_CODE_REQUIRED', 'The discount code has changed.');
                }
                $result = $this->eligibility->assertApplicable($tenantId, $discount, $orderRow);
                $amount = $result['amount'];
                DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order)->delete();
                DB::table('order_discounts')->insert([
                    'tenant_id' => $tenantId, 'order_id' => $order, 'discount_id' => $discount->id,
                    'discount_name' => $data['reason'] ?? $discount->name, 'discount_type' => $discount->type,
                    'discount_value' => $discount->value, 'discount_amount' => $amount,
                    'created_at' => now(), 'updated_at' => now(),
                ]);
                $this->pricing->recalculateOrder($tenantId, $order);
                $this->audit->record($request, $tenantId, 'discount.legacy.applied', 'order', $order,
                    [], ['discountId' => (int) $discount->id, 'source' => $discount->application_mode === 'code' ? 'code' : 'configured_manual', 'amount' => $amount, 'reason' => $data['reason'] ?? null],
                    branchId: (int) $orderRow->branch_id, actorId: $this->actorId($request));

                return [$discount, $amount];
            });
        };
        // A typed coupon is a guessable input: failures spend the attempt budget and availability is concealed.
        if (empty($data['code'])) {
            [$discount, $amount] = $redeem();
        } else {
            try {
                [$discount, $amount] = app(CouponAttemptGuard::class)->guarded($request, $tenantId, $redeem);
            } catch (OrderLifecycleException $exception) {
                // Legacy contract: an unknown or unavailable typed coupon is one identical 404.
                abort_if($exception->domainCode === 'DISCOUNT_NOT_FOUND', 404, 'Discount not found.');

                throw $exception;
            }
        }
        $updated = $this->findOrder($tenantId, $order);

        return response()->json(['data' => [
            'orderId' => $order,
            'discount' => ['id' => $discount->id, 'name' => $discount->name, 'type' => $discount->type, 'value' => (float) $discount->value, 'amount' => (float) $amount],
            'totals' => ['subtotal' => (float) $updated->subtotal, 'discountTotal' => (float) $updated->discount_total, 'taxTotal' => (float) $updated->tax_total, 'total' => (float) $updated->total],
        ]]);
    }

    public function remove(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        app(DiscountEngineProtocol::class)->legacyMutation($request, $tenantId, $order);
        DB::transaction(function () use ($request, $tenantId, $order): void {
            $orderRow = $this->lockedOrder($tenantId, $order);
            app(DiscountResolutionService::class)->lock($tenantId);
            app(DiscountEngineProtocol::class)->legacyMutation($request, $tenantId, $order);
            $this->lifecycle->assertDiscountable($orderRow);
            $removed = DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order)->pluck('discount_id')->filter()->map(fn ($id) => (int) $id)->all();
            DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order)->delete();
            $this->pricing->recalculateOrder($tenantId, $order);
            $this->audit->record($request, $tenantId, 'discount.legacy.removed', 'order', $order, ['discountIds' => $removed], [], branchId: (int) $orderRow->branch_id, actorId: $this->actorId($request));
        });

        return response()->json(['data' => ['orderId' => $order, 'discount' => null]]);
    }

    private function validatedManagementData(Request $request, int $tenantId, ?int $discountId = null): array
    {
        $codeRule = Rule::unique('discounts', 'code')->where(fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at'));
        if ($discountId) {
            $codeRule->ignore($discountId);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'], 'code' => ['nullable', 'string', 'max:100', $codeRule],
            'description' => ['nullable', 'string'], 'applicationMode' => ['required', Rule::in(['manual', 'code', 'automatic'])],
            'priority' => ['sometimes', 'required', 'integer', 'between:0,10'],
            'combinationBehavior' => ['sometimes', 'required', Rule::in(self::COMBINATION_BEHAVIORS)],
            'type' => ['required', Rule::in(['percentage', 'fixed'])], 'scope' => ['required', Rule::in(['order', 'product', 'category', 'bundle'])],
            'fixedAmountBasis' => ['nullable', Rule::in(['per_order', 'per_unit'])],
            'value' => ['required', 'numeric', 'min:0'], 'conditions' => ['nullable', 'string'],
            'startsAt' => ['nullable', 'date'], 'endsAt' => ['nullable', 'date', 'after_or_equal:startsAt'],
            'startDate' => ['nullable', 'date_format:Y-m-d'], 'endDate' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:startDate'],
            'activeDays' => ['nullable', 'array'], 'activeDays.*' => ['distinct', Rule::in(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])],
            'startTime' => ['nullable', 'date_format:H:i'], 'endTime' => ['nullable', 'date_format:H:i'],
            'minimumOrderAmount' => ['nullable', 'numeric', 'min:0'], 'maximumDiscountAmount' => ['nullable', 'numeric', 'min:0'],
            'usageLimit' => ['nullable', 'integer', 'min:1'], 'usageLimitPerCustomer' => ['nullable', 'integer', 'min:1'],
            'perCustomerDailyUsageLimit' => ['nullable', 'integer', 'min:1'],
            'customerEligibilityMode' => ['nullable', Rule::in(['all', 'selected_groups', 'selected_customers'])],
            // Read compatibility only: heuristic labels can never create a V1 policy.
            'customerEligibility' => ['nullable', Rule::in(['All Customers', 'Regular', 'VIP', 'New Customers'])],
            'paymentMethod' => ['nullable', Rule::in(['Any Payment Method', 'Cash', 'Card', 'Wallet'])],
            'customerGroupIds' => ['nullable', 'array'], 'customerGroupIds.*' => ['integer', 'distinct'],
            'customerIds' => ['nullable', 'array'], 'customerIds.*' => ['integer', 'distinct'],
            'paymentMethodIds' => ['nullable', 'array'], 'paymentMethodIds.*' => ['integer', 'distinct'],
            'isActive' => ['required', 'boolean'], 'targetProductIds' => ['nullable', 'array'], 'targetProductIds.*' => ['integer', 'distinct'],
            'productVariantSelections' => ['sometimes', 'required', 'array'],
            'targetCategoryIds' => ['nullable', 'array'], 'targetCategoryIds.*' => ['integer', 'distinct'],
            'bundleRequirements' => ['nullable', 'array'],
            'bundleRequirements.*.productId' => ['required_with:bundleRequirements', 'integer', 'distinct'],
            'bundleRequirements.*.quantity' => ['required_with:bundleRequirements', 'numeric', 'gt:0'],
            // Shapes are checked by DiscountBundleVariantService; the rules only keep the keys.
            'bundleRequirements.*.variantMode' => ['sometimes', 'required', 'string'],
            'bundleRequirements.*.variantIds' => ['sometimes', 'array'],
            'channelKeys' => ['nullable', 'array'],
            'channelKeys.*' => ['string', 'distinct', Rule::in($this->salesChannelKeys())],
            'appliesToAllBranches' => ['required', 'boolean'],
            'branchIds' => [
                'nullable',
                'array',
                Rule::requiredIf(fn () => ! $request->boolean('appliesToAllBranches')),
                Rule::when(! $request->boolean('appliesToAllBranches'), ['min:1']),
            ],
            'branchIds.*' => [
                'integer', 'distinct',
                Rule::exists('branches', 'id')->where(fn (Builder $query) => $query->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')),
            ],
        ]);
        app(DiscountProductVariantService::class)->validate($tenantId, $data);
        app(DiscountBundleVariantService::class)->validate($tenantId, $data);
        foreach (['value', 'minimumOrderAmount', 'maximumDiscountAmount'] as $field) {
            if (isset($data[$field])) {
                try {
                    $data[$field] = (string) BigDecimal::of((string) $data[$field])->toScale(2);
                } catch (MathException $exception) {
                    throw ValidationException::withMessages([$field => 'Use at most two decimal places.']);
                }
            }
        }
        $data['customerEligibilityMode'] ??= ($data['customerEligibility'] ?? null) === 'All Customers' ? 'all' : 'all';
        if (($data['customerEligibility'] ?? null) !== null && $data['customerEligibility'] !== 'All Customers') {
            throw ValidationException::withMessages(['customerEligibility' => 'Legacy spending-heuristic eligibility is not supported by Discount V1. Use customerEligibilityMode and customerGroupIds.']);
        }
        if (($data['paymentMethod'] ?? null) !== null && $data['paymentMethod'] !== 'Any Payment Method') {
            throw ValidationException::withMessages(['paymentMethod' => 'Legacy free-text payment methods are not supported by Discount V1. Use paymentMethodIds.']);
        }
        if ($data['applicationMode'] === 'code' && trim((string) ($data['code'] ?? '')) === '') {
            throw ValidationException::withMessages(['code' => 'A code is required for code-applied discounts.']);
        }
        if (in_array($data['applicationMode'], ['manual', 'automatic'], true) && filled($data['code'] ?? null)) {
            throw ValidationException::withMessages(['code' => 'Manual discounts cannot define a coupon code.']);
        }
        if ($data['type'] === 'percentage' && BigDecimal::of($data['value'])->isGreaterThan(100)) {
            throw ValidationException::withMessages(['value' => 'A percentage discount cannot exceed 100.']);
        }
        $data['fixedAmountBasis'] ??= 'per_order';
        if ($data['fixedAmountBasis'] === 'per_unit' && ($data['type'] !== 'fixed' || $data['scope'] !== 'product')) {
            throw ValidationException::withMessages(['fixedAmountBasis' => 'Per-unit fixed amounts require a fixed product discount.']);
        }
        if (! empty($data['code']) && $this->discountQuery($tenantId)
            ->whereRaw('LOWER(code) = ?', [strtolower($data['code'])])
            ->when($discountId, fn (Builder $query) => $query->where('id', '!=', $discountId))
            ->exists()) {
            throw ValidationException::withMessages(['code' => 'The discount code has already been taken.']);
        }
        if (array_key_exists('code', $data) && $data['code'] !== null) {
            $data['code'] = strtoupper(trim($data['code']));
        }
        $products = $data['targetProductIds'] ?? [];
        $categories = $data['targetCategoryIds'] ?? [];
        $bundleRequirements = $data['bundleRequirements'] ?? [];
        if ($data['scope'] === 'order' && ($products || $categories)) {
            throw ValidationException::withMessages(['targets' => 'Order discounts cannot define product or category targets.']);
        }
        if ($data['scope'] === 'product' && (! $products || $categories)) {
            throw ValidationException::withMessages(['targetProductIds' => 'Product discounts require product targets only.']);
        }
        if ($data['scope'] === 'category' && (! $categories || $products)) {
            throw ValidationException::withMessages(['targetCategoryIds' => 'Category discounts require category targets only.']);
        }
        if ($data['scope'] === 'bundle' && (! $bundleRequirements || $products || $categories)) {
            throw ValidationException::withMessages(['bundleRequirements' => 'Bundle discounts require bundle requirements only.']);
        }
        if ($data['scope'] !== 'bundle' && $bundleRequirements) {
            throw ValidationException::withMessages(['bundleRequirements' => 'Bundle requirements are only valid for bundle discounts.']);
        }
        $groups = $data['customerGroupIds'] ?? [];
        $customers = $data['customerIds'] ?? [];
        if ($data['customerEligibilityMode'] === 'all' && ($groups || $customers)) {
            throw ValidationException::withMessages(['customerEligibilityMode' => 'All-customer discounts cannot define customer targets.']);
        }
        if ($data['customerEligibilityMode'] === 'selected_groups' && ! $groups) {
            throw ValidationException::withMessages(['customerGroupIds' => 'Selected-group discounts require one or more customer groups.']);
        }
        if ($data['customerEligibilityMode'] === 'selected_groups' && $customers) {
            throw ValidationException::withMessages(['customerIds' => 'Selected-group discounts cannot define selected-customer targets.']);
        }
        if ($data['customerEligibilityMode'] === 'selected_customers' && ! $customers) {
            throw ValidationException::withMessages(['customerIds' => 'Selected-customer discounts require one or more customers.']);
        }
        if ($data['customerEligibilityMode'] === 'selected_customers' && $groups) {
            throw ValidationException::withMessages(['customerGroupIds' => 'Selected-customer discounts cannot define customer-group targets.']);
        }
        if (($data['startTime'] ?? null) === null xor ($data['endTime'] ?? null) === null) {
            throw ValidationException::withMessages(['schedule' => 'Start time and end time must be provided together.']);
        }
        $this->assertTenantTargets($tenantId, $data);

        return $data;
    }

    private function discountPayload(int $tenantId, array $data, bool $creating = true): array
    {
        $payload = [
            'name' => $data['name'], 'code' => $data['code'] ?? null, 'description' => $data['description'] ?? null,
            'application_mode' => $data['applicationMode'], 'type' => $data['type'], 'scope' => $data['scope'], 'value' => $data['value'],
            'fixed_amount_basis' => $data['fixedAmountBasis'],
            'conditions' => $data['conditions'] ?? null, 'starts_at' => $data['startsAt'] ?? null, 'ends_at' => $data['endsAt'] ?? null,
            'start_date' => $data['startDate'] ?? null, 'end_date' => $data['endDate'] ?? null,
            'active_days' => isset($data['activeDays']) ? json_encode(array_values($data['activeDays'])) : null,
            'start_time' => $data['startTime'] ?? null, 'end_time' => $data['endTime'] ?? null,
            'minimum_order_amount' => $data['minimumOrderAmount'] ?? 0, 'maximum_discount_amount' => $data['maximumDiscountAmount'] ?? null,
            'usage_limit' => $data['usageLimit'] ?? null, 'usage_limit_per_customer' => $data['usageLimitPerCustomer'] ?? null,
            'usage_limit_per_customer_per_day' => $data['perCustomerDailyUsageLimit'] ?? null,
            'customer_eligibility' => $data['customerEligibilityMode'] === 'all' ? null : $data['customerEligibilityMode'],
            'payment_method' => null,
            'is_active' => $data['isActive'], 'updated_at' => now(),
        ];

        if ($creating || array_key_exists('priority', $data)) {
            $payload['priority'] = $data['priority'] ?? 0;
        }
        // Omitted by older clients: the saved value is kept on update.
        if ($creating || array_key_exists('combinationBehavior', $data)) {
            $payload['combination_behavior'] = $data['combinationBehavior'] ?? 'follow_cafe_policy';
        }

        return $creating ? ['tenant_id' => $tenantId, 'used_count' => 0, 'estimated_saved_value' => 0, 'created_at' => now()] + $payload : $payload;
    }

    private function assertTenantTargets(int $tenantId, array $data): void
    {
        app(DiscountProductVariantService::class)->validate($tenantId, $data);
        app(DiscountBundleVariantService::class)->validate($tenantId, $data);
        foreach (['targetProductIds' => 'products', 'targetCategoryIds' => 'categories'] as $key => $table) {
            $ids = array_values(array_unique(array_map('intval', $data[$key] ?? [])));
            $query = DB::table($table)->where('tenant_id', $tenantId)->whereNull('deleted_at')->whereIn('id', $ids);
            if ($ids && $query->where('is_active', true)->count() !== count($ids)) {
                throw ValidationException::withMessages([$key => 'One or more selected targets are inactive or do not belong to this tenant.']);
            }
        }
        $groups = array_values(array_unique(array_map('intval', $data['customerGroupIds'] ?? [])));
        if ($groups && DB::table('customer_groups')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->whereIn('id', $groups)->count() !== count($groups)) {
            throw ValidationException::withMessages(['customerGroupIds' => 'One or more selected customer groups are inactive or do not belong to this tenant.']);
        }
        $customers = array_values(array_unique(array_map('intval', $data['customerIds'] ?? [])));
        if ($customers && DB::table('customers')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->whereIn('id', $customers)->count() !== count($customers)) {
            throw ValidationException::withMessages(['customerIds' => 'One or more selected customers are inactive or do not belong to this tenant.']);
        }
        $bundleProductIds = array_values(array_unique(array_map(fn (array $requirement) => (int) $requirement['productId'], $data['bundleRequirements'] ?? [])));
        if ($bundleProductIds && DB::table('products')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->whereIn('id', $bundleProductIds)->count() !== count($bundleProductIds)) {
            throw ValidationException::withMessages(['bundleRequirements' => 'One or more bundle products are inactive or do not belong to this tenant.']);
        }
        $methods = array_values(array_unique(array_map('intval', $data['paymentMethodIds'] ?? [])));
        if ($methods && DB::table('payment_methods as methods')->join('financial_accounts as accounts', 'accounts.id', '=', 'methods.financial_account_id')
            ->where('methods.tenant_id', $tenantId)->where('methods.is_active', true)->where('accounts.tenant_id', $tenantId)->where('accounts.is_active', true)->whereNull('accounts.deleted_at')->whereIn('methods.id', $methods)->count() !== count($methods)) {
            throw ValidationException::withMessages(['paymentMethodIds' => 'One or more selected payment methods are inactive or do not belong to this tenant.']);
        }
    }

    private function syncTargets(int $tenantId, int $discountId, array $data): void
    {
        $variants = app(DiscountProductVariantService::class);
        $bundleVariants = app(DiscountBundleVariantService::class);
        $savedVariants = $variants->savedIds($tenantId, $discountId);
        $savedBundleVariants = $bundleVariants->savedIds($tenantId, $discountId);
        DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->delete();
        DB::table('discount_channel_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->delete();
        DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->delete();
        $now = now();
        $rows = [];
        foreach (['targetProductIds' => 'product', 'targetCategoryIds' => 'category'] as $key => $type) {
            foreach (array_unique(array_map('intval', $data[$key] ?? [])) as $targetId) {
                $rows[] = ['tenant_id' => $tenantId, 'discount_id' => $discountId, 'target_type' => $type, 'target_id' => $targetId, 'created_at' => $now, 'updated_at' => $now];
            }
        }
        foreach (array_unique(array_map('intval', $data['customerGroupIds'] ?? [])) as $groupId) {
            $rows[] = ['tenant_id' => $tenantId, 'discount_id' => $discountId, 'target_type' => 'customer_group', 'target_id' => $groupId, 'created_at' => $now, 'updated_at' => $now];
        }
        foreach (array_unique(array_map('intval', $data['customerIds'] ?? [])) as $customerId) {
            $rows[] = ['tenant_id' => $tenantId, 'discount_id' => $discountId, 'target_type' => 'customer', 'target_id' => $customerId, 'created_at' => $now, 'updated_at' => $now];
        }
        foreach (array_unique(array_map('intval', $data['paymentMethodIds'] ?? [])) as $methodId) {
            $rows[] = ['tenant_id' => $tenantId, 'discount_id' => $discountId, 'target_type' => 'payment_method', 'target_id' => $methodId, 'created_at' => $now, 'updated_at' => $now];
        }
        if (! $data['appliesToAllBranches']) {
            foreach (array_unique(array_map('intval', $data['branchIds'] ?? [])) as $branchId) {
                $rows[] = ['tenant_id' => $tenantId, 'discount_id' => $discountId, 'target_type' => 'branch', 'target_id' => $branchId, 'created_at' => $now, 'updated_at' => $now];
            }
        }
        if ($rows) {
            DB::table('discount_targets')->insert($rows);
        }
        $variants->persist($tenantId, $discountId, $data, $savedVariants);
        foreach (array_unique(array_map('strval', $data['channelKeys'] ?? [])) as $channel) {
            DB::table('discount_channel_targets')->insert(['tenant_id' => $tenantId, 'discount_id' => $discountId, 'channel_key' => $channel, 'created_at' => $now, 'updated_at' => $now]);
        }
        $bundleVariants->persist($tenantId, $discountId, $data, $savedBundleVariants);
    }

    private function discountQuery(int $tenantId): Builder
    {
        return DB::table('discounts')->where('tenant_id', $tenantId)->whereNull('deleted_at');
    }

    private function findManagedDiscount(int $tenantId, int $id): object
    {
        $discount = $this->discountQuery($tenantId)->where('id', $id)->first();
        abort_if(! $discount, 404, 'Discount not found.');

        return $discount;
    }

    private function findOrder(int $tenantId, int $orderId): object
    {
        $order = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderId)->whereNull('deleted_at')->first();
        abort_if(! $order, 404, 'Order not found.');
        app(BranchAccessService::class)->authorizeRequestBranch(request(), (int) $order->branch_id);

        return $order;
    }

    private function lockedOrder(int $tenantId, int $orderId): object
    {
        $order = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderId)->whereNull('deleted_at')->lockForUpdate()->first();
        abort_if(! $order, 404, 'Order not found.');
        app(BranchAccessService::class)->authorizeRequestBranch(request(), (int) $order->branch_id);

        return $order;
    }

    private function findDiscount(int $tenantId, array $data): object
    {
        $query = $this->discountQuery($tenantId);
        ! empty($data['discountId']) ? $query->where('id', $data['discountId']) : $query->whereRaw('LOWER(code) = ?', [strtolower($data['code'])]);
        $discount = $query->first();
        if (! $discount && empty($data['discountId'])) {
            // An unknown typed coupon is indistinguishable from an unavailable one (see CouponAttemptGuard).
            throw new OrderLifecycleException('DISCOUNT_NOT_FOUND', 'The coupon code is invalid or unavailable.');
        }
        abort_if(! $discount, 404, 'Discount not found.');

        return $discount;
    }

    private function targetIds(int $tenantId, int $discountId, string $type): array
    {
        return DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->where('target_type', $type)->pluck('target_id')->map(fn ($id) => (int) $id)->all();
    }

    /** @var array<int, array<int, string>> tenant id => [branch id => timezone] */
    private array $branchTimezones = [];

    /**
     * Management status. Date validity is evaluated on each branch's own local
     * calendar day, exactly like runtime eligibility. When the policy spans
     * branches whose status differs, the aggregate is 'active' while any branch
     * is live (so POS-eligible policies are never reported as expired), then
     * 'scheduled', then 'expired'; branchStatuses carries the per-branch detail.
     */
    private function status(int $tenantId, object $discount, ?array $branchIds = null): string
    {
        if (! $discount->is_active) {
            return 'inactive';
        }
        $statuses = array_values($this->branchValidity($tenantId, $discount, $branchIds));
        foreach (['active', 'scheduled'] as $status) {
            if (in_array($status, $statuses, true)) {
                return $status;
            }
        }

        return 'expired';
    }

    /** @return array<int, string> branch id => 'scheduled'|'expired'|'active' (date validity only) */
    private function branchValidity(int $tenantId, object $discount, ?array $branchIds = null): array
    {
        $this->branchTimezones[$tenantId] ??= DB::table('branches')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')
            ->pluck('timezone', 'id')->map(fn ($timezone) => $timezone ?: 'UTC')->all();
        $branches = $this->branchTimezones[$tenantId];
        $branchIds ??= $this->targetIds($tenantId, (int) $discount->id, 'branch');
        $scope = $branchIds === [] ? $branches : array_intersect_key($branches, array_flip($branchIds));
        // No usable branch (tenant without active branches): UTC, never the server timezone.
        $scope = $scope === [] ? [0 => 'UTC'] : $scope;
        $now = CarbonImmutable::now();

        return array_map(fn (string $timezone): string => $this->eligibility->validityStatus($discount, $now->setTimezone($timezone)), $scope);
    }

    /** POS list: with an order, that order's branch decides; otherwise any eligible branch keeps it visible. */
    private function availableNow(int $tenantId, object $discount, ?object $order): bool
    {
        if ($order === null) {
            return $this->status($tenantId, $discount) === 'active';
        }

        return $discount->is_active && ($this->branchValidity($tenantId, $discount, [(int) $order->branch_id])[(int) $order->branch_id] ?? 'expired') === 'active';
    }

    private function serializeManagementDiscount(int $tenantId, object $discount, bool $revealCode = true): array
    {
        return DB::transaction(function () use ($tenantId, $discount, $revealCode): array {
            $current = DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount->id)->sharedLock()->first();
            abort_if(! $current || $current->deleted_at !== null, 404);

            return $this->serializeLockedManagementDiscount($tenantId, $current, $revealCode);
        });
    }

    /** Raw (code included) state of a discount the caller already holds locked, for audit diffing only. */
    private function lockedManagementState(int $tenantId, int $discountId): array
    {
        return $this->serializeLockedManagementDiscount($tenantId, DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discountId)->first());
    }

    private const AUDIT_FIELDS = [
        'name', 'applicationMode', 'priority', 'combinationBehavior', 'type', 'scope', 'value', 'fixedAmountBasis',
        'startDate', 'endDate', 'startsAt', 'endsAt', 'activeDays', 'startTime', 'endTime', 'minimumOrderAmount', 'maximumDiscountAmount',
        'usageLimit', 'usageLimitPerCustomer', 'perCustomerDailyUsageLimit', 'customerEligibilityMode', 'customerGroupIds', 'customerIds',
        'paymentMethodIds', 'isActive', 'targetProductIds', 'targetCategoryIds', 'productVariantSelections', 'bundleRequirements',
        'channelKeys', 'appliesToAllBranches', 'branchIds',
    ];

    /** Meaningful policy state for the audit trail. The coupon text is never copied: only whether one exists. */
    private function auditState(array $state): array
    {
        return array_intersect_key($state, array_flip(self::AUDIT_FIELDS)) + ['hasCode' => $state['code'] !== null];
    }

    private function actorId(Request $request): ?int
    {
        $actor = $request->attributes->get('auth_user');

        return $actor ? (int) $actor->id : null;
    }

    /** @param array<string, mixed>|null $beforeRaw state from lockedManagementState(), or null on create */
    private function auditDiscount(Request $request, int $tenantId, string $action, int $discountId, ?array $beforeRaw): void
    {
        $afterRaw = $this->lockedManagementState($tenantId, $discountId);
        $before = $beforeRaw === null ? [] : $this->auditState($beforeRaw);
        $after = $this->auditState($afterRaw);
        $after['name'] ??= null;
        $changed = $beforeRaw === null ? array_keys($after) : array_keys(array_filter($after, fn ($value, string $key): bool => ! array_key_exists($key, $before) || $before[$key] !== $value, ARRAY_FILTER_USE_BOTH));
        $after['changedFields'] = $changed;
        if ($beforeRaw !== null) {
            $after['codeChanged'] = $beforeRaw['code'] !== $afterRaw['code'];
        }
        $this->audit->record($request, $tenantId, $action, 'discount', $discountId, $before, $after, actorId: $this->actorId($request));
    }

    private function serializeLockedManagementDiscount(int $tenantId, object $discount, bool $revealCode = true): array
    {
        $targets = DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->get()->groupBy('target_type');
        $ids = fn (string $type) => ($targets[$type] ?? collect())->pluck('target_id')->map(fn ($id) => (int) $id)->values()->all();
        $productIds = $ids('product');
        $categoryIds = $ids('category');
        $groupIds = $ids('customer_group');
        $customerIds = $ids('customer');
        $branchIds = $ids('branch');
        $paymentMethodIds = $ids('payment_method');
        $channelKeys = DB::table('discount_channel_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->orderBy('channel_key')->pluck('channel_key')->values()->all();
        $bundleVariants = app(DiscountBundleVariantService::class);
        $savedBundleVariants = $bundleVariants->savedIds($tenantId, $discount->id);
        $bundleVariantRows = $bundleVariants->variantRows($tenantId, $savedBundleVariants);
        $bundleRequirements = DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->orderBy('product_id')->get()
            ->map(fn (object $requirement) => ['productId' => (int) $requirement->product_id, 'quantity' => (float) $requirement->quantity]
                + $bundleVariants->detail($savedBundleVariants, (int) $requirement->product_id, $bundleVariantRows))->all();

        return [
            'id' => (int) $discount->id, 'name' => $discount->name, 'code' => $revealCode ? $discount->code : null, 'hasCode' => $discount->code !== null, 'description' => $discount->description,
            'applicationMode' => $discount->application_mode, 'priority' => (int) $discount->priority, 'combinationBehavior' => $discount->combination_behavior, 'type' => $discount->type, 'scope' => $discount->scope, 'value' => (float) $discount->value,
            'fixedAmountBasis' => $discount->fixed_amount_basis,
            'conditions' => $discount->conditions, 'startDate' => $discount->start_date, 'endDate' => $discount->end_date,
            // Legacy timestamps remain readable but are not used by V1 edits.
            'startsAt' => $discount->starts_at, 'endsAt' => $discount->ends_at,
            'activeDays' => $discount->active_days ? json_decode($discount->active_days, true) : [], 'startTime' => $discount->start_time, 'endTime' => $discount->end_time,
            'minimumOrderAmount' => (float) $discount->minimum_order_amount, 'maximumDiscountAmount' => $discount->maximum_discount_amount === null ? null : (float) $discount->maximum_discount_amount,
            'usageLimit' => $discount->usage_limit, 'usageLimitPerCustomer' => $discount->usage_limit_per_customer,
            'perCustomerDailyUsageLimit' => $discount->usage_limit_per_customer_per_day, 'usedCount' => (int) $discount->used_count,
            'estimatedSavedValue' => (float) $discount->estimated_saved_value,
            'customerEligibilityMode' => $discount->customer_eligibility === 'selected_customers' ? 'selected_customers' : ($groupIds ? 'selected_groups' : 'all'),
            'customerGroupIds' => $groupIds, 'customerGroups' => $this->targetDetails($tenantId, 'customer_groups', $groupIds),
            'customerIds' => $customerIds, 'customers' => $this->targetDetails($tenantId, 'customers', $customerIds),
            'paymentMethodIds' => $paymentMethodIds, 'paymentMethods' => $this->targetDetails($tenantId, 'payment_methods', $paymentMethodIds),
            'legacyCustomerEligibility' => $discount->customer_eligibility === 'selected_groups' ? null : $discount->customer_eligibility,
            'legacyPaymentMethod' => $discount->payment_method,
            'isActive' => (bool) $discount->is_active, 'status' => $this->status($tenantId, $discount, $branchIds), 'branchStatuses' => $this->branchStatuses($tenantId, $discount, $branchIds), 'displayPeriodPrimary' => $discount->display_period_primary, 'displayPeriodSecondary' => $discount->display_period_secondary,
            'productVariantSelections' => app(DiscountProductVariantService::class)->detail($tenantId, $discount->id, $productIds),
            'targetProductIds' => $productIds, 'productTargets' => $this->targetDetails($tenantId, 'products', $productIds),
            'targetCategoryIds' => $categoryIds, 'categoryTargets' => $this->targetDetails($tenantId, 'categories', $categoryIds),
            'bundleRequirements' => $bundleRequirements,
            'channelKeys' => $channelKeys,
            'appliesToAllBranches' => ! $targets->has('branch'), 'branchIds' => $branchIds, 'branches' => $this->targetDetails($tenantId, 'branches', $branchIds),
        ];
    }

    /** @return array<int, array{branchId: int, status: string}> per-branch status, so a multi-branch policy never hides a branch-specific state */
    private function branchStatuses(int $tenantId, object $discount, array $branchIds): array
    {
        $statuses = $discount->is_active ? $this->branchValidity($tenantId, $discount, $branchIds) : array_map(fn () => 'inactive', $this->branchValidity($tenantId, $discount, $branchIds));
        unset($statuses[0]);
        ksort($statuses);

        return array_values(array_map(fn (int $id, string $status): array => ['branchId' => $id, 'status' => $status], array_keys($statuses), $statuses));
    }

    /** @return array<int, array{id: int, name: string, isActive: bool}> */
    private function targetDetails(int $tenantId, string $table, array $ids): array
    {
        if (! $ids) {
            return [];
        }
        $nameColumn = $table === 'payment_methods' ? 'name' : 'name';
        $rows = DB::table($table)->where('tenant_id', $tenantId)->whereIn('id', $ids)->get(['id', $nameColumn, 'is_active']);
        $byId = $rows->keyBy('id');

        return collect($ids)->map(fn (int $id) => $byId->has($id) ? [
            'id' => $id, 'name' => (string) $byId[$id]->{$nameColumn}, 'isActive' => (bool) $byId[$id]->is_active,
        ] : ['id' => $id, 'name' => null, 'isActive' => false])->values()->all();
    }

    private function serializeDiscount(int $tenantId, object $discount, ?object $order): array
    {
        $eligible = true;
        $message = null;
        if ($order) {
            try {
                $this->eligibility->assertApplicable($tenantId, $discount, $order);
            } catch (OrderLifecycleException $exception) {
                $eligible = false;
                $message = $exception->getMessage();
            }
        }

        return ['id' => $discount->id, 'name' => $discount->name, 'type' => $discount->type, 'value' => (float) $discount->value,
            'badge' => match ($discount->type) {
                'percentage' => ((float) $discount->value).'% OFF', 'fixed' => '-SYP '.number_format((float) $discount->value, 2), 'bogo' => 'BOGO', default => strtoupper($discount->type)
            },
            'minimumOrderAmount' => (float) $discount->minimum_order_amount, 'eligible' => $eligible, 'message' => $message]
            + $this->validUntil($tenantId, $discount, $order);
    }

    /**
     * Last moment a policy is valid, for POS display. Current policies end on a
     * branch-local calendar day (end_date, inclusive: kind "date", no zone
     * needed). Older policies carry an instant (ends_at, kind "instant", UTC
     * ISO-8601) which is shown in the order branch's timezone. `validUntil`
     * keeps its legacy key; the kind/timezone fields say how to read it.
     *
     * @return array{validUntil: ?string, validUntilKind: ?string, validUntilTimezone: ?string}
     */
    private function validUntil(int $tenantId, object $discount, ?object $order): array
    {
        if ($discount->end_date) {
            return ['validUntil' => (string) $discount->end_date, 'validUntilKind' => 'date', 'validUntilTimezone' => null];
        }
        if ($discount->ends_at) {
            $timezone = $order ? DB::table('branches')->where('tenant_id', $tenantId)->where('id', $order->branch_id)->value('timezone') : null;

            return [
                'validUntil' => CarbonImmutable::parse($discount->ends_at, 'UTC')->utc()->format('Y-m-d\TH:i:s\Z'),
                'validUntilKind' => 'instant',
                'validUntilTimezone' => $timezone ?: null,
            ];
        }

        return ['validUntil' => null, 'validUntilKind' => null, 'validUntilTimezone' => null];
    }

    private function assertApplicationMode(object $discount, array $data): void
    {
        if ($discount->application_mode === 'code' && empty($data['code'])) {
            throw new OrderLifecycleException('DISCOUNT_CODE_REQUIRED', 'This discount requires its code.');
        }
        if ($discount->application_mode === 'manual' && empty($data['discountId'])) {
            throw new OrderLifecycleException('DISCOUNT_SELECTION_REQUIRED', 'Select this discount from the available discounts list.');
        }
        if (! in_array($discount->application_mode, ['manual', 'code'], true)) {
            throw new OrderLifecycleException('DISCOUNT_APPLICATION_MODE_UNSUPPORTED', 'Automatic discounts are not supported.');
        }
    }

    /** @return array<int, string> */
    private function salesChannelKeys(): array
    {
        return array_map(fn (SalesChannel $channel) => $channel->value, SalesChannel::cases());
    }

    private function throwFriendlyCodeConflict(QueryException $exception): never
    {
        if ((string) $exception->getCode() === '23505' && str_contains($exception->getMessage(), 'discounts_tenant_lower_code_unique')) {
            throw ValidationException::withMessages(['code' => 'The discount code has already been taken.']);
        }

        throw $exception;
    }
}
