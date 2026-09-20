<?php

namespace App\Services;

use App\Domain\Inventory\InventoryWarehouseAssignment;
use App\Domain\Inventory\RecipeMaterialEligibility;
use App\Domain\Inventory\UnitConversionResolver;
use App\Exceptions\OrderLifecycleException;
use App\Models\ProductVariant;
use App\Services\Catalog\RecipeConfigurationService;
use App\Support\InventoryDecimal;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** A read-only plan is shared by preview and the final movement writer. */
final class SalesInvoiceInventoryConsumptionService
{
    public function __construct(private readonly SalesInventoryMovementService $movements, private readonly UnitConversionResolver $conversions, private readonly InventoryWarehouseAssignment $assignments, private readonly PosInventoryWarehouseResolver $warehouseResolver, private readonly RecipeConfigurationService $recipes) {}

    /** @param iterable<object> $lines @return array<int, array<string,mixed>> */
    public function preview(int $tenantId, object $invoice, iterable $lines): array
    {
        $results = [];
        foreach ($lines as $line) {
            $product = DB::table('products')->where('tenant_id', $tenantId)->where('id', $line->product_id)->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $product) {
                throw ValidationException::withMessages(['productId' => "Sales invoice line {$line->line_number} has an inactive or unavailable product."]);
            }
            if (! $this->tracked($product)) {
                $results[(int) $line->id] = ['cogsCents' => 0, 'warehouseId' => null, 'warehouseName' => null, 'movements' => []];

                continue;
            }
            if (! $line->product_variant_id) {
                throw ValidationException::withMessages(['variantId' => "Inventory-tracked line {$line->line_number} has no selected product variant. Edit the draft and select a variant before posting."]);
            }
            $components = $this->components($tenantId, (int) $product->id, (int) $line->product_variant_id);
            if ($components->isEmpty()) {
                // An explicitly absent effective recipe is a valid, zero-Cogs
                // sale. It must not require a warehouse merely because the
                // product is inventory tracked.
                $results[(int) $line->id] = ['cogsCents' => 0, 'warehouseId' => null, 'warehouseName' => null, 'movements' => []];

                continue;
            }
            $warehouse = $this->warehouse($tenantId, (int) $invoice->branch_id);
            if (! $warehouse) {
                throw ValidationException::withMessages(['inventory' => "Product {$product->name} has no active selling warehouse for this branch."]);
            }
            $sold = InventoryDecimal::units($line->quantity);
            $consumptions = [];
            foreach ($components as $component) {
                $material = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $component['materialId'])->whereNull('deleted_at')->first();
                if (! $material || ! RecipeMaterialEligibility::allows($material)) {
                    throw ValidationException::withMessages(['inventory' => 'A selected recipe material is unavailable or ineligible.']);
                }
                $this->assignments->assertAssigned($tenantId, (int) $material->id, (int) $warehouse->id, 'inventory');
                $canonical = $this->conversions->resolveRecipe($tenantId, $material, $component['quantity'], $component['unitCode']);
                $quantity = InventoryDecimal::applyFactor($canonical['baseQuantity'], $sold * 1000);
                $id = (int) $material->id;
                $consumptions[$id] ??= ['materialId' => $id, 'materialName' => $material->name_ar ?: $material->name, 'recipeQuantity' => $component['quantity'], 'recipeUnit' => $component['unitCode'], 'baseUnit' => $canonical['baseUnit'], 'quantity' => 0];
                $consumptions[$id]['quantity'] += $quantity;
            }
            $cogs = 0;
            $movements = [];
            foreach ($consumptions as $consumption) {
                $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'inventory_item_id' => $consumption['materialId']])->first();
                $onHand = InventoryDecimal::signedUnits($balance->quantity_on_hand ?? '0.000');
                $reserved = InventoryDecimal::units($balance->reserved_quantity ?? '0.000');
                if ($consumption['quantity'] > $onHand - $reserved) {
                    throw ValidationException::withMessages(['quantity' => "Insufficient available stock for {$consumption['materialName']} in {$warehouse->name}."]);
                }
                $unitCost = InventoryDecimal::cost($balance->average_unit_cost ?? '0.0000');
                if ($unitCost <= 0) {
                    throw ValidationException::withMessages(['inventory' => "Missing WAC/cost for {$consumption['materialName']} in {$warehouse->name}."]);
                }
                $cost = Money::cents(InventoryDecimal::totalCost($consumption['quantity'], $unitCost));
                $cogs += $cost;
                $movements[] = $consumption + ['warehouseId' => (int) $warehouse->id, 'warehouseName' => $warehouse->name, 'unitCostCents' => $unitCost, 'costCents' => $cost];
            }
            $results[(int) $line->id] = ['cogsCents' => $cogs, 'warehouseId' => (int) $warehouse->id, 'warehouseName' => $warehouse->name, 'movements' => $movements];
        }

        return $results;
    }

    /** @param iterable<object> $lines @return array<int, array<string,mixed>> */
    public function consume(Request $request, int $tenantId, object $invoice, iterable $lines, ?int $actorId): array
    {
        $plans = $this->preview($tenantId, $invoice, $lines);
        foreach ($plans as $lineId => $plan) {
            if ($plan['movements'] === []) {
                continue;
            }
            $actual = $this->movements->consume($request, $tenantId, (int) $invoice->branch_id, $plan['warehouseId'], 'sales_invoice_line', $lineId, array_map(fn (array $m): array => ['materialId' => $m['materialId'], 'baseUnit' => $m['baseUnit'], 'quantity' => $m['quantity']], $plan['movements']), $actorId);
            $actualByItem = collect($actual['movements'])->keyBy('itemId');
            $plans[$lineId]['cogsCents'] = $actual['cogsCents'];
            $plans[$lineId]['movements'] = array_map(function (array $planned) use ($actualByItem): array {
                $written = $actualByItem->get($planned['materialId']);

                return $planned + ['movementId' => $written['movementId'] ?? null, 'costCents' => $written['costCents'] ?? $planned['costCents']];
            }, $plan['movements']);
        }

        return $plans;
    }

    private function tracked(object $product): bool
    {
        return (bool) $product->is_stock_tracked || (bool) $product->inventory_controlled;
    }

    /** No "main"/"primary" warehouse concept — same resolution POS uses (App\Services\PosInventoryWarehouseResolver). */
    private function warehouse(int $tenantId, int $branchId): ?object
    {
        try {
            return $this->warehouseResolver->forBranch($tenantId, $branchId);
        } catch (OrderLifecycleException) {
            return null;
        }
    }

    private function components(int $tenantId, int $productId, int $variantId)
    {
        $variant = ProductVariant::query()
            ->where('tenant_id', $tenantId)->where('product_id', $productId)->whereKey($variantId)
            ->where('is_active', true)->with(['product.recipe.components', 'recipe.components'])
            ->first();
        if (! $variant || $variant->trashed()) {
            throw ValidationException::withMessages(['variantId' => 'Selected product variant is inactive or unavailable.']);
        }

        return collect($this->recipes->effectiveRecipe($variant)['effectiveComponents']);
    }
}
