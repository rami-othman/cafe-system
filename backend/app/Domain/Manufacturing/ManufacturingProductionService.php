<?php

namespace App\Domain\Manufacturing;

use App\Domain\Inventory\InventoryPostingService;
use App\Domain\Inventory\UnitConversionResolver;
use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\InventoryDecimal;
use App\Support\Money;
use App\Support\FactoryWarehouseScope;
use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use App\Support\WarehousePresentation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Production preview/draft/completion/reversal. Every stock or cost effect
 * flows through InventoryPostingService::post() (the existing WAC engine) —
 * this service never writes stock_balances/inventory_items cost columns
 * itself, and never invents its own negative-stock policy: it calls post()
 * the same way every other manual/explicit stock-affecting write path in the
 * app does, which blocks negative stock by default.
 *
 * completion is one DB::transaction(); every post() call inside it becomes a
 * nested transaction (Postgres savepoint), so consumption + output +
 * balances + WAC either all commit or none do.
 *
 * Managerial additional costs (labor/electricity/other) are stored as a
 * memo-only JSON column and never affect actual_material_cost/actual_unit_cost
 * or any Finance posting — see the "Managerial additional costs" decision in
 * the Phase 0 report.
 */
final class ManufacturingProductionService
{
    public function __construct(
        private readonly UnitConversionResolver $conversions,
        private readonly InventoryPostingService $posting,
        private readonly ManufacturingReferenceGenerator $references,
        private readonly ManufacturingAuditService $audit,
    ) {}

    public function preview(int $tenantId, array $data): array
    {
        FactoryWarehouseScope::assertFactoryBranch($tenantId, ! empty($data['branchId']) ? (int) $data['branchId'] : null);
        $recipe = $this->loadActiveRecipeOrThrow($tenantId, (int) $data['recipeId']);
        abort_unless((int) $recipe->branch_id === (int) $data['branchId'], 422, 'الوصفة تتبع فرع معمل آخر.');
        $version = DB::table('manufacturing_recipe_versions')->where('id', $recipe->current_version_id)->first();
        $qty = (string) $data['qty'];
        if (! preg_match('/^\d+(\.\d{1,3})?$/', trim($qty)) || (float) $qty <= 0) {
            return ['recipeId' => $recipe->id, 'qty' => 0, 'rows' => [], 'hasConversionIssue' => false, 'hasInsufficient' => false, 'batchCost' => null, 'unitCost' => null];
        }
        $warehouseId = ! empty($data['warehouseId']) ? (int) $data['warehouseId'] : null;
        if ($warehouseId) {
            $this->loadWarehouse($tenantId, $warehouseId);
            FactoryWarehouseScope::assertDestination($tenantId, ! empty($data['branchId']) ? (int) $data['branchId'] : null, $warehouseId);
        }

        return $this->computeScaledLines($tenantId, $recipe, $version, $qty, $warehouseId);
    }

    public function createDraft(Request $request, int $tenantId, array $data, ?int $actorId): array
    {
        FactoryWarehouseScope::assertFactoryBranch($tenantId, ! empty($data['branchId']) ? (int) $data['branchId'] : null);
        $fingerprint = IdempotencyFingerprint::from($data);
        if (! empty($data['idempotencyKey'])) {
            $existing = DB::table('manufacturing_orders')->where('tenant_id', $tenantId)->where('idempotency_key', $data['idempotencyKey'])->first();
            if ($existing) {
                if ($existing->idempotency_hash !== $fingerprint) {
                    throw ManufacturingDomainException::idempotencyConflict();
                }

                return $this->getDraft($tenantId, (int) $existing->id) ?? throw ManufacturingDomainException::draftNotFound();
            }
        }

        return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $fingerprint) {
            $recipe = $this->loadActiveRecipeOrThrow($tenantId, (int) $data['recipeId']);
            abort_unless((int) $recipe->branch_id === (int) $data['branchId'], 422, 'الوصفة تتبع فرع معمل آخر.');
            $version = DB::table('manufacturing_recipe_versions')->where('id', $recipe->current_version_id)->first();
            $warehouse = $this->loadWarehouse($tenantId, (int) $data['warehouseId']);
            FactoryWarehouseScope::assertDestination($tenantId, ! empty($data['branchId']) ? (int) $data['branchId'] : null, (int) $warehouse->id);
            FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);
            $this->assertRecipeItemsAssigned($tenantId, (int) $warehouse->id, (int) $recipe->product_item_id, (int) $version->id);

            $qty = (string) $data['qty'];
            if (! preg_match('/^\d+(\.\d{1,3})?$/', trim($qty)) || (float) $qty <= 0) {
                throw ManufacturingDomainException::validationFailed('qty', 'Quantity must be greater than zero.');
            }
            $preview = $this->computeScaledLines($tenantId, $recipe, $version, $qty, (int) $warehouse->id);
            if ($preview['hasConversionIssue']) {
                throw ManufacturingDomainException::missingUnitConversion('', '', '');
            }

            $orderId = DB::table('manufacturing_orders')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $warehouse->branch_id, 'warehouse_id' => $warehouse->id,
                'manufacturing_recipe_id' => $recipe->id, 'manufacturing_recipe_version_id' => $version->id,
                'output_item_id' => $recipe->product_item_id, 'status' => 'draft',
                'planned_quantity' => $qty, 'planned_unit' => $version->output_unit,
                'expected_material_cost' => $preview['batchCost'], 'expected_unit_cost' => $preview['unitCost'],
                'production_date' => $data['date'] ?? now()->toDateString(),
                'idempotency_key' => $data['idempotencyKey'] ?? null, 'idempotency_hash' => $fingerprint,
                'created_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
            ]);

            $lineRows = [];
            foreach ($preview['rows'] as $row) {
                $lineRows[] = ['tenant_id' => $tenantId, 'manufacturing_order_id' => $orderId, 'inventory_item_id' => $row['materialId'], 'planned_quantity' => $row['reqBase'], 'unit' => $row['baseUnit']];
            }
            DB::table('manufacturing_order_lines')->insert($lineRows);

            $this->audit->log($tenantId, 'manufacturing_order', $orderId, 'production.draft_created', null, ['recipeId' => $recipe->id, 'qty' => $qty, 'warehouseId' => $warehouse->id], $actorId);

            return $this->getDraft($tenantId, $orderId);
        });
    }

    public function getDraft(int $tenantId, int $orderId): ?array
    {
        $order = DB::table('manufacturing_orders')->where('tenant_id', $tenantId)->where('id', $orderId)->where('status', 'draft')->first();
        if (! $order) {
            return null;
        }
        $lines = DB::table('manufacturing_order_lines as l')->join('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')
            ->where('l.manufacturing_order_id', $orderId)->select('l.*', 'i.unit as base_unit', 'i.name_ar', 'i.name_en')->get();

        return [
            'id' => (int) $order->id, 'recipeId' => (int) $order->manufacturing_recipe_id, 'warehouseId' => (int) $order->warehouse_id,
            'qty' => (string) $order->planned_quantity, 'date' => $order->production_date,
            'unit' => $order->planned_unit,
            'preview' => ['batchCost' => $order->expected_material_cost, 'unitCost' => $order->expected_unit_cost],
            'consumption' => $lines->map(fn ($l) => ['materialId' => (int) $l->inventory_item_id, 'name' => $l->name_ar ?: $l->name_en, 'planned' => (string) $l->planned_quantity, 'actual' => (string) $l->planned_quantity, 'unit' => $l->unit])->all(),
        ];
    }

    public function complete(Request $request, int $tenantId, int $draftId, array $data, ?int $actorId): array
    {
        $fingerprint = IdempotencyFingerprint::from($data);
        if (! empty($data['idempotencyKey'])) {
            $existing = DB::table('manufacturing_orders')->where('tenant_id', $tenantId)->where('id', $draftId)->where('complete_idempotency_key', $data['idempotencyKey'])->first();
            if ($existing) {
                if ($existing->complete_idempotency_hash !== $fingerprint) {
                    throw ManufacturingDomainException::idempotencyConflict();
                }

                return $this->get($tenantId, (int) $existing->id) ?? throw ManufacturingDomainException::draftNotFound();
            }
        }

        return DB::transaction(function () use ($request, $tenantId, $draftId, $data, $actorId, $fingerprint) {
            $order = DB::table('manufacturing_orders')->where('tenant_id', $tenantId)->where('id', $draftId)->lockForUpdate()->first();
            if (! $order) {
                throw ManufacturingDomainException::draftNotFound();
            }
            if ($order->status === 'completed') {
                if (! empty($data['idempotencyKey']) && $order->complete_idempotency_key === $data['idempotencyKey']) {
                    if ($order->complete_idempotency_hash !== $fingerprint) {
                        throw ManufacturingDomainException::idempotencyConflict();
                    }
                    return $this->get($tenantId, (int) $order->id);
                }
                throw ManufacturingDomainException::alreadyCompleted();
            }
            if ($order->status !== 'draft') {
                throw ManufacturingDomainException::draftNotFound();
            }

            $actualQty = (string) $data['actualQty'];
            if (! preg_match('/^\d+(\.\d{1,3})?$/', trim($actualQty)) || (float) $actualQty <= 0) {
                throw ManufacturingDomainException::invalidActualOutput();
            }

            $warehouse = $this->loadWarehouse($tenantId, (int) $order->warehouse_id);
            FactoryWarehouseScope::assertFactoryBranch($tenantId, $order->branch_id ? (int) $order->branch_id : null);
            FactoryWarehouseScope::assertDestination($tenantId, $order->branch_id ? (int) $order->branch_id : null, (int) $warehouse->id);
            FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);
            $outputItem = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $order->output_item_id)->first();
            $version = DB::table('manufacturing_recipe_versions')->where('id', $order->manufacturing_recipe_version_id)->first();
            $this->assertRecipeItemsAssigned($tenantId, (int) $warehouse->id, (int) $order->output_item_id, (int) $version->id);

            $lines = DB::table('manufacturing_order_lines as l')->join('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')
                ->where('l.manufacturing_order_id', $draftId)->select('l.*', 'i.name_ar', 'i.name_en', 'i.unit as base_unit')->get();
            $actuals = collect($data['consumption'] ?? [])->keyBy('materialId');
            if ($actuals->keys()->diff($lines->pluck('inventory_item_id'))->isNotEmpty()) {
                throw ValidationException::withMessages(['consumption' => 'الاستهلاك يجب أن يكون لمواد هذه الوصفة فقط.']);
            }
            $outputConversion = $this->conversions->resolve($tenantId, $outputItem, $actualQty, $version->output_unit);
            if ($outputConversion['baseQuantity'] <= 0) {
                throw ManufacturingDomainException::invalidActualOutput();
            }
            if (! empty($data['waste']['unit']) && \App\Support\InventoryUnitCatalog::normalize($data['waste']['unit']) !== \App\Support\InventoryUnitCatalog::normalize($version->output_unit)) {
                throw ValidationException::withMessages(['waste.unit' => 'وحدة الهدر يجب أن تكون وحدة المنتج في أمر الإنتاج.']);
            }

            $totalMaterialCostCents = 0;
            foreach ($lines as $line) {
                $override = $actuals->get((int) $line->inventory_item_id);
                $actualLineQty = $override && isset($override['actual']) && $override['actual'] !== '' ? (string) $override['actual'] : (string) $line->planned_quantity;
                if (InventoryDecimal::units($actualLineQty) === 0) {
                    DB::table('manufacturing_order_lines')->where('id', $line->id)->update(['actual_quantity' => '0.000', 'unit_cost' => '0.0000', 'total_cost' => '0.00']);
                    continue; // a zeroed-out override means this ingredient truly wasn't consumed
                }

                try {
                    $result = $this->posting->post($request, $tenantId, [
                        'warehouseId' => $warehouse->id, 'itemId' => $line->inventory_item_id, 'branchId' => $warehouse->branch_id,
                        'type' => 'production_consumption', 'quantity' => $actualLineQty, 'unit' => $line->base_unit,
                        'referenceType' => 'manufacturing_order', 'referenceId' => $draftId,
                        'idempotencyKey' => 'mfg-consume-'.$draftId.'-'.$line->inventory_item_id,
                    ], $actorId);
                } catch (ValidationException $error) {
                    if (isset($error->errors()['quantity'])) {
                        throw ManufacturingDomainException::insufficientStock($line->name_ar ?: $line->name_en, $actualLineQty, $line->base_unit);
                    }
                    throw $error;
                }
                $movement = DB::table('stock_movements')->where('id', $result->movementId)->first();
                $totalMaterialCostCents += Money::cents((string) $movement->total_cost);

                DB::table('manufacturing_order_lines')->where('id', $line->id)->update([
                    'actual_quantity' => $actualLineQty, 'unit_cost' => $movement->unit_cost, 'total_cost' => $movement->total_cost,
                    'consumption_movement_id' => $result->movementId,
                ]);
            }

            $actualMaterialCost = Money::decimal($totalMaterialCostCents);
            $actualUnitCost = InventoryDecimal::unitCost(InventoryDecimal::unitCostFromTotal($totalMaterialCostCents, InventoryDecimal::units($actualQty)));
            $baseUnitCost = InventoryDecimal::unitCost(InventoryDecimal::unitCostFromTotal($totalMaterialCostCents, $outputConversion['baseQuantity']));

            $outputResult = $this->posting->post($request, $tenantId, [
                'warehouseId' => $warehouse->id, 'itemId' => $outputItem->id, 'branchId' => $warehouse->branch_id,
                'type' => 'production_output', 'quantity' => $actualQty, 'unit' => $version->output_unit, 'unitCost' => $baseUnitCost,
                'referenceType' => 'manufacturing_order', 'referenceId' => $draftId,
                'idempotencyKey' => 'mfg-output-'.$draftId,
            ], $actorId);

            $reference = $this->references->next($tenantId, 'PR');
            $productionDate = $data['date'] ?? $order->production_date ?? now()->toDateString();
            $expiryDate = $this->computeExpiry($productionDate, $version->shelf_life_value, $version->shelf_life_unit);

            $waste = $data['waste'] ?? null;
            $update = [
                'status' => 'completed', 'reference' => $reference,
                'actual_quantity' => $actualQty, 'actual_material_cost' => $actualMaterialCost, 'actual_unit_cost' => $actualUnitCost,
                'additional_managerial_costs' => isset($data['additionalCosts']) ? json_encode($data['additionalCosts']) : null,
                'waste_quantity' => $waste['qty'] ?? null, 'waste_unit' => $waste ? $version->output_unit : null, 'waste_reason' => $waste['reason'] ?? null, 'waste_notes' => $waste['notes'] ?? null,
                'production_date' => $productionDate, 'expiry_date' => $expiryDate,
                'output_movement_id' => $outputResult->movementId,
                'complete_idempotency_key' => $data['idempotencyKey'] ?? null, 'complete_idempotency_hash' => $fingerprint,
                'updated_at' => now(),
            ];
            DB::table('manufacturing_orders')->where('id', $draftId)->update($update);

            // One batch/lot row per completed production order — see
            // "manufacturing_batches" migration. remaining_quantity starts equal
            // to produced_quantity and is decremented as this specific output
            // item is consumed (InventoryPostingService's FEFO batch hook).
            DB::table('manufacturing_batches')->insert([
                'tenant_id' => $tenantId, 'manufacturing_order_id' => $draftId, 'inventory_item_id' => $outputItem->id, 'warehouse_id' => $warehouse->id,
                'produced_quantity' => InventoryDecimal::quantity($outputConversion['baseQuantity']), 'remaining_quantity' => InventoryDecimal::quantity($outputConversion['baseQuantity']),
                'production_date' => $productionDate, 'expiry_date' => $expiryDate,
                'created_at' => now(), 'updated_at' => now(),
            ]);

            $this->audit->log($tenantId, 'manufacturing_order', $draftId, 'production.completed', null, ['reference' => $reference, 'actualQty' => $actualQty, 'actualMaterialCost' => $actualMaterialCost], $actorId);

            return $this->get($tenantId, $draftId);
        });
    }

    public function get(int $tenantId, int|string $orderIdOrReference): ?array
    {
        $query = DB::table('manufacturing_orders')->where('tenant_id', $tenantId);
        $order = is_numeric($orderIdOrReference)
            ? $query->where('id', (int) $orderIdOrReference)->first()
            : $query->where('reference', $orderIdOrReference)->first();
        if (! $order) {
            return null;
        }

        return $this->serializeOrder($tenantId, $order);
    }

    public function list(int $tenantId, array $filters): array
    {
        $query = DB::table('manufacturing_orders as o')
            ->join('inventory_items as i', 'i.id', '=', 'o.output_item_id')
            ->leftJoin('warehouses as w', 'w.id', '=', 'o.warehouse_id')
            ->where('o.tenant_id', $tenantId)
            ->select('o.*', 'i.name_ar', 'i.name_en', 'i.item_type', 'w.name as warehouse_name');

        if (! empty($filters['search'])) {
            $search = '%'.strtolower((string) $filters['search']).'%';
            $query->where(fn ($q) => $q->whereRaw('LOWER(o.reference) LIKE ?', [$search])->orWhereRaw('LOWER(i.name_en) LIKE ?', [$search])->orWhereRaw('LOWER(i.name_ar) LIKE ?', [$search]));
        }
        if (! empty($filters['warehouseId'])) {
            $query->where('o.warehouse_id', $filters['warehouseId']);
        }
        if (! empty($filters['branchId'])) {
            $query->where('o.branch_id', $filters['branchId']);
        }
        if (! empty($filters['status']) && $filters['status'] !== 'all') {
            $query->where('o.status', $filters['status']);
        }
        if (! empty($filters['type']) && $filters['type'] !== 'all') {
            $query->where('i.item_type', $filters['type']);
        }

        $query->whereIn('o.branch_id', $filters['accessibleBranchIds'] ?? []);
        return $query->orderByDesc('o.created_at')->get()->map(fn ($row) => [
            'id' => $row->reference ?: ('draft_'.$row->id), 'recordId' => (int) $row->id,
            'product' => $row->name_ar ?: $row->name_en, 'type' => $row->item_type, 'warehouseId' => (int) $row->warehouse_id, 'warehouse' => $row->warehouse_name,
            'planned' => (string) $row->planned_quantity, 'actual' => $row->actual_quantity !== null ? (string) $row->actual_quantity : null,
            'unit' => $row->planned_unit, 'plannedCost' => $row->expected_material_cost, 'actualCost' => $row->actual_material_cost,
            'status' => $row->status, 'date' => $row->created_at,
        ])->all();
    }

    public function reverse(Request $request, int $tenantId, int $orderId, string $reason, ?int $actorId, ?string $idempotencyKey = null): array
    {
        return DB::transaction(function () use ($request, $tenantId, $orderId, $reason, $actorId, $idempotencyKey) {
            $order = DB::table('manufacturing_orders')->where('tenant_id', $tenantId)->where('id', $orderId)->lockForUpdate()->first();
            if (! $order) {
                throw ManufacturingDomainException::draftNotFound();
            }
            if ($idempotencyKey && $order->reverse_idempotency_key === $idempotencyKey) {
                return $this->get($tenantId, $orderId);
            }
            if ($order->status === 'reversed') {
                throw ManufacturingDomainException::alreadyReversed();
            }
            if ($order->status !== 'completed') {
                throw ManufacturingDomainException::draftNotFound();
            }

            $warehouse = $this->loadWarehouse($tenantId, (int) $order->warehouse_id);
            FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);

            $outputMovement = DB::table('stock_movements')->where('tenant_id', $tenantId)->where('id', $order->output_movement_id)->first();
            $produced = (float) $outputMovement->quantity_in;
            $batch = DB::table('manufacturing_batches')->where('tenant_id', $tenantId)->where('manufacturing_order_id', $orderId)->lockForUpdate()->first();
            if ($batch) {
                // Batch-aware check: this specific order's own lot, not item-level
                // on-hand (which may also include other, unrelated batches of the
                // same item). Closes the "batch-blind" reversal gap.
                $remaining = min($produced, (float) $batch->remaining_quantity);
            } else {
                // Fallback for orders completed before manufacturing_batches
                // existed (no batch row to check): fall back to item-level on-hand.
                $balance = DB::table('stock_balances')->where('tenant_id', $tenantId)->where('warehouse_id', $order->warehouse_id)->where('inventory_item_id', $order->output_item_id)->lockForUpdate()->first();
                $onHand = $balance ? (float) $balance->quantity_on_hand : 0.0;
                $remaining = min($produced, $onHand);
            }

            $consumed = round($produced - $remaining, 3);
            // Reversal is all-or-nothing: if any part of this specific batch has
            // already been consumed/sold, the whole production is blocked from
            // reversal (no silent partial reversal — the caller must know the
            // exact state, not have stock quietly reshuffled underneath them).
            if ($remaining < $produced) {
                throw ManufacturingDomainException::notReversible((int) round($produced * 1000), (int) round($remaining * 1000), (int) round($consumed * 1000));
            }

            $outputReverse = $this->posting->post($request, $tenantId, [
                'warehouseId' => $warehouse->id, 'itemId' => $order->output_item_id, 'branchId' => $warehouse->branch_id,
                'type' => 'stock_out', 'quantity' => (string) $produced, 'reason' => 'Manufacturing reversal: '.$reason,
                'referenceType' => 'manufacturing_order_reversal', 'referenceId' => $orderId,
                'unitCost' => $outputMovement->unit_cost, 'revalueAfterRemoval' => true,
                'idempotencyKey' => 'mfg-reverse-output-'.$orderId,
            ], $actorId);

            $lines = DB::table('manufacturing_order_lines')->where('manufacturing_order_id', $orderId)->get();
            foreach ($lines as $line) {
                if ($line->actual_quantity === null || (float) $line->actual_quantity <= 0) {
                    continue;
                }
                $restoreQty = (float) $line->actual_quantity;
                $this->posting->post($request, $tenantId, [
                    'warehouseId' => $warehouse->id, 'itemId' => $line->inventory_item_id, 'branchId' => $warehouse->branch_id,
                    'type' => 'stock_in', 'quantity' => (string) $restoreQty, 'unitCost' => $line->unit_cost,
                    'referenceType' => 'manufacturing_order_reversal', 'referenceId' => $orderId,
                    'idempotencyKey' => 'mfg-reverse-line-'.$orderId.'-'.$line->id,
                ], $actorId);
            }

            if ($batch) {
                DB::table('manufacturing_batches')->where('id', $batch->id)->update(['remaining_quantity' => '0.000', 'updated_at' => now()]);
            }

            DB::table('manufacturing_orders')->where('id', $orderId)->update([
                'status' => 'reversed', 'reverse_reason' => $reason, 'reversed_at' => now(), 'reversed_by' => $actorId,
                'reverse_idempotency_key' => $idempotencyKey, 'updated_at' => now(),
            ]);

            $this->audit->log($tenantId, 'manufacturing_order', $orderId, 'production.reversed', null, ['reason' => $reason, 'reversedQty' => $produced, 'consumedQty' => $consumed], $actorId);

            return $this->get($tenantId, $orderId);
        });
    }

    // ---- internals ----

    private function assertRecipeItemsAssigned(int $tenantId, int $warehouseId, int $outputItemId, int $versionId): void
    {
        $ids = DB::table('manufacturing_recipe_version_lines')->where('manufacturing_recipe_version_id', $versionId)->pluck('inventory_item_id')->push($outputItemId)->unique();
        if (DB::table('inventory_items')->where('tenant_id', $tenantId)->whereIn('id', $ids)->where('is_active', true)->whereNull('deleted_at')->count() !== $ids->count()) {
            throw ValidationException::withMessages(['recipeId' => 'مواد الوصفة والمنتج يجب أن تكون نشطة قبل الإنتاج.']);
        }
        $assigned = DB::table('inventory_item_warehouses')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)->whereIn('inventory_item_id', $ids)->pluck('inventory_item_id');
        $missing = $ids->diff($assigned);
        if ($missing->isNotEmpty()) {
            $names = DB::table('inventory_items')->where('tenant_id', $tenantId)->whereIn('id', $missing)->pluck('name_ar')->implode('، ');
            throw ValidationException::withMessages(['warehouseId' => 'فعّل مواد الوصفة والمنتج لهذا المخزن من تعديل المادة: '.$names]);
        }
    }

    private function loadActiveRecipeOrThrow(int $tenantId, int $recipeId): object
    {
        $recipe = DB::table('manufacturing_recipes')->where('tenant_id', $tenantId)->where('id', $recipeId)->whereNull('deleted_at')->first();
        if (! $recipe || ! $recipe->current_version_id) {
            throw ManufacturingDomainException::recipeNotFound();
        }
        if ($recipe->status !== 'active') {
            throw ManufacturingDomainException::recipeInactive();
        }

        return $recipe;
    }

    private function loadWarehouse(int $tenantId, int $warehouseId): object
    {
        $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $warehouse) {
            throw ManufacturingDomainException::warehouseNotAllowed();
        }
        if (WarehousePresentation::isLegacy($warehouse->code)) {
            throw ManufacturingDomainException::warehouseNotAllowed();
        }

        return $warehouse;
    }

    private function computeScaledLines(int $tenantId, object $recipe, object $version, string $qty, ?int $warehouseId): array
    {
        $lines = DB::table('manufacturing_recipe_version_lines as l')->join('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')
            ->where('l.manufacturing_recipe_version_id', $version->id)->orderBy('l.sort_order')
            ->select('l.*', 'i.name_ar', 'i.name_en', 'i.item_type', 'i.unit as base_unit', 'i.cost_per_unit')->get();

        $stock = $warehouseId ? DB::table('stock_balances')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)->whereIn('inventory_item_id', $lines->pluck('inventory_item_id'))->get()->keyBy('inventory_item_id') : collect();

        $rows = [];
        $hasConversionIssue = false;
        $hasInsufficient = false;
        $batchCostCents = 0;
        $costIncomplete = false;

        foreach ($lines as $l) {
            $scaledQty = BigDecimal::of($l->quantity)->multipliedBy($qty)->dividedBy($version->output_quantity, 6, RoundingMode::HALF_UP);
            $item = (object) ['id' => $l->inventory_item_id, 'unit' => $l->base_unit];
            $row = ['materialId' => (int) $l->inventory_item_id, 'name' => $l->name_ar ?: $l->name_en, 'semiFinished' => $l->item_type === 'semi_finished_good', 'baseUnit' => $l->base_unit];
            try {
                $resolved = $this->conversions->resolveRecipe($tenantId, $item, (string) $scaledQty, $l->unit);
                $row['reqBase'] = InventoryDecimal::quantity($resolved['baseQuantity']);
                $row['convError'] = false;
            } catch (ValidationException) {
                $row['reqBase'] = null;
                $row['convError'] = true;
                $hasConversionIssue = true;
                $rows[] = $row + ['available' => null, 'after' => null, 'status' => 'إعداد وحدة مطلوب', 'level' => 'danger', 'deficit' => 0];

                continue;
            }

            $balance = $stock->get($l->inventory_item_id);
            $costPerUnit = InventoryDecimal::cost($warehouseId ? ($balance->average_unit_cost ?? '0') : $l->cost_per_unit);
            if ($warehouseId && ! $balance) {
                $costIncomplete = true;
            } else {
                $batchCostCents += Money::cents(InventoryDecimal::totalCost($resolved['baseQuantity'], $costPerUnit));
            }

            $available = null;
            $after = null;
            $status = '—';
            $level = 'neutral';
            $deficit = 0;
            if ($warehouseId) {
                $available = $balance ? max(0, (float) $balance->quantity_on_hand - (float) $balance->reserved_quantity) : 0.0;
                $after = round($available - (float) $row['reqBase'], 3);
                if ($after < 0) {
                    $status = 'غير كافٍ';
                    $level = 'danger';
                    $hasInsufficient = true;
                    $deficit = abs($after);
                } else {
                    $status = 'متوفر';
                    $level = 'ok';
                }
            }
            $rows[] = $row + ['available' => $available, 'after' => $after, 'status' => $status, 'level' => $level, 'deficit' => $deficit];
        }

        $batchCost = $costIncomplete ? null : round($batchCostCents / 100, 2);
        $unitCost = $batchCost !== null ? (float) InventoryDecimal::unitCost(InventoryDecimal::unitCostFromTotal($batchCostCents, InventoryDecimal::units($qty))) : null;

        return ['recipeId' => (int) $recipe->id, 'qty' => (float) $qty, 'rows' => $rows, 'hasConversionIssue' => $hasConversionIssue, 'hasInsufficient' => $hasInsufficient, 'batchCost' => $batchCost, 'unitCost' => $unitCost];
    }

    private function computeExpiry(string $productionDate, ?int $shelfValue, ?string $shelfUnit): ?string
    {
        if ($shelfValue === null || $shelfUnit === null) {
            return null;
        }
        $days = $shelfUnit === 'hours' ? (int) ceil($shelfValue / 24) : (int) $shelfValue;

        return \Carbon\CarbonImmutable::parse($productionDate)->addDays($days)->toDateString();
    }

    private function serializeOrder(int $tenantId, object $order): array
    {
        $item = DB::table('inventory_items')->where('id', $order->output_item_id)->first();
        $warehouse = DB::table('warehouses')->where('id', $order->warehouse_id)->first();
        $version = DB::table('manufacturing_recipe_versions')->where('id', $order->manufacturing_recipe_version_id)->first();
        $creator = $order->created_by ? DB::table('users')->where('id', $order->created_by)->value('name') : null;
        $lines = DB::table('manufacturing_order_lines as l')->join('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')
            ->where('l.manufacturing_order_id', $order->id)->select('l.*', 'i.name_ar', 'i.name_en')->get();

        $batch = $order->actual_quantity !== null
            ? DB::table('manufacturing_batches')->where('tenant_id', $tenantId)->where('manufacturing_order_id', $order->id)->first()
            : null;
        $balance = $batch ? null : DB::table('stock_balances')->where('tenant_id', $tenantId)->where('warehouse_id', $order->warehouse_id)->where('inventory_item_id', $order->output_item_id)->first();
        $remaining = $batch ? (float) $batch->remaining_quantity : ($balance ? (float) $balance->quantity_on_hand : 0.0);
        $outputMovement = $order->output_movement_id ? DB::table('stock_movements')->where('tenant_id', $tenantId)->where('id', $order->output_movement_id)->first() : null;
        $factor = $outputMovement ? (float) $outputMovement->conversion_factor : 1.0;
        $remaining = $remaining / max($factor, 0.000001);
        $additionalCosts = json_decode($order->additional_managerial_costs ?? '[]', true) ?: [];
        $additionalCents = array_sum(array_map(fn ($cost) => Money::cents($cost['amount']), $additionalCosts));
        $fullCostCents = Money::cents($order->actual_material_cost ?? '0') + $additionalCents;
        $soldQtyEstimate = $order->actual_quantity !== null
            ? max(0, round((float) $order->actual_quantity - min((float) $order->actual_quantity, $remaining), 3))
            : 0;

        return [
            'id' => $order->reference ?: (string) $order->id, 'recordId' => (int) $order->id,
            'recipeId' => (int) $order->manufacturing_recipe_id, 'product' => $item->name_ar ?: $item->name_en, 'type' => $item->item_type,
            'warehouseId' => (int) $order->warehouse_id, 'planned' => (string) $order->planned_quantity, 'actual' => $order->actual_quantity !== null ? (string) $order->actual_quantity : null,
            'unit' => $order->planned_unit, 'plannedCost' => $order->expected_material_cost, 'actualCost' => $order->actual_material_cost,
            'actualUnitCost' => $order->actual_unit_cost, 'additionalCosts' => $additionalCosts,
            'additionalCostTotal' => Money::decimal($additionalCents),
            'fullCost' => $order->actual_quantity !== null ? Money::decimal($fullCostCents) : null,
            'fullUnitCost' => $order->actual_quantity !== null ? InventoryDecimal::unitCost(InventoryDecimal::unitCostFromTotal($fullCostCents, InventoryDecimal::units($order->actual_quantity))) : null,
            'date' => $order->production_date, 'user' => $creator, 'recipeVersion' => 'v'.$version->version_number, 'status' => $order->status,
            'soldQty' => $soldQtyEstimate, 'waste' => $order->waste_quantity !== null ? ['qty' => (string) $order->waste_quantity, 'unit' => $order->waste_unit, 'reason' => $order->waste_reason, 'note' => $order->waste_notes] : null,
            'materialsConsumed' => $lines->map(fn ($l) => ['materialId' => (int) $l->inventory_item_id, 'name' => $l->name_ar ?: $l->name_en, 'planned' => (string) $l->planned_quantity, 'actual' => $l->actual_quantity !== null ? (string) $l->actual_quantity : null, 'unit' => $l->unit, 'unitCost' => $l->unit_cost])->all(),
            'batch' => $order->expiry_date ? ['ref' => $order->reference, 'mfgDate' => $order->production_date, 'shelfLife' => $version->shelf_life_value.' '.($version->shelf_life_unit === 'days' ? 'أيام' : 'ساعات'), 'expiry' => $order->expiry_date] : null,
            'reverseReason' => $order->reverse_reason,
        ];
    }
}
