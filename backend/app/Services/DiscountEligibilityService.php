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
    public function assertApplicable(int $tenantId, object $discount, object $order, ?string $paymentMethod = null): array
    {
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $order->branch_id)->whereNull('deleted_at')->first();
        if (! $branch) {
            throw new OrderLifecycleException('DISCOUNT_BRANCH_NOT_ELIGIBLE', 'The order branch is unavailable.');
        }

        $now = CarbonImmutable::now($branch->timezone ?: 'UTC');
        $this->assertSchedule($discount, $now);
        $this->assertBranch($tenantId, $discount, $order);
        $this->assertCustomer($tenantId, $discount, $order);
        if ($paymentMethod !== null) {
            $this->assertPaymentMethod($discount, $paymentMethod);
        }

        // Existing semantics define the minimum against the pre-discount
        // whole-order subtotal, not the targeted-item subtotal.
        if ((float) $order->subtotal < (float) $discount->minimum_order_amount) {
            throw new OrderLifecycleException('DISCOUNT_MINIMUM_NOT_MET', 'The minimum order amount has not been reached.');
        }

        $eligibleSubtotal = $this->eligibleSubtotal($tenantId, $order, $discount);
        if (in_array($discount->scope, ['product', 'category'], true) && $eligibleSubtotal <= 0) {
            throw new OrderLifecycleException('DISCOUNT_ITEMS_NOT_ELIGIBLE', 'No order items are eligible for this discount.');
        }

        $amount = match ($discount->type) {
            'percentage' => $eligibleSubtotal * ((float) $discount->value / 100),
            'fixed' => min((float) $discount->value, $eligibleSubtotal),
            'bogo' => $this->bogoAmount($tenantId, (int) $order->id, $discount),
            default => 0,
        };
        if ($discount->maximum_discount_amount !== null) {
            $amount = min($amount, (float) $discount->maximum_discount_amount);
        }

        return ['eligibleSubtotal' => round($eligibleSubtotal, 2), 'amount' => round(min($amount, $eligibleSubtotal), 2)];
    }

    /** Refresh a draft discount after cart/customer mutations, or reject it at payment. */
    public function refreshAppliedDiscounts(int $tenantId, object $order, ?string $paymentMethod = null, bool $rejectInvalid = false): void
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
                $result = $this->assertApplicable($tenantId, $discount, $order, $paymentMethod);
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
            DB::table('discount_usages')->insert([
                'tenant_id' => $tenantId, 'discount_id' => $discount->id, 'order_id' => $order->id,
                'payment_id' => $paymentId, 'customer_id' => $order->customer_id,
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
        if ($discount->starts_at && $now->lessThan(CarbonImmutable::parse($discount->starts_at))) {
            throw new OrderLifecycleException('DISCOUNT_NOT_STARTED', 'This discount has not started yet.');
        }
        if ($discount->ends_at && $now->greaterThan(CarbonImmutable::parse($discount->ends_at))) {
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

    private function assertCustomer(int $tenantId, object $discount, object $order): void
    {
        $policy = strtolower(trim((string) $discount->customer_eligibility));
        if ($policy === '' || $policy === 'all customers') {
            return;
        }
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

    private function assertPaymentMethod(object $discount, string $paymentMethod): void
    {
        $policy = strtolower(trim((string) $discount->payment_method));
        if ($policy === '' || $policy === 'any payment method' || $policy === strtolower($paymentMethod)) {
            return;
        }
        throw new OrderLifecycleException('DISCOUNT_PAYMENT_METHOD_NOT_ALLOWED', 'This discount is not available with the selected payment method.');
    }

    private function eligibleSubtotal(int $tenantId, object $order, object $discount): float
    {
        if ($discount->scope === 'order') {
            return (float) $order->subtotal;
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

    private function bogoAmount(int $tenantId, int $orderId, object $discount): float
    {
        $eligible = $this->eligibleItems($tenantId, $orderId, $discount);
        $item = $eligible->where('order_items.quantity', '>=', 2)->orderBy('order_items.unit_price')->first();

        return $item ? (float) $item->unit_price * floor((float) $item->quantity / max(2, (int) $discount->value + 1)) : 0;
    }

    private function eligibleItems(int $tenantId, int $orderId, object $discount): Builder
    {
        $order = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderId)->first();
        $items = DB::table('order_items')->leftJoin('products', 'products.id', '=', 'order_items.product_id')->where('order_items.tenant_id', $tenantId)->where('order_items.order_id', $orderId)->whereNull('order_items.deleted_at');
        $products = $this->targetIds($tenantId, $discount->id, 'product');
        $categories = $this->targetIds($tenantId, $discount->id, 'category');
        if ($products || $categories) {
            $items->where(function (Builder $query) use ($products, $categories, $order): void {
                if ($products) {
                    $query->whereIn('order_items.product_id', $products);
                }
                if ($categories) {
                    $products ? $query->orWhereIn($order->published_menu_version_id === null ? 'products.category_id' : 'order_items.category_id', $categories) : $query->whereIn($order->published_menu_version_id === null ? 'products.category_id' : 'order_items.category_id', $categories);
                }
            });
        }

        return $items;
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
