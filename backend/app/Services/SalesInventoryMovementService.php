<?php

namespace App\Services;

use App\Domain\Inventory\InventoryPostingService;
use App\Support\InventoryDecimal;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** The shared final movement writer used by POS consumption and manual Sales Invoice consumption. */
final class SalesInventoryMovementService
{
    public function __construct(private readonly InventoryPostingService $posting) {}

    /** @param array<int, array{materialId:int,baseUnit:string,quantity:int}> $consumptions */
    public function consume(Request $request, int $tenantId, int $branchId, int $warehouseId, string $referenceType, int $referenceId, array $consumptions, ?int $actorId): array
    {
        $cost = 0; $movements = [];
        foreach ($consumptions as $consumption) {
            if ($consumption['quantity'] <= 0) continue;
            $result = $this->posting->post($request, $tenantId, [
                'warehouseId' => $warehouseId, 'itemId' => $consumption['materialId'], 'type' => 'sale_consumption',
                'quantity' => InventoryDecimal::quantity($consumption['quantity']), 'unit' => $consumption['baseUnit'], 'branchId' => $branchId,
                'referenceType' => $referenceType, 'referenceId' => $referenceId,
                'idempotencyKey' => $referenceType === 'order_item'
                    ? "sale-consumption-{$tenantId}-{$referenceId}-{$consumption['materialId']}"
                    : "sale-consumption-{$tenantId}-{$referenceType}-{$referenceId}-{$consumption['materialId']}",
            ], $actorId);
            $movement = DB::table('stock_movements')->where('tenant_id', $tenantId)->where('id', $result->movementId)->first();
            $amount = Money::cents($movement->total_cost ?? '0'); $cost += $amount;
            $movements[] = ['movementId' => (int) $result->movementId, 'itemId' => (int) $consumption['materialId'], 'quantity' => InventoryDecimal::quantity($consumption['quantity']), 'unit' => $consumption['baseUnit'], 'costCents' => $amount];
        }
        return ['cogsCents' => $cost, 'movements' => $movements];
    }

    /**
     * Restocks materials returned via a Sales Credit Note, using the
     * ORIGINAL sale's cost snapshot as the inbound unit cost (never today's
     * WAC, never a fabricated purchase price — docs/sales Phase 4 §13/§15).
     * `return_in` is already registered as an inbound type in
     * InventoryPostingService::INCOMING and is explicitly excluded from
     * automatic Finance mapping (InventoryAccountingMapper), so the Credit
     * Note's own journal owns the Inventory Asset / COGS reversal lines —
     * exactly the same "shared writer, caller owns the journal" shape as
     * consume() above.
     *
     * @param array<int, array{materialId:int,baseUnit:string,quantity:int,unitCostCents:int}> $restorations
     */
    public function restore(Request $request, int $tenantId, int $branchId, int $warehouseId, string $referenceType, int $referenceId, array $restorations, ?int $actorId): array
    {
        $cost = 0; $movements = [];
        foreach ($restorations as $index => $restoration) {
            if ($restoration['quantity'] <= 0) continue;
            $result = $this->posting->post($request, $tenantId, [
                'warehouseId' => $warehouseId, 'itemId' => $restoration['materialId'], 'type' => 'return_in',
                'quantity' => InventoryDecimal::quantity($restoration['quantity']), 'unit' => $restoration['baseUnit'], 'branchId' => $branchId,
                'unitCost' => InventoryDecimal::unitCost($restoration['unitCostCents']),
                'referenceType' => $referenceType, 'referenceId' => $referenceId,
                'idempotencyKey' => "sale-return-{$tenantId}-{$referenceType}-{$referenceId}-{$restoration['materialId']}-{$index}",
            ], $actorId);
            $movement = DB::table('stock_movements')->where('tenant_id', $tenantId)->where('id', $result->movementId)->first();
            $amount = Money::cents($movement->total_cost ?? '0'); $cost += $amount;
            $movements[] = ['movementId' => (int) $result->movementId, 'itemId' => (int) $restoration['materialId'], 'quantity' => InventoryDecimal::quantity($restoration['quantity']), 'unit' => $restoration['baseUnit'], 'costCents' => $amount];
        }
        return ['cogsCents' => $cost, 'movements' => $movements];
    }
}
