<?php

namespace App\Domain\Manufacturing;

use App\Domain\Inventory\InventoryPostingService;
use App\Support\FinancialActor;
use App\Support\WarehousePresentation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Product Conversion / Split (تحويل منتج) — pure inventory value transfer
 * between two existing inventory items in the same warehouse. No revenue, no
 * expense. Target receipt cost is always derived from the source's outbound
 * WAC cost (via InventoryPostingService — never entered by hand), matching
 * ManufacturingProductionService's output-costing approach.
 */
final class ManufacturingConversionService
{
    public function __construct(
        private readonly InventoryPostingService $posting,
        private readonly ManufacturingReferenceGenerator $references,
        private readonly ManufacturingAuditService $audit,
    ) {}

    public function convert(Request $request, int $tenantId, array $data, ?int $actorId): array
    {
        \App\Support\FactoryWarehouseScope::assertFactoryBranch($tenantId, ! empty($data['branchId']) ? (int) $data['branchId'] : null);
        \App\Support\FactoryWarehouseScope::assertWarehouseForBranch($tenantId, (int) $data['branchId'], (int) $data['warehouseId']);
        if (! empty($data['idempotencyKey'])) {
            $existing = DB::table('manufacturing_conversions')->where('tenant_id', $tenantId)->where('idempotency_key', $data['idempotencyKey'])->first();
            if ($existing) {
                if ((int) $existing->warehouse_id !== (int) $data['warehouseId']
                    || (int) $existing->source_item_id !== (int) $data['sourceItemId']
                    || (float) $existing->source_quantity !== (float) $data['sourceQty']
                    || (int) $existing->target_item_id !== (int) $data['targetItemId']
                    || (float) $existing->target_quantity !== (float) $data['resultQty']) {
                    throw ManufacturingDomainException::idempotencyConflict();
                }
                return $this->serialize($existing);
            }
        }

        return DB::transaction(function () use ($request, $tenantId, $data, $actorId) {
            $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $data['warehouseId'])->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $warehouse || WarehousePresentation::isLegacy($warehouse->code)) {
                throw ManufacturingDomainException::warehouseNotAllowed();
            }
            FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);

            $sourceId = (int) $data['sourceItemId'];
            $targetId = (int) $data['targetItemId'];
            if ($sourceId === $targetId) {
                throw ManufacturingDomainException::conversionSameItem();
            }
            $source = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $sourceId)->whereNull('deleted_at')->first();
            $target = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $targetId)->whereNull('deleted_at')->first();
            if (! $source || ! $target) {
                throw ManufacturingDomainException::validationFailed('itemId', 'Item not found.');
            }
            $sourceQty = (string) $data['sourceQty'];
            $resultQty = (string) $data['resultQty'];
            if ((float) $sourceQty <= 0 || (float) $resultQty <= 0) {
                throw ManufacturingDomainException::validationFailed('quantity', 'Quantities must be greater than zero.');
            }

            try {
                $sourceMovement = $this->posting->post($request, $tenantId, [
                    'warehouseId' => $warehouse->id, 'itemId' => $sourceId, 'branchId' => $warehouse->branch_id,
                    'type' => 'conversion_consumption', 'quantity' => $sourceQty,
                    'referenceType' => 'manufacturing_conversion', 'idempotencyKey' => 'mfg-conv-src-'.($data['idempotencyKey'] ?? uniqid('', true)),
                ], $actorId);
            } catch (\Illuminate\Validation\ValidationException) {
                throw ManufacturingDomainException::insufficientStock($source->name_ar ?: $source->name_en, '?', $source->unit);
            }
            $sourceRow = DB::table('stock_movements')->where('id', $sourceMovement->movementId)->first();
            $totalCost = (float) $sourceRow->total_cost;
            $resultUnitCost = round($totalCost / (float) $resultQty, 4);

            $targetMovement = $this->posting->post($request, $tenantId, [
                'warehouseId' => $warehouse->id, 'itemId' => $targetId, 'branchId' => $warehouse->branch_id,
                'type' => 'conversion_output', 'quantity' => $resultQty, 'unitCost' => (string) $resultUnitCost,
                'referenceType' => 'manufacturing_conversion', 'idempotencyKey' => 'mfg-conv-tgt-'.($data['idempotencyKey'] ?? uniqid('', true)),
            ], $actorId);

            $reference = $this->references->next($tenantId, 'CV');
            $conversionId = DB::table('manufacturing_conversions')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $warehouse->branch_id, 'warehouse_id' => $warehouse->id, 'status' => 'completed', 'reference' => $reference,
                'source_item_id' => $sourceId, 'source_quantity' => $sourceQty, 'source_unit' => $source->unit, 'source_unit_cost' => $sourceRow->unit_cost,
                'target_item_id' => $targetId, 'target_quantity' => $resultQty, 'target_unit' => $target->unit,
                'total_cost' => $totalCost, 'result_unit_cost' => $resultUnitCost,
                'source_movement_id' => $sourceMovement->movementId, 'target_movement_id' => $targetMovement->movementId,
                'idempotency_key' => $data['idempotencyKey'] ?? null, 'created_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
            ]);

            $this->audit->log($tenantId, 'manufacturing_conversion', $conversionId, 'conversion.completed', null, ['reference' => $reference, 'sourceItemId' => $sourceId, 'targetItemId' => $targetId], $actorId);

            return $this->get($tenantId, $conversionId);
        });
    }

    public function get(int $tenantId, int|string $idOrReference): ?array
    {
        $query = DB::table('manufacturing_conversions')->where('tenant_id', $tenantId);
        $row = is_numeric($idOrReference) ? $query->where('id', (int) $idOrReference)->first() : $query->where('reference', $idOrReference)->first();

        return $row ? $this->serialize($row) : null;
    }

    private function serialize(object $row): array
    {
        $source = DB::table('inventory_items')->where('id', $row->source_item_id)->first();
        $target = DB::table('inventory_items')->where('id', $row->target_item_id)->first();

        return [
            'id' => $row->reference, 'warehouseId' => (int) $row->warehouse_id, 'status' => $row->status,
            'sourceItemId' => (int) $row->source_item_id, 'sourceName' => $source->name_ar ?: $source->name_en, 'sourceUnit' => $row->source_unit, 'sourceQty' => (string) $row->source_quantity, 'sourceUnitCost' => $row->source_unit_cost,
            'targetItemId' => (int) $row->target_item_id, 'targetName' => $target->name_ar ?: $target->name_en, 'targetUnit' => $row->target_unit, 'resultQty' => (string) $row->target_quantity,
            'totalCost' => $row->total_cost, 'resultUnitCost' => $row->result_unit_cost, 'date' => $row->created_at,
        ];
    }
}
