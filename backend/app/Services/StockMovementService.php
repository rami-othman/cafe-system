<?php

namespace App\Services;

use App\Domain\Inventory\InventoryPostingService;
use Illuminate\Http\Request;

/**
 * Compatibility façade for existing workflows.
 *
 * New code must inject InventoryPostingService directly; all balance and
 * movement writes still pass through that single service.
 */
class StockMovementService
{
    public function __construct(private readonly InventoryPostingService $posting) {}

    public function record(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->posting->post($request, $tenantId, $data, $actorId)->movementId;
    }
}
