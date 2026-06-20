<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PosPricingService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PosOrderController extends Controller
{
    public function __construct(private readonly PosPricingService $pricing)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        $query = DB::table('orders')
            ->where('tenant_id', $tenantId)
            ->whereNull('deleted_at');

        if ($request->filled('branchId')) {
            $query->where('branch_id', (int) $request->query('branchId'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }

        if ($request->filled('orderType')) {
            $query->where('type', $request->query('orderType'));
        }

        $orders = $query->latest('created_at')->limit(100)->get()
            ->map(fn ($order) => $this->serializeOrder($tenantId, $order, false));

        return response()->json(['data' => $orders]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'branchId' => ['required', 'integer', 'exists:branches,id'],
            'shiftId' => ['nullable', 'integer', 'exists:shifts,id'],
            'orderType' => ['required', 'in:dine_in,takeaway,delivery'],
            'tableId' => ['nullable', 'integer', 'exists:cafe_tables,id'],
            'customerId' => ['nullable', 'integer', 'exists:customers,id'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.productId' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity' => ['required', 'numeric', 'min:1'],
            'items.*.modifiers' => ['array'],
            'items.*.note' => ['nullable', 'string'],
            'note' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $order = DB::transaction(function () use ($tenantId, $data) {
            $now = now();
            $orderId = DB::table('orders')->insertGetId([
                'tenant_id' => $tenantId,
                'branch_id' => $data['branchId'],
                'shift_id' => $data['shiftId'] ?? null,
                'table_id' => $data['tableId'] ?? null,
                'customer_id' => $data['customerId'] ?? null,
                'order_number' => $this->nextOrderNumber($tenantId, $data['branchId']),
                'type' => $data['orderType'],
                'status' => 'draft',
                'payment_status' => 'unpaid',
                'notes' => $data['note'] ?? null,
                'opened_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            foreach ($data['items'] as $item) {
                $this->persistItem($tenantId, $orderId, $item);
            }

            return $this->pricing->recalculateOrder($tenantId, $orderId);
        });

        return response()->json(['data' => $this->serializeOrder($tenantId, $order)], 201);
    }

    public function show(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $row = $this->findOrder($tenantId, $order);

        return response()->json(['data' => $this->serializeOrder($tenantId, $row)]);
    }

    public function update(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'orderType' => ['sometimes', 'in:dine_in,takeaway,delivery'],
            'tableId' => ['nullable', 'integer', 'exists:cafe_tables,id'],
            'customerId' => ['nullable', 'integer', 'exists:customers,id'],
            'note' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);

        $updates = ['updated_at' => now()];

        if (array_key_exists('orderType', $data)) {
            $updates['type'] = $data['orderType'];
        }

        if (array_key_exists('tableId', $data)) {
            $updates['table_id'] = $data['tableId'];
        }

        if (array_key_exists('customerId', $data)) {
            $updates['customer_id'] = $data['customerId'];
        }

        if (array_key_exists('note', $data)) {
            $updates['notes'] = $data['note'];
        }

        DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->update($updates);

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))]);
    }

    public function cancel(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);

        DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->update([
            'status' => 'cancelled',
            'closed_at' => now(),
            'updated_at' => now(),
            'deleted_at' => now(),
        ]);

        return response()->json(null, 204);
    }

    public function addItem(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'productId' => ['required', 'integer', 'exists:products,id'],
            'quantity' => ['required', 'numeric', 'min:1'],
            'modifiers' => ['array'],
            'note' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);

        DB::transaction(function () use ($tenantId, $order, $data): void {
            $this->persistItem($tenantId, $order, $data);
            $this->pricing->recalculateOrder($tenantId, $order);
        });

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))], 201);
    }

    public function updateItem(Request $request, int $order, int $item): JsonResponse
    {
        $data = $request->validate([
            'quantity' => ['sometimes', 'numeric', 'min:1'],
            'modifiers' => ['sometimes', 'array'],
            'note' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);
        $existing = DB::table('order_items')->where('tenant_id', $tenantId)->where('order_id', $order)->where('id', $item)->whereNull('deleted_at')->first();
        abort_if(! $existing, 404, 'Order item not found.');

        DB::transaction(function () use ($tenantId, $order, $item, $existing, $data): void {
            $quantity = $data['quantity'] ?? (float) $existing->quantity;
            $modifiers = $data['modifiers'] ?? DB::table('order_item_modifiers')
                ->where('tenant_id', $tenantId)
                ->where('order_item_id', $item)
                ->get()
                ->map(fn ($modifier) => ['optionId' => $modifier->modifier_option_id])
                ->all();

            DB::table('order_item_modifiers')->where('tenant_id', $tenantId)->where('order_item_id', $item)->delete();

            $price = $this->pricing->priceItem($tenantId, (int) $existing->product_id, $quantity, $modifiers);

            DB::table('order_items')->where('tenant_id', $tenantId)->where('id', $item)->update([
                'quantity' => $quantity,
                'unit_price' => $price['unit_price'],
                'total' => $price['line_total'],
                'notes' => array_key_exists('note', $data) ? $data['note'] : $existing->notes,
                'updated_at' => now(),
            ]);

            $this->persistModifiers($tenantId, $item, $price['selected_options']);
            $this->pricing->recalculateOrder($tenantId, $order);
        });

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))]);
    }

    public function removeItem(Request $request, int $order, int $item): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);

        DB::transaction(function () use ($tenantId, $order, $item): void {
            DB::table('order_items')->where('tenant_id', $tenantId)->where('order_id', $order)->where('id', $item)->update([
                'deleted_at' => now(),
                'updated_at' => now(),
            ]);
            $this->pricing->recalculateOrder($tenantId, $order);
        });

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))]);
    }

    public function hold(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);

        DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->update([
            'status' => 'held',
            'updated_at' => now(),
        ]);

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))]);
    }

    public function discount(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:percentage,fixed'],
            'value' => ['required', 'numeric', 'min:0'],
            'reason' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $row = $this->findOrder($tenantId, $order);
        $amount = $data['type'] === 'percentage'
            ? round((float) $row->subtotal * ((float) $data['value'] / 100), 2)
            : min((float) $data['value'], (float) $row->subtotal);

        DB::transaction(function () use ($tenantId, $order, $data, $amount): void {
            DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order)->delete();
            DB::table('order_discounts')->insert([
                'tenant_id' => $tenantId,
                'order_id' => $order,
                'discount_name' => $data['reason'] ?? 'POS Discount',
                'discount_type' => $data['type'],
                'discount_value' => $data['value'],
                'discount_amount' => $amount,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $this->pricing->recalculateOrder($tenantId, $order);
        });

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))]);
    }

    public function removeDiscount(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);

        DB::transaction(function () use ($tenantId, $order): void {
            DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order)->delete();
            $this->pricing->recalculateOrder($tenantId, $order);
        });

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))]);
    }

    public function print(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:receipt,kitchen_ticket'],
            'printerId' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $this->findOrder($tenantId, $order);

        return response()->json([
            'data' => [
                'id' => 'print_'.$order.'_'.time(),
                'orderId' => $order,
                'type' => $data['type'],
                'printerId' => $data['printerId'] ?? null,
                'status' => 'queued',
            ],
        ], 202);
    }

    private function persistItem(int $tenantId, int $orderId, array $item): int
    {
        $quantity = (float) $item['quantity'];
        $price = $this->pricing->priceItem($tenantId, (int) $item['productId'], $quantity, $item['modifiers'] ?? []);

        $itemId = DB::table('order_items')->insertGetId([
            'tenant_id' => $tenantId,
            'order_id' => $orderId,
            'product_id' => $price['product']->id,
            'product_name' => $price['product']->name,
            'quantity' => $quantity,
            'unit_price' => $price['unit_price'],
            'total' => $price['line_total'],
            'notes' => $item['note'] ?? null,
            'status' => 'pending',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->persistModifiers($tenantId, $itemId, $price['selected_options']);

        return $itemId;
    }

    private function persistModifiers(int $tenantId, int $itemId, iterable $selectedOptions): void
    {
        foreach ($selectedOptions as $option) {
            DB::table('order_item_modifiers')->insert([
                'tenant_id' => $tenantId,
                'order_item_id' => $itemId,
                'modifier_group_id' => $option->modifier_group_id,
                'modifier_option_id' => $option->id,
                'group_name' => $option->group_name,
                'option_name' => $option->name,
                'price_delta' => $option->price_delta,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    private function findOrder(int $tenantId, int $orderId): object
    {
        $order = DB::table('orders')->where('tenant_id', $tenantId)->where('id', $orderId)->whereNull('deleted_at')->first();
        abort_if(! $order, 404, 'Order not found.');

        return $order;
    }

    private function nextOrderNumber(int $tenantId, int $branchId): string
    {
        $count = DB::table('orders')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->count() + 1;

        return now()->format('Ymd').'-'.str_pad((string) $count, 4, '0', STR_PAD_LEFT);
    }

    private function serializeOrder(int $tenantId, object $order, bool $withItems = true): array
    {
        $customer = $order->customer_id
            ? DB::table('customers')->where('tenant_id', $tenantId)->where('id', $order->customer_id)->first()
            : null;

        $table = $order->table_id
            ? DB::table('cafe_tables')->where('tenant_id', $tenantId)->where('id', $order->table_id)->first()
            : null;

        return [
            'id' => $order->id,
            'orderNumber' => $order->order_number,
            'branchId' => $order->branch_id,
            'shiftId' => $order->shift_id,
            'orderType' => $order->type,
            'status' => $order->status,
            'paymentStatus' => $order->payment_status,
            'table' => $table ? ['id' => $table->id, 'name' => $table->name, 'code' => $table->code] : null,
            'customer' => $customer ? ['id' => $customer->id, 'name' => $customer->name, 'phone' => $customer->phone] : null,
            'items' => $withItems ? $this->items($tenantId, $order->id) : [],
            'discount' => $this->discountRow($tenantId, $order->id),
            'payments' => $withItems ? $this->payments($tenantId, $order->id) : [],
            'refunds' => $withItems ? $this->refunds($tenantId, $order->id) : [],
            'timeline' => $withItems ? $this->timeline($tenantId, $order) : [],
            'totals' => [
                'subtotal' => (float) $order->subtotal,
                'discountTotal' => (float) $order->discount_total,
                'taxRate' => 0.08,
                'taxTotal' => (float) $order->tax_total,
                'serviceTotal' => (float) $order->service_total,
                'total' => (float) $order->total,
            ],
            'note' => $order->notes,
            'createdAt' => $order->created_at,
            'updatedAt' => $order->updated_at,
        ];
    }

    private function payments(int $tenantId, int $orderId): array
    {
        return DB::table('payments')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $orderId)
            ->whereNull('deleted_at')
            ->orderBy('paid_at')
            ->get()
            ->map(fn ($payment) => [
                'id' => $payment->id,
                'method' => $payment->method,
                'amount' => (float) $payment->amount,
                'status' => $payment->status,
                'reference' => $payment->reference_number,
                'paidAt' => $payment->paid_at,
            ])
            ->all();
    }

    private function refunds(int $tenantId, int $orderId): array
    {
        return DB::table('payment_refunds')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $orderId)
            ->orderBy('refunded_at')
            ->get()
            ->map(fn ($refund) => [
                'id' => $refund->id,
                'refundNumber' => $refund->refund_number,
                'type' => $refund->type,
                'amount' => (float) $refund->amount,
                'reason' => $refund->reason,
                'status' => $refund->status,
                'refundedAt' => $refund->refunded_at,
            ])
            ->all();
    }

    private function timeline(int $tenantId, object $order): array
    {
        $events = [
            [
                'type' => 'order_created',
                'label' => 'Order created',
                'occurredAt' => $order->created_at,
            ],
        ];

        if ($order->status === 'held') {
            $events[] = ['type' => 'order_held', 'label' => 'Order held', 'occurredAt' => $order->updated_at];
        }

        if ($order->closed_at) {
            $events[] = ['type' => 'order_closed', 'label' => 'Order closed', 'occurredAt' => $order->closed_at];
        }

        $refunds = DB::table('payment_refunds')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $order->id)
            ->orderBy('refunded_at')
            ->get();

        foreach ($refunds as $refund) {
            $events[] = [
                'type' => 'refund_completed',
                'label' => 'Refund completed',
                'amount' => (float) $refund->amount,
                'occurredAt' => $refund->refunded_at,
            ];
        }

        return $events;
    }

    private function items(int $tenantId, int $orderId): array
    {
        return DB::table('order_items')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $orderId)
            ->whereNull('deleted_at')
            ->orderBy('id')
            ->get()
            ->map(function ($item) use ($tenantId) {
                $modifiers = DB::table('order_item_modifiers')
                    ->where('tenant_id', $tenantId)
                    ->where('order_item_id', $item->id)
                    ->get()
                    ->map(fn ($modifier) => [
                        'groupId' => $modifier->modifier_group_id,
                        'optionId' => $modifier->modifier_option_id,
                        'groupName' => $modifier->group_name,
                        'optionName' => $modifier->option_name,
                        'priceDelta' => (float) $modifier->price_delta,
                    ]);

                return [
                    'id' => $item->id,
                    'productId' => $item->product_id,
                    'name' => $item->product_name,
                    'quantity' => (float) $item->quantity,
                    'unitPrice' => (float) $item->unit_price,
                    'lineTotal' => (float) $item->total,
                    'status' => $item->status,
                    'modifiers' => $modifiers,
                    'note' => $item->notes,
                ];
            })
            ->all();
    }

    private function discountRow(int $tenantId, int $orderId): ?array
    {
        $discount = DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $orderId)->first();

        if (! $discount) {
            return null;
        }

        return [
            'type' => $discount->discount_type,
            'value' => (float) $discount->discount_value,
            'amount' => (float) $discount->discount_amount,
            'reason' => $discount->discount_name,
        ];
    }
}
