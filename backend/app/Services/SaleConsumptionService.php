<?php

namespace App\Services;

use App\Domain\Inventory\InventoryPostingService;
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
 * product's active recipe) and *where from* (via product_inventory_settings,
 * falling back to the branch's main warehouse). The actual balance/WAC math
 * is delegated entirely to InventoryPostingService::post().
 *
 * Must be called from inside the caller's own DB transaction (payment
 * completion): a missing recipe/warehouse configuration throws immediately,
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

            $recipe = DB::table('recipes')
                ->where('tenant_id', $tenantId)->where('product_id', $product->id)->where('is_active', true)
                ->orderByDesc('version')->first();
            if (! $recipe) {
                throw ValidationException::withMessages(['productId' => "Product \"{$product->name}\" (#{$product->id}) is inventory-controlled but has no active recipe configured. Configure a recipe for this product before it can be sold."]);
            }

            $lines = DB::table('recipe_lines')->where('tenant_id', $tenantId)->where('recipe_id', $recipe->id)->orderBy('line_number')->get();
            if ($lines->isEmpty()) {
                throw ValidationException::withMessages(['productId' => "Product \"{$product->name}\" (#{$product->id}) has an active recipe (#{$recipe->id}) with no ingredient lines configured."]);
            }

            $warehouseId = $this->resolveWarehouse($tenantId, $product->id, (int) $order->branch_id);
            if ($warehouseId === null) {
                throw ValidationException::withMessages(['productId' => "Product \"{$product->name}\" (#{$product->id}) has no active warehouse configured for branch #{$order->branch_id}. Configure Product Inventory Settings or a main branch warehouse."]);
            }

            $yieldQuantity = (float) $recipe->yield_quantity > 0 ? (float) $recipe->yield_quantity : 1.0;
            $soldQuantity = (float) $item->quantity;
            $itemCogsCents = 0;

            foreach ($lines as $line) {
                $wastageFactor = 1 + ((float) $line->wastage_percentage / 100);
                $consumeQuantity = ((float) $line->quantity / $yieldQuantity) * $soldQuantity * $wastageFactor;
                if ($consumeQuantity <= 0) {
                    continue;
                }

                $result = $this->posting->post($request, $tenantId, [
                    'warehouseId' => $warehouseId,
                    'itemId' => $line->inventory_item_id,
                    'type' => 'sale_consumption',
                    'quantity' => number_format($consumeQuantity, 3, '.', ''),
                    'unit' => $line->unit,
                    'branchId' => $order->branch_id,
                    'referenceType' => 'order_item',
                    'referenceId' => $item->id,
                    'idempotencyKey' => "sale-consumption-{$tenantId}-{$item->id}-{$line->inventory_item_id}",
                ], $actorId);

                $movementCost = DB::table('stock_movements')->where('id', $result->movementId)->value('total_cost');
                $itemCogsCents += Money::cents($movementCost ?? '0');
            }

            $now = now();
            DB::table('sale_consumptions')->insert([
                'tenant_id' => $tenantId,
                'order_id' => $order->id,
                'order_item_id' => $item->id,
                'recipe_id' => $recipe->id,
                'branch_id' => $order->branch_id,
                'warehouse_id' => $warehouseId,
                'payment_id' => $paymentId,
                'quantity_sold' => $item->quantity,
                'cogs_total' => Money::decimal($itemCogsCents),
                'consumed_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->snapshotItem($tenantId, $item, $itemCogsCents, $recipe->id);
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
