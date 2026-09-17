<?php

namespace App\Http\Controllers\Api;

use App\Domain\Menu\Enums\SalesChannel;
use App\Exceptions\OrderLifecycleException;
use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\DiscountEligibilityService;
use App\Services\OrderLifecyclePolicy;
use App\Services\PosPricingService;
use App\Support\TenantContext;
use Illuminate\Database\Query\Builder;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class DiscountController extends Controller
{
    public function __construct(
        private readonly PosPricingService $pricing,
        private readonly OrderLifecyclePolicy $lifecycle,
        private readonly DiscountEligibilityService $eligibility,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $query = $this->discountQuery($tenantId);

        if ($request->filled('search')) {
            $search = '%'.strtolower((string) $request->query('search')).'%';
            $query->where(function (Builder $query) use ($search): void {
                $query->whereRaw('LOWER(name) LIKE ?', [$search])
                    ->orWhereRaw('LOWER(code) LIKE ?', [$search])
                    ->orWhereRaw('LOWER(conditions) LIKE ?', [$search]);
            });
        }

        $discounts = $query->orderBy('id')->get()
            ->filter(fn (object $discount) => ! $request->filled('status') || $this->status($discount) === $request->query('status'))
            ->map(fn (object $discount) => $this->serializeManagementDiscount($tenantId, $discount))
            ->values();

        return response()->json(['data' => $discounts]);
    }

    public function show(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $discount))]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $this->validatedManagementData($request, $tenantId);
        try {
            $id = DB::transaction(function () use ($tenantId, $data): int {
                $id = (int) DB::table('discounts')->insertGetId($this->discountPayload($tenantId, $data));
                $this->syncTargets($tenantId, $id, $data);

                return $id;
            });
        } catch (QueryException $exception) {
            $this->throwFriendlyCodeConflict($exception);
        }

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $id))], 201);
    }

    public function update(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findManagedDiscount($tenantId, $discount);
        $data = $this->validatedManagementData($request, $tenantId, $discount);

        try {
            DB::transaction(function () use ($tenantId, $discount, $data): void {
                DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->update($this->discountPayload($tenantId, $data, false));
                $this->syncTargets($tenantId, $discount, $data);
            });
        } catch (QueryException $exception) {
            $this->throwFriendlyCodeConflict($exception);
        }

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $discount))]);
    }

    public function updateStatus(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findManagedDiscount($tenantId, $discount);
        $data = $request->validate(['isActive' => ['required', 'boolean']]);
        DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->update([
            'is_active' => $data['isActive'],
            'updated_at' => now(),
        ]);

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $discount))]);
    }

    public function destroy(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findManagedDiscount($tenantId, $discount);
        DB::transaction(function () use ($tenantId, $discount): void {
            DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount)->delete();
            DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $discount)->delete();
            DB::table('discount_channel_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount)->delete();
            DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->update(['deleted_at' => now(), 'updated_at' => now()]);
        });

        return response()->json([], 204);
    }

    /** Generates a readable code; the unique database index remains final authority on create. */
    public function generateCode(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        for ($attempt = 0; $attempt < 16; $attempt++) {
            $code = $this->newCouponCode();
            if (! $this->discountQuery($tenantId)->whereRaw('LOWER(code) = ?', [strtolower($code)])->exists()) {
                return response()->json(['data' => ['code' => $code]]);
            }
        }

        throw ValidationException::withMessages(['code' => 'A unique coupon code could not be generated. Please retry.']);
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
            ->filter(fn (object $discount) => $this->status($discount) === 'active')
            ->map(fn (object $discount) => $this->serializeDiscount($tenantId, $discount, $order))
            ->values();

        return response()->json(['data' => $discounts]);
    }

    public function apply(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validate([
            'code' => ['nullable', 'string'],
            'discountId' => ['nullable', 'integer', Rule::exists('discounts', 'id')->where(fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at'))],
            'reason' => ['nullable', 'string'],
        ]);
        if (empty($data['code']) && empty($data['discountId'])) {
            throw ValidationException::withMessages(['discount' => 'A coupon code or discountId is required.']);
        }

        $discount = $this->findDiscount($tenantId, $data);
        $this->assertApplicationMode($discount, $data);

        $amount = DB::transaction(function () use ($tenantId, $order, $discount, $data): float {
            $orderRow = $this->lockedOrder($tenantId, $order);
            $this->lifecycle->assertDiscountable($orderRow);
            $discount = DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount->id)->whereNull('deleted_at')->lockForUpdate()->first();
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

            return $amount;
        });

        $updated = $this->findOrder($tenantId, $order);

        return response()->json(['data' => [
            'orderId' => $order,
            'discount' => ['id' => $discount->id, 'name' => $discount->name, 'type' => $discount->type, 'value' => (float) $discount->value, 'amount' => $amount],
            'totals' => ['subtotal' => (float) $updated->subtotal, 'discountTotal' => (float) $updated->discount_total, 'taxTotal' => (float) $updated->tax_total, 'total' => (float) $updated->total],
        ]]);
    }

    public function remove(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        DB::transaction(function () use ($tenantId, $order): void {
            $this->lifecycle->assertDiscountable($this->lockedOrder($tenantId, $order));
            DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order)->delete();
            $this->pricing->recalculateOrder($tenantId, $order);
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
            'description' => ['nullable', 'string'], 'applicationMode' => ['required', Rule::in(['manual', 'code'])],
            'type' => ['required', Rule::in(['percentage', 'fixed'])], 'scope' => ['required', Rule::in(['order', 'product', 'category', 'bundle'])],
            'value' => ['required', 'numeric', 'gt:0'], 'conditions' => ['nullable', 'string'],
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
            'targetCategoryIds' => ['nullable', 'array'], 'targetCategoryIds.*' => ['integer', 'distinct'],
            'bundleRequirements' => ['nullable', 'array'],
            'bundleRequirements.*.productId' => ['required_with:bundleRequirements', 'integer', 'distinct'],
            'bundleRequirements.*.quantity' => ['required_with:bundleRequirements', 'numeric', 'gt:0'],
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
        if ($data['applicationMode'] === 'manual' && filled($data['code'] ?? null)) {
            throw ValidationException::withMessages(['code' => 'Manual discounts cannot define a coupon code.']);
        }
        if ($data['type'] === 'percentage' && (float) $data['value'] > 100) {
            throw ValidationException::withMessages(['value' => 'A percentage discount cannot exceed 100.']);
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

        return $creating ? ['tenant_id' => $tenantId, 'used_count' => 0, 'estimated_saved_value' => 0, 'created_at' => now()] + $payload : $payload;
    }

    private function assertTenantTargets(int $tenantId, array $data): void
    {
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
        foreach (array_unique(array_map('strval', $data['channelKeys'] ?? [])) as $channel) {
            DB::table('discount_channel_targets')->insert(['tenant_id' => $tenantId, 'discount_id' => $discountId, 'channel_key' => $channel, 'created_at' => $now, 'updated_at' => $now]);
        }
        foreach ($data['bundleRequirements'] ?? [] as $requirement) {
            DB::table('discount_bundle_requirements')->insert(['tenant_id' => $tenantId, 'discount_id' => $discountId, 'product_id' => (int) $requirement['productId'], 'quantity' => $requirement['quantity'], 'created_at' => $now, 'updated_at' => $now]);
        }
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
        abort_if(! $discount, 404, 'Discount not found.');

        return $discount;
    }

    private function targetIds(int $tenantId, int $discountId, string $type): array
    {
        return DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->where('target_type', $type)->pluck('target_id')->map(fn ($id) => (int) $id)->all();
    }

    private function status(object $discount): string
    {
        if (! $discount->is_active) {
            return 'inactive';
        }
        $today = now()->toDateString();
        if ($discount->start_date && $today < $discount->start_date) {
            return 'scheduled';
        }
        if ($discount->end_date && $today > $discount->end_date) {
            return 'expired';
        }
        if ($discount->start_date === null && $discount->starts_at && now('UTC')->lessThan(Carbon::parse($discount->starts_at, 'UTC'))) {
            return 'scheduled';
        }
        if ($discount->end_date === null && $discount->ends_at && now('UTC')->greaterThan(Carbon::parse($discount->ends_at, 'UTC'))) {
            return 'expired';
        }

        return 'active';
    }

    private function serializeManagementDiscount(int $tenantId, object $discount): array
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
        $bundleRequirements = DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->orderBy('product_id')->get()
            ->map(fn (object $requirement) => ['productId' => (int) $requirement->product_id, 'quantity' => (float) $requirement->quantity])->all();

        return [
            'id' => (int) $discount->id, 'name' => $discount->name, 'code' => $discount->code, 'description' => $discount->description,
            'applicationMode' => $discount->application_mode, 'type' => $discount->type, 'scope' => $discount->scope, 'value' => (float) $discount->value,
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
            'isActive' => (bool) $discount->is_active, 'status' => $this->status($discount), 'displayPeriodPrimary' => $discount->display_period_primary, 'displayPeriodSecondary' => $discount->display_period_secondary,
            'targetProductIds' => $productIds, 'productTargets' => $this->targetDetails($tenantId, 'products', $productIds),
            'targetCategoryIds' => $categoryIds, 'categoryTargets' => $this->targetDetails($tenantId, 'categories', $categoryIds),
            'bundleRequirements' => $bundleRequirements,
            'channelKeys' => $channelKeys,
            'appliesToAllBranches' => ! $targets->has('branch'), 'branchIds' => $branchIds, 'branches' => $this->targetDetails($tenantId, 'branches', $branchIds),
        ];
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
            'minimumOrderAmount' => (float) $discount->minimum_order_amount, 'eligible' => $eligible, 'message' => $message, 'validUntil' => $discount->ends_at];
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

    private function newCouponCode(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $part = function () use ($alphabet): string {
            $value = '';
            for ($index = 0; $index < 4; $index++) {
                $value .= $alphabet[random_int(0, strlen($alphabet) - 1)];
            }

            return $value;
        };

        return 'CPN-'.$part().'-'.$part();
    }

    private function throwFriendlyCodeConflict(QueryException $exception): never
    {
        if ((string) $exception->getCode() === '23505' && str_contains($exception->getMessage(), 'discounts_tenant_lower_code_unique')) {
            throw ValidationException::withMessages(['code' => 'The discount code has already been taken.']);
        }

        throw $exception;
    }
}
