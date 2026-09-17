<?php

namespace App\Services;

use App\Exceptions\OrderLifecycleException;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/**
 * Authoritative runtime policy for configured discounts.  This service only
 * accepts persisted Order state; callers must never pass client totals, time,
 * branch, or customer information to it.
 */
class DiscountEligibilityService
{
    public function assertApplicable(int $tenantId, object $discount, object $order, ?int $paymentMethodId = null, ?string $legacyPaymentMethod = null): array
    {
        if ($discount->type === 'bogo') {
            throw new OrderLifecycleException('DISCOUNT_BOGO_UNSUPPORTED', 'BOGO discounts are not supported for new orders.');
        }
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $order->branch_id)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $branch) {
            throw new OrderLifecycleException('DISCOUNT_BRANCH_NOT_ELIGIBLE', 'The order branch is unavailable.');
        }

        $now = CarbonImmutable::now($branch->timezone ?: 'UTC');
        $this->assertSchedule($discount, $now);
        $this->assertBranch($tenantId, $discount, $order);
        $this->assertChannel($tenantId, $discount, $order);
        $this->assertCustomer($tenantId, $discount, $order);
        if ($paymentMethodId !== null) {
            $this->assertPaymentMethod($tenantId, $discount, $paymentMethodId, $legacyPaymentMethod);
        }

        // Existing semantics define the minimum against the pre-discount
        // whole-order subtotal, not the targeted-item subtotal.
        if ((float) $order->subtotal < (float) $discount->minimum_order_amount) {
            throw new OrderLifecycleException('DISCOUNT_MINIMUM_NOT_MET', 'The minimum order amount has not been reached.');
        }

        $this->assertUsageAvailable($tenantId, $discount, $order, $branch);

        $eligibleSubtotal = $this->eligibleSubtotal($tenantId, $order, $discount);
        if (in_array($discount->scope, ['product', 'category', 'bundle'], true) && $eligibleSubtotal <= 0) {
            throw new OrderLifecycleException('DISCOUNT_ITEMS_NOT_ELIGIBLE', 'No order items are eligible for this discount.');
        }

        $amount = match ($discount->type) {
            'percentage' => $eligibleSubtotal * ((float) $discount->value / 100),
            'fixed' => min((float) $discount->value, $eligibleSubtotal),
            default => 0,
        };
        if ($discount->maximum_discount_amount !== null) {
            $amount = min($amount, (float) $discount->maximum_discount_amount);
        }

        return ['eligibleSubtotal' => round($eligibleSubtotal, 2), 'amount' => round(max(0, min($amount, $eligibleSubtotal)), 2)];
    }

    /** Refresh a draft discount after cart/customer mutations, or reject it at payment. */
    public function refreshAppliedDiscounts(int $tenantId, object $order, ?int $paymentMethodId = null, ?string $legacyPaymentMethod = null, bool $rejectInvalid = false): void
    {
        $rows = DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order->id)->get();
        foreach ($rows as $row) {
            // POS manager/manual discounts have no configurable policy to revalidate.
            if ($row->discount_id === null) {
                continue;
            }
            $discount = DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $row->discount_id)->whereNull('deleted_at')->lockForUpdate()->first();
            try {
                if (! $discount) {
                    throw new OrderLifecycleException('DISCOUNT_INACTIVE', 'The configured discount is no longer available.');
                }
                $result = $this->assertApplicable($tenantId, $discount, $order, $paymentMethodId, $legacyPaymentMethod);
                DB::table('order_discounts')->where('id', $row->id)->update([
                    'discount_type' => $discount->type,
                    'discount_value' => $discount->value,
                    'discount_amount' => $result['amount'],
                    'updated_at' => now(),
                ]);
            } catch (OrderLifecycleException $exception) {
                if ($rejectInvalid) {
                    throw $exception;
                }
                // Draft cart mutations must never leave a stale managed discount.
                DB::table('order_discounts')->where('id', $row->id)->delete();
            }
        }
    }

    /**
     * Consumes a completed-sale usage while the discount row is locked.  The
     * caller already holds the Order lock, so an idempotent payment retry sees
     * its existing payment before this method can run again.
     */
    public function consumeUsage(int $tenantId, object $order, int $paymentId): void
    {
        $rows = DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order->id)->whereNotNull('discount_id')->get();
        foreach ($rows as $row) {
            if (DB::table('discount_usages')->where('order_id', $order->id)->exists()) {
                return;
            }
            $discount = DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $row->discount_id)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $discount) {
                throw new OrderLifecycleException('DISCOUNT_INACTIVE', 'The configured discount is no longer available.');
            }
            $globalUses = DB::table('discount_usages')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->count();
            if ($discount->usage_limit !== null && $globalUses >= $discount->usage_limit) {
                throw new OrderLifecycleException('DISCOUNT_USAGE_LIMIT_REACHED', 'The discount usage limit has been reached.');
            }
            if ($discount->usage_limit_per_customer !== null) {
                if ($order->customer_id === null) {
                    throw new OrderLifecycleException('DISCOUNT_CUSTOMER_REQUIRED', 'This discount requires an identified customer.');
                }
                $customerUses = DB::table('discount_usages')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->where('customer_id', $order->customer_id)->count();
                if ($customerUses >= $discount->usage_limit_per_customer) {
                    throw new OrderLifecycleException('DISCOUNT_USAGE_LIMIT_REACHED', 'The customer usage limit has been reached.');
                }
            }
            $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $order->branch_id)->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $branch) {
                throw new OrderLifecycleException('DISCOUNT_BRANCH_NOT_ELIGIBLE', 'The order branch is unavailable.');
            }
            $businessDate = $this->businessDate($branch);
            if ($discount->usage_limit_per_customer_per_day !== null) {
                if ($order->customer_id === null) {
                    throw new OrderLifecycleException('DISCOUNT_CUSTOMER_REQUIRED', 'This discount requires an identified customer.');
                }
                $dailyUses = DB::table('discount_usages')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)
                    ->where('customer_id', $order->customer_id)->where('business_date', $businessDate)->count();
                if ($dailyUses >= $discount->usage_limit_per_customer_per_day) {
                    throw new OrderLifecycleException('DISCOUNT_DAILY_USAGE_LIMIT_REACHED', 'The customer daily usage limit has been reached.');
                }
            }
            DB::table('discount_usages')->insert([
                'tenant_id' => $tenantId, 'discount_id' => $discount->id, 'order_id' => $order->id,
                'payment_id' => $paymentId, 'customer_id' => $order->customer_id, 'business_date' => $businessDate,
                'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('discounts')->where('id', $discount->id)->increment('used_count');
        }
    }

    private function assertSchedule(object $discount, CarbonImmutable $now): void
    {
        if (! $discount->is_active) {
            throw new OrderLifecycleException('DISCOUNT_INACTIVE', 'This discount is inactive.');
        }
        $today = $now->toDateString();
        if ($discount->start_date && $today < $discount->start_date) {
            throw new OrderLifecycleException('DISCOUNT_NOT_STARTED', 'This discount has not started yet.');
        }
        if ($discount->end_date && $today > $discount->end_date) {
            throw new OrderLifecycleException('DISCOUNT_EXPIRED', 'This discount has expired.');
        }
        // Legacy timestamps retain their original instant semantics. Canonical
        // V1 date-only fields above are branch-local and never use app time.
        if ($discount->start_date === null && $discount->starts_at && CarbonImmutable::now('UTC')->lessThan(CarbonImmutable::parse($discount->starts_at, 'UTC'))) {
            throw new OrderLifecycleException('DISCOUNT_NOT_STARTED', 'This discount has not started yet.');
        }
        if ($discount->end_date === null && $discount->ends_at && CarbonImmutable::now('UTC')->greaterThan(CarbonImmutable::parse($discount->ends_at, 'UTC'))) {
            throw new OrderLifecycleException('DISCOUNT_EXPIRED', 'This discount has expired.');
        }
        $days = $discount->active_days ? json_decode($discount->active_days, true) : [];
        if ($days && ! in_array($now->format('D'), $days, true)) {
            throw new OrderLifecycleException('DISCOUNT_DAY_NOT_ALLOWED', 'This discount is not available today.');
        }
        if (! $this->withinTimeWindow($now, $discount->start_time, $discount->end_time)) {
            throw new OrderLifecycleException('DISCOUNT_TIME_NOT_ALLOWED', 'This discount is not available at this time.');
        }
    }

    private function withinTimeWindow(CarbonImmutable $now, ?string $start, ?string $end): bool
    {
        if (! $start && ! $end) {
            return true;
        }
        $time = $now->hour * 3600 + $now->minute * 60 + $now->second;
        $startSeconds = $start ? $this->timeSeconds($start) : null;
        $endSeconds = $end ? $this->timeSeconds($end) : null;
        if ($startSeconds === null) {
            return $time <= $endSeconds;
        }
        if ($endSeconds === null) {
            return $time >= $startSeconds;
        }

        // An end before the start is an explicitly supported overnight window.
        return $startSeconds <= $endSeconds
            ? $time >= $startSeconds && $time <= $endSeconds
            : $time >= $startSeconds || $time <= $endSeconds;
    }

    private function assertBranch(int $tenantId, object $discount, object $order): void
    {
        $targets = $this->targetIds($tenantId, $discount->id, 'branch');
        if ($targets && ! in_array((int) $order->branch_id, $targets, true)) {
            throw new OrderLifecycleException('DISCOUNT_BRANCH_NOT_ELIGIBLE', 'This discount is not available at the order branch.');
        }
    }

    private function assertChannel(int $tenantId, object $discount, object $order): void
    {
        $channels = DB::table('discount_channel_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->pluck('channel_key')->all();
        if ($channels && ! in_array((string) ($order->sales_channel ?? 'pos'), $channels, true)) {
            throw new OrderLifecycleException('DISCOUNT_CHANNEL_NOT_ELIGIBLE', 'This discount is not available for the order sales channel.');
        }
    }

    private function assertCustomer(int $tenantId, object $discount, object $order): void
    {
        $mode = strtolower(trim((string) $discount->customer_eligibility));
        if ($mode === 'selected_customers') {
            if ($order->customer_id === null) {
                throw new OrderLifecycleException('DISCOUNT_CUSTOMER_REQUIRED', 'This discount requires an identified customer.');
            }
            $customerIds = $this->targetIds($tenantId, $discount->id, 'customer');
            $eligible = $customerIds && in_array((int) $order->customer_id, $customerIds, true)
                && DB::table('customers')->where('tenant_id', $tenantId)->where('id', $order->customer_id)->where('is_active', true)->whereNull('deleted_at')->exists();
            if (! $eligible) {
                throw new OrderLifecycleException('DISCOUNT_CUSTOMER_NOT_ELIGIBLE', 'The order customer is not eligible for this discount.');
            }

            return;
        }
        $groupIds = $this->targetIds($tenantId, $discount->id, 'customer_group');
        if (! $groupIds) {
            // Historical, pre-V1 records remain readable and executable. New
            // V1 policies always use explicit Customer Group targets instead.
            $policy = strtolower(trim((string) $discount->customer_eligibility));
            if ($policy === '' || $policy === 'all customers') {
                return;
            }
            $this->assertLegacyCustomer($tenantId, $order, $policy);

            return;
        }
        if ($order->customer_id === null) {
            throw new OrderLifecycleException('DISCOUNT_CUSTOMER_REQUIRED', 'This discount requires an identified customer.');
        }
        $eligible = DB::table('customer_group_memberships as memberships')
            ->join('customer_groups as groups', 'groups.id', '=', 'memberships.customer_group_id')
            ->join('customers', 'customers.id', '=', 'memberships.customer_id')
            ->where('memberships.tenant_id', $tenantId)->where('memberships.customer_id', $order->customer_id)
            ->whereIn('memberships.customer_group_id', $groupIds)
            ->where('groups.tenant_id', $tenantId)->where('groups.is_active', true)->whereNull('groups.deleted_at')
            ->where('customers.tenant_id', $tenantId)->where('customers.is_active', true)->whereNull('customers.deleted_at')
            ->exists();
        if (! $eligible) {
            throw new OrderLifecycleException('DISCOUNT_CUSTOMER_NOT_ELIGIBLE', 'The order customer is not eligible for this discount.');
        }
    }

    private function assertLegacyCustomer(int $tenantId, object $order, string $policy): void
    {
        if ($order->customer_id === null) {
            throw new OrderLifecycleException('DISCOUNT_CUSTOMER_REQUIRED', 'This discount requires an identified customer.');
        }
        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $order->customer_id)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $customer) {
            throw new OrderLifecycleException('DISCOUNT_CUSTOMER_NOT_ELIGIBLE', 'The order customer is not eligible for this discount.');
        }
        $eligible = match ($policy) {
            'regular' => (float) $customer->total_spent >= 250 && (float) $customer->total_spent < 1000,
            'vip' => (float) $customer->total_spent >= 1000,
            'new customers' => (int) $customer->visits_count === 0,
            default => false,
        };
        if (! $eligible) {
            throw new OrderLifecycleException('DISCOUNT_CUSTOMER_NOT_ELIGIBLE', 'The order customer is not eligible for this discount.');
        }
    }

    private function assertPaymentMethod(int $tenantId, object $discount, int $paymentMethodId, ?string $legacyPaymentMethod): void
    {
        $allowedIds = $this->targetIds($tenantId, $discount->id, 'payment_method');
        if ($allowedIds) {
            if (! in_array($paymentMethodId, $allowedIds, true)) {
                throw new OrderLifecycleException('DISCOUNT_PAYMENT_METHOD_NOT_ALLOWED', 'This discount is not available with the selected payment method.');
            }

            return;
        }
        $policy = strtolower(trim((string) $discount->payment_method));
        if ($policy === '' || $policy === 'any payment method' || $policy === strtolower((string) $legacyPaymentMethod)) {
            return;
        }
        throw new OrderLifecycleException('DISCOUNT_PAYMENT_METHOD_NOT_ALLOWED', 'This discount is not available with the selected payment method.');
    }

    private function eligibleSubtotal(int $tenantId, object $order, object $discount): float
    {
        if ($discount->scope === 'order') {
            return (float) $order->subtotal;
        }
        if ($discount->scope === 'bundle') {
            return $this->bundleSubtotal($tenantId, $order, $discount);
        }
        $productIds = $this->targetIds($tenantId, $discount->id, 'product');
        $categoryIds = $this->targetIds($tenantId, $discount->id, 'category');
        $items = DB::table('order_items')->leftJoin('products', 'products.id', '=', 'order_items.product_id')
            ->where('order_items.tenant_id', $tenantId)->where('order_items.order_id', $order->id)->whereNull('order_items.deleted_at');
        $items->where(function (Builder $query) use ($productIds, $categoryIds, $order): void {
            if ($productIds) {
                $query->whereIn('order_items.product_id', $productIds);
            }
            if ($categoryIds) {
                // Versioned orders persist the category selected from their published
                // menu payload. Legacy orders intentionally retain live fallback.
                $categoryColumn = $order->published_menu_version_id === null ? 'products.category_id' : 'order_items.category_id';
                $productIds ? $query->orWhereIn($categoryColumn, $categoryIds) : $query->whereIn($categoryColumn, $categoryIds);
            }
        });

        return (float) $items->sum('order_items.total');
    }

    /**
     * Prices are derived only from immutable order items. One requirement set
     * is selected, even where an order contains enough units for many bundles.
     */
    private function bundleSubtotal(int $tenantId, object $order, object $discount): float
    {
        $requirements = DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $discount->id)->orderBy('product_id')->get();
        if ($requirements->isEmpty()) {
            return 0.0;
        }
        $itemsByProduct = DB::table('order_items')->where('tenant_id', $tenantId)->where('order_id', $order->id)->whereNull('deleted_at')
            ->whereIn('product_id', $requirements->pluck('product_id'))->orderBy('id')->get()->groupBy('product_id');
        $subtotal = 0.0;
        foreach ($requirements as $requirement) {
            $remaining = (float) $requirement->quantity;
            foreach ($itemsByProduct->get($requirement->product_id, collect()) as $item) {
                $taken = min($remaining, (float) $item->quantity);
                $subtotal += $taken * (float) $item->unit_price;
                $remaining -= $taken;
                if ($remaining <= 0.00001) {
                    break;
                }
            }
            if ($remaining > 0.00001) {
                return 0.0;
            }
        }

        return round($subtotal, 2);
    }

    private function assertUsageAvailable(int $tenantId, object $discount, object $order, object $branch): void
    {
        if ($discount->usage_limit === null && $discount->usage_limit_per_customer === null && $discount->usage_limit_per_customer_per_day === null) {
            return;
        }
        $usages = DB::table('discount_usages')->where('tenant_id', $tenantId)->where('discount_id', $discount->id);
        if ($discount->usage_limit !== null && (clone $usages)->count() >= $discount->usage_limit) {
            throw new OrderLifecycleException('DISCOUNT_USAGE_LIMIT_REACHED', 'The discount usage limit has been reached.');
        }
        if ($discount->usage_limit_per_customer !== null || $discount->usage_limit_per_customer_per_day !== null) {
            if ($order->customer_id === null) {
                throw new OrderLifecycleException('DISCOUNT_CUSTOMER_REQUIRED', 'This discount requires an identified customer.');
            }
            $customerUsages = (clone $usages)->where('customer_id', $order->customer_id);
            if ($discount->usage_limit_per_customer !== null && (clone $customerUsages)->count() >= $discount->usage_limit_per_customer) {
                throw new OrderLifecycleException('DISCOUNT_USAGE_LIMIT_REACHED', 'The customer usage limit has been reached.');
            }
            if ($discount->usage_limit_per_customer_per_day !== null && $customerUsages->where('business_date', $this->businessDate($branch))->count() >= $discount->usage_limit_per_customer_per_day) {
                throw new OrderLifecycleException('DISCOUNT_DAILY_USAGE_LIMIT_REACHED', 'The customer daily usage limit has been reached.');
            }
        }
    }

    private function businessDate(object $branch): string
    {
        return CarbonImmutable::now($branch->timezone ?: 'UTC')->toDateString();
    }

    private function targetIds(int $tenantId, int $discountId, string $type): array
    {
        return DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->where('target_type', $type)->pluck('target_id')->map(fn ($id) => (int) $id)->all();
    }

    private function timeSeconds(string $time): int
    {
        [$hour, $minute, $second] = array_pad(array_map('intval', explode(':', $time)), 3, 0);

        return $hour * 3600 + $minute * 60 + $second;
    }
}
