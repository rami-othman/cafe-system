<?php

namespace App\Services;

use App\Domain\Inventory\InventoryPostingService;
use App\Models\PublishedMenuVersion;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Consumes inventory for a paid order and snapshots the resulting,
 * Inventory-authoritative COGS onto order_items/orders.
 *
 * Inventory remains the sole source of truth for consumed quantity, WAC, and
 * movement cost (see InventoryPostingService). This service never computes a
 * cost itself — it only decides *whether* a product consumes inventory (via
 * products.inventory_controlled) and, if so, *what* it consumes (via the
 * order's immutable published-menu snapshot) and *where from* (via product_inventory_settings,
 * falling back to the branch's main warehouse). The actual balance/WAC math
 * is delegated entirely to InventoryPostingService::post().
 *
 * Must be called from inside the caller's own DB transaction (payment
 * completion): missing sold-snapshot data or warehouse configuration throws immediately,
 * so the whole payment (and any partial consumption already posted for
 * earlier items in the same order) rolls back — a sale is never left
 * half-consumed.
 */
class SaleConsumptionService
{
    public function __construct(
        private readonly InventoryPostingService $posting,
    ) {}

    /**
     * @return array{cogsTotalCents: int, anyInventoryControlled: bool}
     */
    public function consumeForOrder(Request $request, int $tenantId, object $order, ?int $paymentId, ?int $actorId): array
    {
        $items = DB::table('order_items')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $order->id)
            ->whereNull('deleted_at')
            ->get();

        $orderCogsCents = 0;
        $anyInventoryControlled = false;
        $snapshot = $this->publishedSnapshot($tenantId, $order);

        foreach ($items as $item) {
            $product = $item->product_id
                ? DB::table('products')->where('tenant_id', $tenantId)->where('id', $item->product_id)->first()
                : null;

            if (! $product || ! $product->inventory_controlled) {
                // Non-inventory / service item or a custom line with no product
                // link: VALID_ZERO_COGS — a deliberate zero, not "unavailable".
                $this->snapshotItem($tenantId, $item, 0, null);
                continue;
            }

            $anyInventoryControlled = true;

            $existing = DB::table('sale_consumptions')->where('tenant_id', $tenantId)->where('order_item_id', $item->id)->lockForUpdate()->first();
            if ($existing !== null) {
                // Idempotency: this order item was already consumed (e.g. a
                // payment retry that somehow re-entered this path). Reuse the
                // recorded cost rather than consuming stock a second time.
                $orderCogsCents += Money::cents($existing->cogs_total);
                continue;
            }

            // Use the immutable published menu version, never today's recipes.
            // An inventory-controlled line without its sold configuration is
            // unsafe to cost, so payment must fail instead of silently
            // inventing a zero-cost or live-recipe consumption event.
            if ($snapshot === null || (int) ($snapshot['context']['schemaVersion'] ?? 0) < 3 || empty($item->product_variant_id) || empty($item->menu_item_placement_id)) {
                throw ValidationException::withMessages(['productId' => "Inventory-controlled product #{$product->id} must be paid from a schema-v3 published menu snapshot."]);
            }
            $lines = $this->componentsForItem($tenantId, $snapshot, $item);
            if ($lines === []) {
                throw ValidationException::withMessages(['productId' => "The sold variant for product #{$product->id} has no recipe components in its published menu snapshot."]);
            }

            $warehouseId = $this->resolveWarehouse($tenantId, $product->id, (int) $order->branch_id);
            if ($warehouseId === null) {
                throw ValidationException::withMessages(['productId' => "Product \"{$product->name}\" (#{$product->id}) has no active warehouse configured for branch #{$order->branch_id}. Configure Product Inventory Settings or a main branch warehouse."]);
            }

            $soldQuantity = (float) $item->quantity;
            $itemCogsCents = 0;

            foreach ($lines as $line) {
                $consumeQuantity = round((float) $line['quantity'] * $soldQuantity, 3);
                if ($consumeQuantity <= 0) {
                    continue;
                }

                $result = $this->posting->post($request, $tenantId, [
                    'warehouseId' => $warehouseId,
                    'itemId' => $line['materialId'],
                    'type' => 'sale_consumption',
                    'quantity' => number_format($consumeQuantity, 3, '.', ''),
                    'unit' => $line['unitCode'],
                    'branchId' => $order->branch_id,
                    'referenceType' => 'order_item',
                    'referenceId' => $item->id,
                    'idempotencyKey' => "sale-consumption-{$tenantId}-{$item->id}-{$line['materialId']}",
                ], $actorId);

                $movementCost = DB::table('stock_movements')->where('id', $result->movementId)->value('total_cost');
                $itemCogsCents += Money::cents($movementCost ?? '0');
            }

            $now = now();
            DB::table('sale_consumptions')->insert([
                'tenant_id' => $tenantId,
                'order_id' => $order->id,
                'order_item_id' => $item->id,
                'recipe_id' => null,
                'branch_id' => $order->branch_id,
                'warehouse_id' => $warehouseId,
                'payment_id' => $paymentId,
                'quantity_sold' => $item->quantity,
                'cogs_total' => Money::decimal($itemCogsCents),
                'consumed_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->snapshotItem($tenantId, $item, $itemCogsCents, null);
            $orderCogsCents += $itemCogsCents;
        }

        $totalCents = Money::cents($order->total);
        $grossProfitCents = $totalCents - $orderCogsCents;
        DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order->id)->update([
            'cogs_total' => Money::decimal($orderCogsCents),
            'gross_profit' => Money::decimal($grossProfitCents),
            'gross_margin_percentage' => $totalCents > 0 ? round(($grossProfitCents / $totalCents) * 100, 4) : 0,
            'updated_at' => now(),
        ]);

        return ['cogsTotalCents' => $orderCogsCents, 'anyInventoryControlled' => $anyInventoryControlled];
    }

    /** @return array<string, mixed>|null */
    private function publishedSnapshot(int $tenantId, object $order): ?array
    {
        if (empty($order->published_menu_version_id)) {
            return null;
        }

        $version = PublishedMenuVersion::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($order->published_menu_version_id)
            ->first();

        return $version?->payload_json;
    }

    /**
     * @return list<array{materialId: int, quantity: float, unitCode: string}>
     */
    private function componentsForItem(int $tenantId, array $snapshot, object $item): array
    {
        $variant = null;
        foreach ($snapshot['menus'] ?? [] as $menu) {
            foreach ($menu['sections'] ?? [] as $section) {
                foreach ($section['products'] ?? [] as $product) {
                    if ((int) ($product['productId'] ?? 0) !== (int) $item->product_id || (int) ($product['placementId'] ?? 0) !== (int) $item->menu_item_placement_id) {
                        continue;
                    }
                    foreach ($product['variants'] ?? [] as $candidate) {
                        if ((int) ($candidate['id'] ?? 0) === (int) $item->product_variant_id) {
                            $variant = $candidate;
                            break 4;
                        }
                    }
                }
            }
        }
        if (! is_array($variant)) {
            throw ValidationException::withMessages(['variantId' => 'The sold variant is missing from its published menu snapshot.']);
        }

        $selected = DB::table('order_item_modifiers')
            ->where('tenant_id', $tenantId)->where('order_item_id', $item->id)
            ->get(['modifier_option_id', 'quantity'])
            ->mapWithKeys(fn (object $row) => [(int) $row->modifier_option_id => max(1, (int) $row->quantity)])
            ->all();
        $components = [];
        $add = function (array $component, int $direction = 1, int $multiplier = 1) use (&$components): void {
            $materialId = (int) ($component['materialId'] ?? 0);
            $unit = (string) ($component['unitCode'] ?? '');
            $quantity = (float) ($component['quantity'] ?? 0) * $direction * $multiplier;
            if ($materialId <= 0 || $unit === '' || $quantity == 0.0) {
                return;
            }
            $key = $materialId.':'.$unit;
            $components[$key] ??= ['materialId' => $materialId, 'quantity' => 0.0, 'unitCode' => $unit];
            $components[$key]['quantity'] += $quantity;
        };
        foreach ($variant['baseRecipe'] ?? [] as $component) {
            $add($component);
        }
        foreach ($variant['modifierRecipeAdjustments'] ?? [] as $adjustment) {
            $selectedQuantity = $selected[(int) ($adjustment['optionId'] ?? 0)] ?? 0;
            if ($selectedQuantity === 0) {
                continue;
            }
            foreach ($adjustment['components'] ?? [] as $component) {
                $add($component, ($component['operation'] ?? 'add') === 'remove' ? -1 : 1, $selectedQuantity);
            }
        }

        return array_values(array_filter($components, fn (array $component) => $component['quantity'] > 0));
    }

    private function snapshotItem(int $tenantId, object $item, int $cogsTotalCents, ?int $recipeId): void
    {
        $quantity = (float) $item->quantity;
        $cogsUnitCents = $quantity > 0 ? (int) round($cogsTotalCents / $quantity) : 0;
        $lineTotalCents = Money::cents($item->total);

        DB::table('order_items')->where('tenant_id', $tenantId)->where('id', $item->id)->update([
            'recipe_id' => $recipeId,
            'cogs_unit' => Money::decimal($cogsUnitCents),
            'cogs_total' => Money::decimal($cogsTotalCents),
            'gross_profit' => Money::decimal($lineTotalCents - $cogsTotalCents),
            'updated_at' => now(),
        ]);
    }

    /**
     * Resolves which warehouse a product's inventory is consumed from for a
     * given branch: an explicit product_inventory_settings mapping first,
     * falling back to the branch's main warehouse (the same
     * "BR-{branchId}-MAIN" convention FinancialSetupService already creates
     * for every branch) — not a second, invented resolution scheme.
     */
    private function resolveWarehouse(int $tenantId, int $productId, int $branchId): ?int
    {
        $configuredId = DB::table('product_inventory_settings')
            ->where('tenant_id', $tenantId)->where('product_id', $productId)->where('branch_id', $branchId)
            ->value('warehouse_id');

        if ($configuredId !== null) {
            $active = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $configuredId)->where('is_active', true)->whereNull('deleted_at')->exists();

            return $active ? (int) $configuredId : null;
        }

        $fallbackId = DB::table('warehouses')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('code', "BR-{$branchId}-MAIN")
            ->where('is_active', true)->whereNull('deleted_at')->value('id');

        return $fallbackId !== null ? (int) $fallbackId : null;
    }
}
