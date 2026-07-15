<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PosPricingService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class DiscountController extends Controller
{
    public function __construct(private readonly PosPricingService $pricing)
    {
    }

    public function available(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $order = $request->filled('orderId')
            ? $this->findOrder($tenantId, (int) $request->query('orderId'))
            : null;

        $discounts = DB::table('discounts')
            ->where('tenant_id', $tenantId)
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->where(fn ($query) => $query->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn ($query) => $query->whereNull('ends_at')->orWhere('ends_at', '>=', now()))
            ->orderBy('id')
            ->get()
            ->map(fn ($discount) => $this->serializeDiscount($discount, $order));

        return response()->json(['data' => $discounts]);
    }

    public function apply(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'code' => ['nullable', 'string'],
            'discountId' => ['nullable', 'integer', 'exists:discounts,id'],
            'reason' => ['nullable', 'string'],
        ]);

        if (empty($data['code']) && empty($data['discountId'])) {
            throw ValidationException::withMessages(['discount' => 'A coupon code or discountId is required.']);
        }

        $tenantId = TenantContext::id($request);
        $orderRow = $this->findOrder($tenantId, $order);
        $discount = $this->findDiscount($tenantId, $data);
        $this->assertEligible($discount, $orderRow);

        $amount = $this->discountAmount($tenantId, $orderRow, $discount);

        DB::transaction(function () use ($tenantId, $order, $discount, $amount, $data): void {
            DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order)->delete();
            DB::table('order_discounts')->insert([
                'tenant_id' => $tenantId,
                'order_id' => $order,
                'discount_id' => $discount->id,
                'discount_name' => $data['reason'] ?? $discount->name,
                'discount_type' => $discount->type,
                'discount_value' => $discount->value,
                'discount_amount' => $amount,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $discount->id)->increment('used_count');
            $this->pricing->recalculateOrder($tenantId, $order);
        });

        $updated = $this->findOrder($tenantId, $order);

        return response()->json([
            'data' => [
                'orderId' => $order,
                'discount' => [
                    'id' => $discount->id,
                    'name' => $discount->name,
                    'code' => $discount->code,
                    'type' => $discount->type,
                    'value' => (float) $discount->value,
                    'amount' => $amount,
                ],
                'totals' => [
                    'subtotal' => (float) $updated->subtotal,
                    'discountTotal' => (float) $updated->discount_total,
                    'taxTotal' => (float) $updated->tax_total,
                    'total' => (float) $updated->total,
                ],
            ],
        ]);
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

    private function findOrder(int $tenantId, int $orderId): object
    {
        $order = DB::table('orders')
            ->where('tenant_id', $tenantId)
            ->where('id', $orderId)
            ->whereNull('deleted_at')
            ->first();

        abort_if(! $order, 404, 'Order not found.');

        return $order;
    }

    private function findDiscount(int $tenantId, array $data): object
    {
        $query = DB::table('discounts')
            ->where('tenant_id', $tenantId)
            ->where('is_active', true)
            ->whereNull('deleted_at');

        if (! empty($data['discountId'])) {
            $query->where('id', $data['discountId']);
        } else {
            $query->whereRaw('LOWER(code) = ?', [strtolower($data['code'])]);
        }

        $discount = $query->first();
        abort_if(! $discount, 404, 'Discount not found.');

        return $discount;
    }

    private function assertEligible(object $discount, object $order): void
    {
        if ($discount->starts_at && now()->lessThan(\Illuminate\Support\Carbon::parse($discount->starts_at))) {
            throw ValidationException::withMessages(['discount' => 'Discount is not active yet.']);
        }

        if ($discount->ends_at && now()->greaterThan(\Illuminate\Support\Carbon::parse($discount->ends_at))) {
            throw ValidationException::withMessages(['discount' => 'Discount has expired.']);
        }

        if ($discount->usage_limit !== null && $discount->used_count >= $discount->usage_limit) {
            throw ValidationException::withMessages(['discount' => 'Discount usage limit has been reached.']);
        }

        if ((float) $order->subtotal < (float) $discount->minimum_order_amount) {
            $minimum = number_format((float) $discount->minimum_order_amount, 2);
            throw ValidationException::withMessages(['discount' => "Minimum order amount (\${$minimum}) not reached."]);
        }
    }

    private function discountAmount(int $tenantId, object $order, object $discount): float
    {
        $subtotal = (float) $order->subtotal;

        $amount = match ($discount->type) {
            'percentage' => $subtotal * ((float) $discount->value / 100),
            'fixed' => (float) $discount->value,
            'bogo' => $this->bogoAmount($tenantId, (int) $order->id),
            default => 0,
        };

        if ($discount->maximum_discount_amount !== null) {
            $amount = min($amount, (float) $discount->maximum_discount_amount);
        }

        return round(min($amount, $subtotal), 2);
    }

    private function bogoAmount(int $tenantId, int $orderId): float
    {
        $item = DB::table('order_items')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $orderId)
            ->whereNull('deleted_at')
            ->where('quantity', '>=', 2)
            ->orderBy('unit_price')
            ->first();

        return $item ? (float) $item->unit_price : 0;
    }

    private function serializeDiscount(object $discount, ?object $order): array
    {
        $eligible = true;
        $message = null;

        if ($order && (float) $order->subtotal < (float) $discount->minimum_order_amount) {
            $eligible = false;
            $message = 'Minimum order amount ($'.number_format((float) $discount->minimum_order_amount, 2).') not reached.';
        }

        return [
            'id' => $discount->id,
            'name' => $discount->name,
            'code' => $discount->code,
            'type' => $discount->type,
            'value' => (float) $discount->value,
            'badge' => match ($discount->type) {
                'percentage' => ((float) $discount->value).'% OFF',
                'fixed' => '-$'.number_format((float) $discount->value, 2),
                'bogo' => 'BOGO',
                default => strtoupper($discount->type),
            },
            'minimumOrderAmount' => (float) $discount->minimum_order_amount,
            'eligible' => $eligible,
            'message' => $message,
            'validUntil' => $discount->ends_at,
        ];
    }
}
