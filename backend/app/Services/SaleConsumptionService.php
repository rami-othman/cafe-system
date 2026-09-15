<?php

namespace App\Services;

use App\Domain\Inventory\RecipeMaterialEligibility;
use App\Domain\Inventory\UnitConversionResolver;
use App\Models\PublishedMenuVersion;
use App\Support\InventoryDecimal;
use App\Support\Money;
use App\Support\PaymentPerformanceProbe;
use App\Exceptions\OrderLifecycleException;
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
 * products.is_stock_tracked, the single canonical "Track Inventory" flag —
 * see CatalogProductService, which keeps the legacy products.inventory_controlled
 * column mirrored to it on every write; that legacy column is still consulted
 * here as a read-only safety net so a row that predates the backfill migration
 * is never silently disabled) and, if so, *what* it consumes (via the
 * products.is_stock_tracked) and, if so, *what* it consumes (via the
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
        private readonly SalesInventoryMovementService $movements,
        private readonly UnitConversionResolver $conversions,
        private readonly PaymentPerformanceProbe $performance,
    ) {}

    /**
     * @return array{cogsTotalCents: int, anyInventoryControlled: bool}
     */
    public function consumeForOrder(Request $request, int $tenantId, object $order, ?int $paymentId, ?int $actorId): array
    {
        $items = $this->performance->measure('recipe loading', fn () => DB::table('order_items')
            ->where('tenant_id', $tenantId)
            ->where('order_id', $order->id)
            ->whereNull('deleted_at')
            ->get());

        $orderCogsCents = 0;
        $anyInventoryControlled = false;
        $snapshot = $this->performance->measure('recipe loading', fn () => $this->publishedSnapshot($tenantId, $order));

        foreach ($items as $item) {
            $product = $item->product_id
                ? DB::table('products')->where('tenant_id', $tenantId)->where('id', $item->product_id)->first()
                : null;

            if (! $product || ! $this->isTracked($product)) {
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
            $recipeStarted = $this->performance->start('recipe loading');
            $lines = $this->componentsForItem($tenantId, $snapshot, $item);
            if ($lines === []) {
                throw ValidationException::withMessages(['productId' => "The sold variant for product #{$product->id} has no recipe components in its published menu snapshot."]);
            }

            $warehouseId = $this->resolveWarehouse($tenantId, (int) $order->branch_id);
            if ($warehouseId === null) {
                throw new OrderLifecycleException('WAREHOUSE_NOT_CONFIGURED', "No active branch-main warehouse is configured for order branch #{$order->branch_id}.");
            }

            $soldQuantity = InventoryDecimal::units($item->quantity);
            $itemCogsCents = 0;
            $consumptions = [];

            foreach ($lines as $line) {
                $canonical = $this->canonicalLine($tenantId, $line);
                $quantity = InventoryDecimal::applyFactor($canonical['quantity'], $soldQuantity * 1000);
                $key = (int) $line['materialId'];
                $consumptions[$key] ??= ['materialId' => $key, 'baseUnit' => $canonical['baseUnit'], 'quantity' => 0];
                $consumptions[$key]['quantity'] += $line['direction'] * $quantity;
            }

            $this->performance->stop('recipe loading', $recipeStarted);

            $movementResult = $this->performance->measure('inventory consumption', fn () => $this->movements->consume($request, $tenantId, (int) $order->branch_id, $warehouseId, 'order_item', (int) $item->id, array_values($consumptions), $actorId));
            $itemCogsCents += $movementResult['cogsCents'];

            $cogsStarted = $this->performance->start('COGS');
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
            $this->performance->stop('COGS', $cogsStarted);
        }

        $totalCents = Money::cents($order->total);
        $grossProfitCents = $totalCents - $orderCogsCents;
        $cogsStarted = $this->performance->start('COGS');
        DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order->id)->update([
            'cogs_total' => Money::decimal($orderCogsCents),
            'gross_profit' => Money::decimal($grossProfitCents),
            'gross_margin_percentage' => $totalCents > 0 ? round(($grossProfitCents / $totalCents) * 100, 4) : 0,
            'updated_at' => now(),
        ]);
        $this->performance->stop('COGS', $cogsStarted);

        return ['cogsTotalCents' => $orderCogsCents, 'anyInventoryControlled' => $anyInventoryControlled];
    }

    /**
     * Read-only payment preflight for the warehouse configuration required by
     * this order's authoritative sale-consumption path.
     *
     * @return array{code: string, reason: string}|null
     */
    public function preflightWarehouseConfiguration(int $tenantId, object $order): ?array
    {
        $requiresInventory = DB::table('order_items')
            ->join('products', 'products.id', '=', 'order_items.product_id')
            ->where('order_items.tenant_id', $tenantId)
            ->where('products.tenant_id', $tenantId)
            ->where('order_items.order_id', $order->id)
            ->whereNull('order_items.deleted_at')
            ->where('products.is_stock_tracked', true)
            ->exists();

        if (! $requiresInventory) {
            return null;
        }

        try {
            if ($this->resolveWarehouse($tenantId, (int) $order->branch_id) !== null) {
                return null;
            }
        } catch (OrderLifecycleException $exception) {
            if ($exception->domainCode === 'WAREHOUSE_CONFIGURATION_AMBIGUOUS') {
                return [
                    'code' => $exception->domainCode,
                    'reason' => 'Multiple active branch-main warehouses are configured. Keep exactly one active main warehouse for this branch before paying.',
                ];
            }

            throw $exception;
        }

        return [
            'code' => 'WAREHOUSE_NOT_CONFIGURED',
            'reason' => 'No active branch-main warehouse is configured. Configure one before paying.',
        ];
    }

    /**
     * Canonical tracking check: `is_stock_tracked` is authoritative;
     * `inventory_controlled` is a legacy mirror and must never override an
     * explicit false value in the authoritative column.
     */
    private function isTracked(object $product): bool
    {
        return (bool) $product->is_stock_tracked;
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
     * @return list<array{materialId: int, quantity: string, unitCode: string, canonicalQuantity?: string, baseUnit?: string, direction: int}>
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
            $quantity = (string) ($component['quantity'] ?? '');
            if ($materialId <= 0 || $unit === '' || $quantity === '') {
                return;
            }
            for ($i = 0; $i < $multiplier; $i++) {
                $components[] = ['materialId' => $materialId, 'quantity' => $quantity, 'unitCode' => $unit, 'canonicalQuantity' => $component['canonicalQuantity'] ?? null, 'baseUnit' => $component['baseUnit'] ?? null, 'direction' => $direction];
            }
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

        return $components;
    }

    /** @return array{quantity: int, baseUnit: string} */
    private function canonicalLine(int $tenantId, array $line): array
    {
        $material = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $line['materialId'])->whereNull('deleted_at')->first();
        if (! $material) {
            throw ValidationException::withMessages(['productId' => 'A published recipe material is unavailable.']);
        }
        if (! RecipeMaterialEligibility::allows($material)) {
            throw ValidationException::withMessages(['productId' => 'A published recipe material is ineligible for recipe consumption.']);
        }
        if (is_string($line['canonicalQuantity'] ?? null) && is_string($line['baseUnit'] ?? null)) {
            return ['quantity' => InventoryDecimal::units($line['canonicalQuantity']), 'baseUnit' => $line['baseUnit']];
        }

        $canonical = $this->conversions->resolveRecipe($tenantId, $material, $line['quantity'], $line['unitCode']);

        return ['quantity' => $canonical['baseQuantity'], 'baseUnit' => $canonical['baseUnit']];
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
     * given branch: the provisioned branch main warehouse. Product inventory
     * settings are not yet a validated operational routing surface, so v1
     * treats them as non-authoritative rather than inventing a second route.
     */
    private function resolveWarehouse(int $tenantId, int $branchId): ?int
    {
        $warehouses = DB::table('warehouses')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('type', 'branch_main')
            ->where('is_active', true)->whereNull('deleted_at')->orderBy('id')->get(['id', 'code']);
        if ($warehouses->count() > 1) {
            throw new OrderLifecycleException('WAREHOUSE_CONFIGURATION_AMBIGUOUS', "Multiple active branch-main warehouses are configured for order branch #{$branchId}.");
        }
        if ($warehouses->count() === 1) {
            return (int) $warehouses->first()->id;
        }

        // Backward compatibility for pre-type data. The repair command reports
        // this state so it can be normalized without blocking an existing site.
        $legacyId = DB::table('warehouses')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('code', "BR-{$branchId}-MAIN")
            ->where('is_active', true)->whereNull('deleted_at')->value('id');

        return $legacyId !== null ? (int) $legacyId : null;
    }
}
