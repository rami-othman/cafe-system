<?php

namespace App\Services;

use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PosPricingService
{
    public function __construct(private readonly DiscountEligibilityService $discounts) {}

    public function priceItem(int $tenantId, int $productId, int|float $quantity, array $modifiers = []): array
    {
        $product = DB::table('products')
            ->where('tenant_id', $tenantId)
            ->where('id', $productId)
            ->whereNull('deleted_at')
            ->first();

        if (! $product || ! $product->is_active) {
            throw ValidationException::withMessages(['productId' => 'Product is not available.']);
        }

        $selectedOptions = $this->selectedOptions($tenantId, $productId, $modifiers);
        // Database decimals are strings. Sum in integer minor units so a
        // signed modifier cannot introduce binary-float drift or a negative
        // sell price.
        $unitCents = $this->minorUnits((string) $product->price);
        foreach ($selectedOptions as $option) {
            $unitCents += $this->minorUnits((string) $option->price_delta);
        }
        if ($unitCents < 0) {
            throw ValidationException::withMessages(['modifiers' => 'Selected modifiers result in an invalid negative unit price.']);
        }
        $unitPrice = $unitCents / 100;

        return [
            'product' => $product,
            'selected_options' => $selectedOptions,
            'unit_price' => round($unitPrice, 2),
            'line_total' => round($unitPrice * (float) $quantity, 2),
        ];
    }

    public function recalculateOrder(int $tenantId, int $orderId, bool $rejectInvalidDiscount = false, ?string $paymentMethod = null): object
    {
        $order = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderId)->whereNull('deleted_at')->first();
        abort_if(! $order, 404, 'Order not found.');
        $subtotal = (float) DB::table('order_items')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $orderId)
            ->whereNull('deleted_at')
            ->sum('total');
        // Eligibility uses the current cart, even though the persisted order
        // total is only written after the discount result is known.
        $order->subtotal = $subtotal;
        // Draft cart mutations recalculate a managed discount or remove it if
        // current authoritative Order state no longer satisfies the policy.
        if (in_array($order->status, ['draft', 'held'], true) && $order->payment_status === 'unpaid') {
            $this->discounts->refreshAppliedDiscounts($tenantId, $order, $paymentMethod, $rejectInvalidDiscount);
        }

        $discountTotal = (float) DB::table('order_discounts')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $orderId)
            ->sum('discount_amount');

        $taxable = max(0, $subtotal - $discountTotal);
        $taxTotal = round($taxable * (float) $order->tax_rate, 2);
        $total = round($taxable + $taxTotal, 2);

        DB::table('orders')
            ->where('tenant_id', $tenantId)
            ->where('id', $orderId)
            ->update([
                'subtotal' => $subtotal,
                'discount_total' => $discountTotal,
                'tax_total' => $taxTotal,
                'total' => $total,
                'updated_at' => now(),
            ]);

        return DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderId)->first();
    }

    private function selectedOptions(int $tenantId, int $productId, array $modifiers): Collection
    {
        $groups = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->where('product_modifier_group.tenant_id', $tenantId)
            ->where('product_modifier_group.product_id', $productId)
            ->where('modifier_groups.is_active', true)
            ->whereNull('modifier_groups.deleted_at')
            ->select([
                'modifier_groups.id',
                'modifier_groups.name',
                'modifier_groups.selection_type',
                'modifier_groups.is_required',
                'modifier_groups.min_selections',
                'modifier_groups.max_selections',
            ])
            ->get();

        $optionIds = collect($modifiers)->pluck('optionId')->filter()->map(fn ($id) => (int) $id)->values();

        if ($optionIds->isEmpty()) {
            $requiredGroup = $groups->first(fn ($group) => $group->is_required || $group->min_selections > 0);

            if ($requiredGroup) {
                throw ValidationException::withMessages(['modifiers' => "{$requiredGroup->name} is required."]);
            }

            return collect();
        }

        $options = DB::table('modifier_options')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'modifier_options.modifier_group_id')
            ->join('product_modifier_group', 'product_modifier_group.modifier_group_id', '=', 'modifier_groups.id')
            ->where('modifier_options.tenant_id', $tenantId)
            ->where('product_modifier_group.product_id', $productId)
            ->whereIn('modifier_options.id', $optionIds)
            ->where('modifier_options.is_available', true)
            ->where('modifier_groups.is_active', true)
            ->whereNull('modifier_options.deleted_at')
            ->whereNull('modifier_groups.deleted_at')
            ->select([
                'modifier_options.id',
                'modifier_options.modifier_group_id',
                'modifier_options.name',
                'modifier_options.price_delta',
                'modifier_groups.name as group_name',
            ])
            ->get();

        if ($options->count() !== $optionIds->count()) {
            throw ValidationException::withMessages(['modifiers' => 'One or more selected modifiers are invalid.']);
        }

        $optionsByGroup = $options->groupBy('modifier_group_id');

        foreach ($groups as $group) {
            $count = $optionsByGroup->get($group->id, collect())->count();

            if (($group->is_required || $group->min_selections > 0) && $count < $group->min_selections) {
                throw ValidationException::withMessages(['modifiers' => "{$group->name} requires at least {$group->min_selections} selection(s)."]);
            }

            if ($count > $group->max_selections) {
                throw ValidationException::withMessages(['modifiers' => "{$group->name} allows at most {$group->max_selections} selection(s)."]);
            }

            if ($group->selection_type === 'single' && $count > 1) {
                throw ValidationException::withMessages(['modifiers' => "{$group->name} allows only one selection."]);
            }
        }

        return $options;
    }

    private function minorUnits(string $value): int
    {
        $negative = str_starts_with($value, '-');
        $value = ltrim($value, '+-');
        [$whole, $fraction] = array_pad(explode('.', $value, 2), 2, '');
        $cents = ((int) $whole * 100) + (int) str_pad(substr($fraction, 0, 2), 2, '0');

        return $negative ? -$cents : $cents;
    }
}
