<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\OrderLifecycleException;
use App\Exceptions\UnsupportedMenuSnapshotSchemaException;
use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\Menu\PublishedMenuOrderResolver;
use App\Services\OrderLifecyclePolicy;
use App\Services\PosNumberGenerator;
use App\Services\PosPricingService;
use App\Services\TenantTaxService;
use App\Support\IdempotencyFingerprint;
use App\Support\TenantContext;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class PosOrderController extends Controller
{
    public function __construct(
        private readonly PosPricingService $pricing,
        private readonly TenantTaxService $taxes,
        private readonly PublishedMenuOrderResolver $publishedOrders,
        private readonly OrderLifecyclePolicy $lifecycle,
        private readonly PosNumberGenerator $numbers,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        $request->validate([
            'branchId' => ['nullable', 'integer', $this->tenantExists('branches', $tenantId)],
        ]);

        $query = DB::table('orders')
            ->where('tenant_id', $tenantId)
            ->whereIn('branch_id', app(BranchAccessService::class)->accessibleBranchIds($request->attributes->get('auth_user')))
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
        $tenantId = TenantContext::id($request);
        // The no-version branch is retained solely for backward-compatible
        // integrations and historical workflows. Production POS must send a
        // publishedMenuVersionId and is resolved only from that snapshot.
        $snapshotRequested = $request->filled('publishedMenuVersionId');
        $data = $request->validate([
            'branchId' => ['required', 'integer', $this->tenantExists('branches', $tenantId)],
            'shiftId' => ['nullable', 'integer', $this->tenantExists('shifts', $tenantId)],
            'orderType' => ['required', 'in:dine_in,takeaway,delivery'],
            'tableId' => ['nullable', 'integer', $this->tenantExists('cafe_tables', $tenantId)],
            'customerId' => ['nullable', 'integer', $this->tenantExists('customers', $tenantId)],
            'publishedMenuVersionId' => ['nullable', 'integer'],
            'items' => ['required', 'array', 'min:1'],
            // Product identity belongs to the snapshot on the versioned path;
            // the temporary no-version path remains the legacy Catalog flow.
            'items.*.productId' => $snapshotRequested
                ? ['required', 'integer']
                : ['required', 'integer', $this->tenantExists('products', $tenantId)],
            'items.*.variantId' => ['nullable', 'integer'],
            'items.*.placementId' => ['nullable', 'integer'],
            'items.*.quantity' => ['required', 'numeric', 'min:1'],
            'items.*.modifiers' => ['array'],
            'items.*.modifierOptionIds' => ['array'],
            'items.*.modifierOptionIds.*' => ['integer'],
            'items.*.note' => ['nullable', 'string'],
            'note' => ['nullable', 'string'],
            'idempotencyKey' => ['nullable', 'string', 'max:120'],
        ]);

        $this->assertBranchRelationships($tenantId, $data, (int) $data['branchId']);
        try {
            $actorId = (int) $request->attributes->get('auth_user')->id;
            $result = DB::transaction(function () use ($tenantId, $data, $actorId) {
                $key = $data['idempotencyKey'] ?? null;
                $fingerprint = $key ? IdempotencyFingerprint::from($data) : null;
                if ($key && ($existing = DB::table('orders')->where('tenant_id', $tenantId)->where('idempotency_key', $key)->lockForUpdate()->first())) {
                    if (! $existing->idempotency_fingerprint || ! hash_equals($existing->idempotency_fingerprint, $fingerprint)) {
                        throw new OrderLifecycleException('ORDER_IDEMPOTENCY_CONFLICT', 'This order key was already used for a different request.');
                    }

                    return ['order' => $existing, 'replayed' => true];
                }

                $snapshot = array_key_exists('publishedMenuVersionId', $data) && $data['publishedMenuVersionId'] !== null
                    ? $this->publishedOrders->bindNewOrder($tenantId, (int) $data['branchId'], (int) $data['publishedMenuVersionId'])
                    : null;
                $now = now();
                $orderId = DB::table('orders')->insertGetId([
                    'tenant_id' => $tenantId,
                    'branch_id' => $data['branchId'],
                    'published_menu_version_id' => $snapshot['version']->id ?? null,
                    'shift_id' => $data['shiftId'] ?? null,
                    'table_id' => $data['tableId'] ?? null,
                    'customer_id' => $data['customerId'] ?? null,
                    // Authenticated creator of this transaction context.
                    'cashier_id' => $actorId,
                    'order_number' => $this->numbers->nextOrderNumber($tenantId, $data['branchId']),
                    'type' => $data['orderType'],
                    'status' => 'draft',
                    'payment_status' => 'unpaid',
                    'tax_rate' => $this->taxes->rateFor($tenantId),
                    'notes' => $data['note'] ?? null,
                    'idempotency_key' => $key,
                    'idempotency_fingerprint' => $fingerprint,
                    'opened_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                foreach ($data['items'] as $item) {
                    $this->persistItem($tenantId, $orderId, $item, $snapshot);
                }

                return ['order' => $this->pricing->recalculateOrder($tenantId, $orderId), 'replayed' => false];
            });
        } catch (UnsupportedMenuSnapshotSchemaException $exception) {
            return $this->unsupportedSnapshotResponse($exception);
        }

        return response()->json(['data' => $this->serializeOrder($tenantId, $result['order'])], $result['replayed'] ? 200 : 201);
    }

    public function show(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $row = $this->findOrder($tenantId, $order);

        return response()->json(['data' => $this->serializeOrder($tenantId, $row)]);
    }

    public function update(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $existingOrder = $this->findOrder($tenantId, $order);
        $data = $request->validate([
            'orderType' => ['sometimes', 'in:dine_in,takeaway,delivery'],
            'tableId' => ['nullable', 'integer', $this->tenantExists('cafe_tables', $tenantId)],
            'customerId' => ['nullable', 'integer', $this->tenantExists('customers', $tenantId)],
            'note' => ['nullable', 'string'],
        ]);

        $this->assertBranchRelationships($tenantId, $data, (int) $existingOrder->branch_id);

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

        DB::transaction(function () use ($tenantId, $order, $updates): void {
            $this->lifecycle->assertMutable($this->lockedOrder($tenantId, $order));
            DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->update($updates);
            $this->pricing->recalculateOrder($tenantId, $order);
        });

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))]);
    }

    public function cancel(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        DB::transaction(function () use ($tenantId, $order): void {
            $this->lifecycle->assertCancellable($this->lockedOrder($tenantId, $order));
            DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->update([
                'status' => 'cancelled', 'closed_at' => now(), 'updated_at' => now(), 'deleted_at' => now(),
            ]);
        });

        return response()->json(null, 204);
    }

    public function addItem(Request $request, int $order): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $orderRow = $this->findOrder($tenantId, $order);
        $data = $request->validate([
            'productId' => $orderRow->published_menu_version_id === null
                ? ['required', 'integer', $this->tenantExists('products', $tenantId)]
                : ['required', 'integer'],
            'variantId' => ['nullable', 'integer'],
            'placementId' => ['nullable', 'integer'],
            'quantity' => ['required', 'numeric', 'min:1'],
            'modifiers' => ['array'],
            'modifierOptionIds' => ['array'],
            'modifierOptionIds.*' => ['integer'],
            'note' => ['nullable', 'string'],
        ]);

        try {
            DB::transaction(function () use ($tenantId, $order, $data): void {
                $lockedOrder = $this->lockedOrder($tenantId, $order);
                $this->lifecycle->assertMutable($lockedOrder);
                $snapshot = $lockedOrder->published_menu_version_id === null ? null : $this->publishedOrders->bindPinnedOrder($tenantId, (int) $lockedOrder->branch_id, (int) $lockedOrder->published_menu_version_id);
                $this->persistItem($tenantId, $order, $data, $snapshot);
                $this->pricing->recalculateOrder($tenantId, $order);
            });
        } catch (UnsupportedMenuSnapshotSchemaException $exception) {
            return $this->unsupportedSnapshotResponse($exception);
        }

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))], 201);
    }

    public function updateItem(Request $request, int $order, int $item): JsonResponse
    {
        $data = $request->validate([
            'quantity' => ['sometimes', 'numeric', 'min:1'],
            'modifiers' => ['sometimes', 'array'],
            'modifierOptionIds' => ['sometimes', 'array'],
            'modifierOptionIds.*' => ['integer'],
            'note' => ['nullable', 'string'],
        ]);

        $tenantId = TenantContext::id($request);
        $orderRow = $this->findOrder($tenantId, $order);
        $existing = DB::table('order_items')->where('tenant_id', $tenantId)->where('order_id', $order)->where('id', $item)->whereNull('deleted_at')->first();
        abort_if(! $existing, 404, 'Order item not found.');

        try {
            DB::transaction(function () use ($tenantId, $order, $item, $existing, $data): void {
                $orderRow = $this->lockedOrder($tenantId, $order);
                $this->lifecycle->assertMutable($orderRow);
                $quantity = $data['quantity'] ?? (float) $existing->quantity;
                if ($orderRow->published_menu_version_id !== null) {
                    $optionIds = $data['modifierOptionIds'] ?? DB::table('order_item_modifiers')
                        ->where('tenant_id', $tenantId)->where('order_item_id', $item)->pluck('modifier_option_id')->map(fn ($id) => (int) $id)->all();
                    $snapshot = $this->publishedOrders->bindPinnedOrder($tenantId, (int) $orderRow->branch_id, (int) $orderRow->published_menu_version_id);
                    $price = $this->publishedOrders->priceItem($snapshot, [
                        'productId' => (int) $existing->product_id,
                        'placementId' => (int) $existing->menu_item_placement_id,
                        'variantId' => (int) $existing->product_variant_id,
                        'quantity' => $quantity,
                        'modifierOptionIds' => $optionIds,
                    ]);
                    DB::table('order_item_modifiers')->where('tenant_id', $tenantId)->where('order_item_id', $item)->delete();
                    DB::table('order_items')->where('tenant_id', $tenantId)->where('id', $item)->update([
                        'quantity' => $quantity, 'unit_price' => $price['unitPrice'], 'total' => $price['lineTotal'], 'category_id' => $price['categoryId'],
                        'notes' => array_key_exists('note', $data) ? $data['note'] : $existing->notes, 'updated_at' => now(),
                    ]);
                    $this->persistModifiers($tenantId, $item, $price['selectedOptions']);
                    $this->pricing->recalculateOrder($tenantId, $order);

                    return;
                }
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
        } catch (UnsupportedMenuSnapshotSchemaException $exception) {
            return $this->unsupportedSnapshotResponse($exception);
        }

        return response()->json(['data' => $this->serializeOrder($tenantId, $this->findOrder($tenantId, $order))]);
    }

    public function removeItem(Request $request, int $order, int $item): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        DB::transaction(function () use ($tenantId, $order, $item): void {
            $this->lifecycle->assertMutable($this->lockedOrder($tenantId, $order));
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
        DB::transaction(function () use ($tenantId, $order): void {
            $this->lifecycle->assertHoldable($this->lockedOrder($tenantId, $order));
            DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order)->update(['status' => 'held', 'updated_at' => now()]);
        });

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
        DB::transaction(function () use ($tenantId, $order, $data): void {
            $row = $this->lockedOrder($tenantId, $order);
            $this->lifecycle->assertDiscountable($row);
            $amount = $data['type'] === 'percentage' ? round((float) $row->subtotal * ((float) $data['value'] / 100), 2) : min((float) $data['value'], (float) $row->subtotal);
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
        DB::transaction(function () use ($tenantId, $order): void {
            $this->lifecycle->assertDiscountable($this->lockedOrder($tenantId, $order));
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

    private function persistItem(int $tenantId, int $orderId, array $item, ?array $snapshot = null): int
    {
        if ($snapshot !== null) {
            $price = $this->publishedOrders->priceItem($snapshot, $item);
            $itemId = DB::table('order_items')->insertGetId([
                'tenant_id' => $tenantId,
                'order_id' => $orderId,
                'product_id' => $price['productId'],
                'category_id' => $price['categoryId'],
                'product_variant_id' => $price['variantId'],
                'menu_item_placement_id' => $price['placementId'],
                'product_name' => $price['productName'],
                'variant_name' => $price['variantName'],
                'quantity' => $price['quantity'],
                'unit_price' => $price['unitPrice'],
                'total' => $price['lineTotal'],
                'notes' => $item['note'] ?? null,
                'status' => 'pending',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $this->persistModifiers($tenantId, $itemId, $price['selectedOptions']);

            return $itemId;
        }

        $quantity = (float) $item['quantity'];
        $price = $this->pricing->priceItem($tenantId, (int) $item['productId'], $quantity, $item['modifiers'] ?? []);

        $itemId = DB::table('order_items')->insertGetId([
            'tenant_id' => $tenantId,
            'order_id' => $orderId,
            'product_id' => $price['product']->id,
            'category_id' => $price['product']->category_id,
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
            $snapshotOption = is_array($option);
            DB::table('order_item_modifiers')->insert([
                'tenant_id' => $tenantId,
                'order_item_id' => $itemId,
                'modifier_group_id' => $snapshotOption ? $option['modifierGroupId'] : $option->modifier_group_id,
                'modifier_option_id' => $snapshotOption ? $option['id'] : $option->id,
                'group_name' => $snapshotOption ? $option['groupName'] : $option->group_name,
                'option_name' => $snapshotOption ? $option['optionName'] : $option->name,
                'price_delta' => $snapshotOption ? $option['priceDelta'] : $option->price_delta,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
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

    private function tenantExists(string $table, int $tenantId)
    {
        return Rule::exists($table, 'id')->where(
            fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at'),
        );
    }

    private function assertBranchRelationships(int $tenantId, array $data, int $branchId): void
    {
        foreach (['shiftId' => 'shifts', 'tableId' => 'cafe_tables'] as $field => $table) {
            if (! empty($data[$field]) && ! DB::table($table)
                ->where('tenant_id', $tenantId)
                ->where('branch_id', $branchId)
                ->where('id', $data[$field])
                ->whereNull('deleted_at')
                ->exists()) {
                throw ValidationException::withMessages([$field => "The selected {$field} is invalid."]);
            }
        }
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
            'publishedMenuVersionId' => $order->published_menu_version_id,
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
                'taxRate' => (float) $order->tax_rate,
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
                    'variantId' => $item->product_variant_id,
                    'placementId' => $item->menu_item_placement_id,
                    'variantName' => $item->variant_name,
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

    private function unsupportedSnapshotResponse(UnsupportedMenuSnapshotSchemaException $exception): JsonResponse
    {
        return response()->json(['message' => $exception->getMessage(), 'code' => 'UNSUPPORTED_MENU_SNAPSHOT_SCHEMA'], 409);
    }
}
