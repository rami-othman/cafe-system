<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PosPricingService;
use App\Support\TenantContext;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class DiscountController extends Controller
{
    public function __construct(private readonly PosPricingService $pricing)
    {
    }

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
        $id = DB::transaction(function () use ($tenantId, $data): int {
            $id = (int) DB::table('discounts')->insertGetId($this->discountPayload($tenantId, $data));
            $this->syncTargets($tenantId, $id, $data);

            return $id;
        });

        return response()->json(['data' => $this->serializeManagementDiscount($tenantId, $this->findManagedDiscount($tenantId, $id))], 201);
    }

    public function update(Request $request, int $discount): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findManagedDiscount($tenantId, $discount);
        $data = $this->validatedManagementData($request, $tenantId, $discount);

        DB::transaction(function () use ($tenantId, $discount, $data): void {
            DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->update($this->discountPayload($tenantId, $data, false));
            $this->syncTargets($tenantId, $discount, $data);
        });

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
            DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount)->update(['deleted_at' => now(), 'updated_at' => now()]);
        });

        return response()->json([], 204);
    }

    public function available(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $order = $request->filled('orderId') ? $this->findOrder($tenantId, (int) $request->query('orderId')) : null;

        $discounts = $this->discountQuery($tenantId)->where('is_active', true)->get()
            ->filter(fn (object $discount) => $this->status($discount) === 'active')
            ->map(fn (object $discount) => $this->serializeDiscount($discount, $order))
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

        $orderRow = $this->findOrder($tenantId, $order);
        $discount = $this->findDiscount($tenantId, $data);
        $this->assertEligible($tenantId, $discount, $orderRow);
        $amount = $this->discountAmount($tenantId, $orderRow, $discount);

        DB::transaction(function () use ($tenantId, $order, $discount, $amount, $data): void {
            DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order)->delete();
            DB::table('order_discounts')->insert([
                'tenant_id' => $tenantId, 'order_id' => $order, 'discount_id' => $discount->id,
                'discount_name' => $data['reason'] ?? $discount->name, 'discount_type' => $discount->type,
                'discount_value' => $discount->value, 'discount_amount' => $amount,
                'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount->id)->increment('used_count');
            $this->pricing->recalculateOrder($tenantId, $order);
        });

        $updated = $this->findOrder($tenantId, $order);
        return response()->json(['data' => [
            'orderId' => $order,
            'discount' => ['id' => $discount->id, 'name' => $discount->name, 'code' => $discount->code, 'type' => $discount->type, 'value' => (float) $discount->value, 'amount' => $amount],
            'totals' => ['subtotal' => (float) $updated->subtotal, 'discountTotal' => (float) $updated->discount_total, 'taxTotal' => (float) $updated->tax_total, 'total' => (float) $updated->total],
        ]]);
    }

    public function remove(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);
        DB::transaction(function () use ($tenantId, $order): void {
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
            'description' => ['nullable', 'string'], 'applicationMode' => ['required', Rule::in(['auto', 'manual', 'code'])],
            'type' => ['required', Rule::in(['percentage', 'fixed', 'bogo'])], 'scope' => ['required', Rule::in(['order', 'product', 'category'])],
            'value' => ['required', 'numeric', 'min:0'], 'conditions' => ['nullable', 'string'],
            'startsAt' => ['nullable', 'date'], 'endsAt' => ['nullable', 'date', 'after_or_equal:startsAt'],
            'activeDays' => ['nullable', 'array'], 'activeDays.*' => [Rule::in(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])],
            'startTime' => ['nullable', 'date_format:H:i'], 'endTime' => ['nullable', 'date_format:H:i'],
            'minimumOrderAmount' => ['nullable', 'numeric', 'min:0'], 'maximumDiscountAmount' => ['nullable', 'numeric', 'min:0'],
            'usageLimit' => ['nullable', 'integer', 'min:1'], 'usageLimitPerCustomer' => ['nullable', 'integer', 'min:1'],
            'customerEligibility' => ['nullable', 'string', 'max:100'], 'paymentMethod' => ['nullable', 'string', 'max:100'],
            'isActive' => ['required', 'boolean'], 'targetProductIds' => ['nullable', 'array'], 'targetProductIds.*' => ['integer'],
            'targetCategoryIds' => ['nullable', 'array'], 'targetCategoryIds.*' => ['integer'],
            'appliesToAllBranches' => ['required', 'boolean'],
            'branchIds' => [
                'nullable',
                'array',
                Rule::requiredIf(fn () => ! $request->boolean('appliesToAllBranches')),
                Rule::when(! $request->boolean('appliesToAllBranches'), ['min:1']),
            ],
            'branchIds.*' => [
                'integer',
                Rule::exists('branches', 'id')->where(fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at')),
            ],
        ]);
        if ($data['type'] === 'percentage' && (float) $data['value'] > 100) {
            throw ValidationException::withMessages(['value' => 'A percentage discount cannot exceed 100.']);
        }
        if (! empty($data['code']) && $this->discountQuery($tenantId)
            ->whereRaw('LOWER(code) = ?', [strtolower($data['code'])])
            ->when($discountId, fn (Builder $query) => $query->where('id', '!=', $discountId))
            ->exists()) {
            throw ValidationException::withMessages(['code' => 'The discount code has already been taken.']);
        }
        if (in_array($data['scope'], ['product', 'category'], true) && empty($data['targetProductIds']) && empty($data['targetCategoryIds'])) {
            throw ValidationException::withMessages(['targets' => 'Select at least one target for a product or category discount.']);
        }
        $this->assertTenantTargets($tenantId, $data);
        return $data;
    }

    private function discountPayload(int $tenantId, array $data, bool $creating = true): array
    {
        $payload = [
            'name' => $data['name'], 'code' => $data['code'] ?: null, 'description' => $data['description'] ?? null,
            'application_mode' => $data['applicationMode'], 'type' => $data['type'], 'scope' => $data['scope'], 'value' => $data['value'],
            'conditions' => $data['conditions'] ?? null, 'starts_at' => $data['startsAt'] ?? null, 'ends_at' => $data['endsAt'] ?? null,
            'active_days' => isset($data['activeDays']) ? json_encode(array_values($data['activeDays'])) : null,
            'start_time' => $data['startTime'] ?? null, 'end_time' => $data['endTime'] ?? null,
            'minimum_order_amount' => $data['minimumOrderAmount'] ?? 0, 'maximum_discount_amount' => $data['maximumDiscountAmount'] ?? null,
            'usage_limit' => $data['usageLimit'] ?? null, 'usage_limit_per_customer' => $data['usageLimitPerCustomer'] ?? null,
            'customer_eligibility' => $data['customerEligibility'] ?? null, 'payment_method' => $data['paymentMethod'] ?? null,
            'is_active' => $data['isActive'], 'updated_at' => now(),
        ];
        return $creating ? ['tenant_id' => $tenantId, 'used_count' => 0, 'estimated_saved_value' => 0, 'created_at' => now()] + $payload : $payload;
    }

    private function assertTenantTargets(int $tenantId, array $data): void
    {
        foreach (['targetProductIds' => 'products', 'targetCategoryIds' => 'categories'] as $key => $table) {
            $ids = array_values(array_unique(array_map('intval', $data[$key] ?? [])));
            if ($ids && DB::table($table)->where('tenant_id', $tenantId)->whereNull('deleted_at')->whereIn('id', $ids)->count() !== count($ids)) {
                throw ValidationException::withMessages([$key => 'One or more selected targets do not belong to this tenant.']);
            }
        }
    }

    private function syncTargets(int $tenantId, int $discountId, array $data): void
    {
        DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->delete();
        $now = now();
        $rows = [];
        foreach (['targetProductIds' => 'product', 'targetCategoryIds' => 'category'] as $key => $type) {
            foreach (array_unique(array_map('intval', $data[$key] ?? [])) as $targetId) {
                $rows[] = ['tenant_id' => $tenantId, 'discount_id' => $discountId, 'target_type' => $type, 'target_id' => $targetId, 'created_at' => $now, 'updated_at' => $now];
            }
        }
        if (! $data['appliesToAllBranches']) {
            foreach (array_unique(array_map('intval', $data['branchIds'] ?? [])) as $branchId) {
                $rows[] = ['tenant_id' => $tenantId, 'discount_id' => $discountId, 'target_type' => 'branch', 'target_id' => $branchId, 'created_at' => $now, 'updated_at' => $now];
            }
        }
        if ($rows) DB::table('discount_targets')->insert($rows);
    }

    private function discountQuery(int $tenantId): Builder { return DB::table('discounts')->where('tenant_id', $tenantId)->whereNull('deleted_at'); }
    private function findManagedDiscount(int $tenantId, int $id): object { $discount = $this->discountQuery($tenantId)->where('id', $id)->first(); abort_if(! $discount, 404, 'Discount not found.'); return $discount; }
    private function findOrder(int $tenantId, int $orderId): object { $order = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderId)->whereNull('deleted_at')->first(); abort_if(! $order, 404, 'Order not found.'); return $order; }

    private function findDiscount(int $tenantId, array $data): object
    {
        $query = $this->discountQuery($tenantId)->where('is_active', true);
        ! empty($data['discountId']) ? $query->where('id', $data['discountId']) : $query->whereRaw('LOWER(code) = ?', [strtolower($data['code'])]);
        $discount = $query->first(); abort_if(! $discount, 404, 'Discount not found.'); return $discount;
    }

    private function assertEligible(int $tenantId, object $discount, object $order): void
    {
        if ($this->status($discount) !== 'active') throw ValidationException::withMessages(['discount' => 'Discount is not currently active.']);
        if ($discount->usage_limit !== null && $discount->used_count >= $discount->usage_limit) throw ValidationException::withMessages(['discount' => 'Discount usage limit has been reached.']);
        if ((float) $order->subtotal < (float) $discount->minimum_order_amount) throw ValidationException::withMessages(['discount' => 'Minimum order amount not reached.']);
        $branchTargets = $this->targetIds($tenantId, $discount->id, 'branch');
        if ($branchTargets && ! in_array((int) $order->branch_id, $branchTargets, true)) throw ValidationException::withMessages(['discount' => 'Discount is not available at this branch.']);
    }

    private function discountAmount(int $tenantId, object $order, object $discount): float
    {
        $eligibleSubtotal = $this->eligibleSubtotal($tenantId, $order, $discount);
        $amount = match ($discount->type) {
            'percentage' => $eligibleSubtotal * ((float) $discount->value / 100), 'fixed' => min((float) $discount->value, $eligibleSubtotal),
            'bogo' => $this->bogoAmount($tenantId, (int) $order->id, $discount), default => 0,
        };
        if ($discount->maximum_discount_amount !== null) $amount = min($amount, (float) $discount->maximum_discount_amount);
        return round(min($amount, $eligibleSubtotal), 2);
    }

    private function eligibleSubtotal(int $tenantId, object $order, object $discount): float
    {
        if ($discount->scope === 'order') return (float) $order->subtotal;
        $items = DB::table('order_items')->join('products', 'products.id', '=', 'order_items.product_id')
            ->where('order_items.tenant_id', $tenantId)->where('order_items.order_id', $order->id)->whereNull('order_items.deleted_at');
        $productIds = $this->targetIds($tenantId, $discount->id, 'product'); $categoryIds = $this->targetIds($tenantId, $discount->id, 'category');
        $items->where(function (Builder $query) use ($productIds, $categoryIds): void { if ($productIds) $query->whereIn('products.id', $productIds); if ($categoryIds) $productIds ? $query->orWhereIn('products.category_id', $categoryIds) : $query->whereIn('products.category_id', $categoryIds); });
        return (float) $items->sum('order_items.total');
    }

    private function bogoAmount(int $tenantId, int $orderId, object $discount): float
    {
        $items = DB::table('order_items')->join('products', 'products.id', '=', 'order_items.product_id')->where('order_items.tenant_id', $tenantId)->where('order_items.order_id', $orderId)->whereNull('order_items.deleted_at');
        $productIds = $this->targetIds($tenantId, $discount->id, 'product'); $categoryIds = $this->targetIds($tenantId, $discount->id, 'category');
        if ($productIds || $categoryIds) $items->where(function (Builder $query) use ($productIds, $categoryIds): void { if ($productIds) $query->whereIn('products.id', $productIds); if ($categoryIds) $productIds ? $query->orWhereIn('products.category_id', $categoryIds) : $query->whereIn('products.category_id', $categoryIds); });
        $item = $items->where('order_items.quantity', '>=', 2)->orderBy('order_items.unit_price')->first();
        return $item ? (float) $item->unit_price * floor((float) $item->quantity / max(2, (int) $discount->value + 1)) : 0;
    }

    private function targetIds(int $tenantId, int $discountId, string $type): array { return DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->where('target_type', $type)->pluck('target_id')->map(fn ($id) => (int) $id)->all(); }

    private function status(object $discount): string
    {
        if (! $discount->is_active) return 'inactive';
        if ($discount->starts_at && now()->lessThan(Carbon::parse($discount->starts_at))) return 'scheduled';
        if ($discount->ends_at && now()->greaterThan(Carbon::parse($discount->ends_at))) return 'expired';
        return 'active';
    }

    private function serializeManagementDiscount(int $tenantId, object $discount): array
    {
        $targets = DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->get()->groupBy('target_type');
        return [
            'id' => (int) $discount->id, 'name' => $discount->name, 'code' => $discount->code, 'description' => $discount->description,
            'applicationMode' => $discount->application_mode, 'type' => $discount->type, 'scope' => $discount->scope, 'value' => (float) $discount->value,
            'conditions' => $discount->conditions, 'startsAt' => $discount->starts_at, 'endsAt' => $discount->ends_at,
            'activeDays' => $discount->active_days ? json_decode($discount->active_days, true) : [], 'startTime' => $discount->start_time, 'endTime' => $discount->end_time,
            'minimumOrderAmount' => (float) $discount->minimum_order_amount, 'maximumDiscountAmount' => $discount->maximum_discount_amount === null ? null : (float) $discount->maximum_discount_amount,
            'usageLimit' => $discount->usage_limit, 'usageLimitPerCustomer' => $discount->usage_limit_per_customer, 'usedCount' => (int) $discount->used_count,
            'estimatedSavedValue' => (float) $discount->estimated_saved_value, 'customerEligibility' => $discount->customer_eligibility, 'paymentMethod' => $discount->payment_method,
            'isActive' => (bool) $discount->is_active, 'status' => $this->status($discount), 'displayPeriodPrimary' => $discount->display_period_primary, 'displayPeriodSecondary' => $discount->display_period_secondary,
            'targetProductIds' => ($targets['product'] ?? collect())->pluck('target_id')->map(fn ($id) => (int) $id)->values(), 'targetCategoryIds' => ($targets['category'] ?? collect())->pluck('target_id')->map(fn ($id) => (int) $id)->values(),
            'appliesToAllBranches' => ! $targets->has('branch'), 'branchIds' => ($targets['branch'] ?? collect())->pluck('target_id')->map(fn ($id) => (int) $id)->values(),
        ];
    }

    private function serializeDiscount(object $discount, ?object $order): array
    {
        $eligible = ! $order || (float) $order->subtotal >= (float) $discount->minimum_order_amount;
        return ['id' => $discount->id, 'name' => $discount->name, 'code' => $discount->code, 'type' => $discount->type, 'value' => (float) $discount->value,
            'badge' => match ($discount->type) {'percentage' => ((float) $discount->value).'% OFF', 'fixed' => '-$'.number_format((float) $discount->value, 2), 'bogo' => 'BOGO', default => strtoupper($discount->type)},
            'minimumOrderAmount' => (float) $discount->minimum_order_amount, 'eligible' => $eligible, 'message' => $eligible ? null : 'Minimum order amount not reached.', 'validUntil' => $discount->ends_at];
    }
}
