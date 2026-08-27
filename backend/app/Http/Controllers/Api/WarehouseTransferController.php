<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\StockMovementService;
use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\TenantContext;
use App\Support\WarehousePresentation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class WarehouseTransferController extends Controller
{
    public function __construct(private readonly StockMovementService $movements) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $rows = DB::table('warehouse_transfers as transfers')
            ->join('warehouses as source', 'source.id', '=', 'transfers.source_warehouse_id')
            ->join('warehouses as destination', 'destination.id', '=', 'transfers.destination_warehouse_id')
            ->leftJoin('branches as source_branch', 'source_branch.id', '=', 'source.branch_id')
            ->leftJoin('branches as destination_branch', 'destination_branch.id', '=', 'destination.branch_id')
            ->where('transfers.tenant_id', $tenant)
            ->when($request->filled('status'), fn ($query) => $query->where('transfers.status', $request->string('status')))
            ->orderByDesc('transfers.id')
            ->get(['transfers.*', 'source.name as source_name', 'source.type as source_type', 'source_branch.name as source_branch_name', 'destination.name as destination_name', 'destination.type as destination_type', 'destination_branch.name as destination_branch_name']);

        return response()->json(['data' => $rows->map(fn (object $row) => $this->serialize($tenant, $row, false))->values()]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->validateDraft($request, false);
        $actor = FinancialActor::id($request, $tenant);
        $id = DB::transaction(function () use ($tenant, $data, $actor): int {
            $this->assertWarehouses($tenant, $data['sourceWarehouseId'], $data['destinationWarehouseId'], $actor);
            return (int) DB::table('warehouse_transfers')->insertGetId([
                'tenant_id' => $tenant,
                'source_warehouse_id' => $data['sourceWarehouseId'],
                'destination_warehouse_id' => $data['destinationWarehouseId'],
                'status' => 'draft',
                'notes' => $data['notes'] ?? null,
                'created_by' => $actor,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        });
        return response()->json(['data' => $this->serialize($tenant, $this->find($tenant, $id), true)], 201);
    }

    public function show(Request $request, int $transfer): JsonResponse
    {
        return response()->json(['data' => $this->serialize(TenantContext::id($request), $this->find(TenantContext::id($request), $transfer), true)]);
    }

    public function update(Request $request, int $transfer): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->validateDraft($request, true);
        $actor = FinancialActor::id($request, $tenant);
        DB::transaction(function () use ($tenant, $transfer, $data, $actor): void {
            $row = DB::table('warehouse_transfers')->where('tenant_id', $tenant)->where('id', $transfer)->lockForUpdate()->first();
            abort_unless($row, 404, 'Transfer not found.');
            if ($row->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only draft transfers can be edited.']);
            $source = $data['sourceWarehouseId'] ?? (int) $row->source_warehouse_id;
            $destination = $data['destinationWarehouseId'] ?? (int) $row->destination_warehouse_id;
            $this->assertWarehouses($tenant, $source, $destination, $actor);
            DB::table('warehouse_transfers')->where('id', $transfer)->update(['source_warehouse_id' => $source, 'destination_warehouse_id' => $destination, 'notes' => array_key_exists('notes', $data) ? $data['notes'] : $row->notes, 'updated_at' => now()]);
            if (array_key_exists('lines', $data)) {
                DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $transfer)->delete();
                foreach ($data['lines'] as $line) {
                    $item = DB::table('inventory_items')->where('tenant_id', $tenant)->where('id', $line['itemId'])->where('is_active', true)->whereNull('deleted_at')->first();
                    if (! $item) throw ValidationException::withMessages(['lines' => 'One or more inventory items are unavailable.']);
                    if (! DB::table('inventory_item_warehouses')->where('tenant_id', $tenant)->where('inventory_item_id', $item->id)->where('warehouse_id', $source)->exists()) {
                        throw ValidationException::withMessages(['lines' => 'Each transfer item must be assigned to the source warehouse.']);
                    }
                    DB::table('warehouse_transfer_lines')->insert(['tenant_id' => $tenant, 'warehouse_transfer_id' => $transfer, 'inventory_item_id' => $item->id, 'unit' => $item->unit, 'requested_quantity' => InventoryDecimal::quantity(InventoryDecimal::units($line['requestedQuantity'])), 'unit_cost' => $item->latest_unit_cost, 'created_at' => now(), 'updated_at' => now()]);
                }
            }
        });
        return response()->json(['data' => $this->serialize($tenant, $this->find($tenant, $transfer), true)]);
    }

    public function action(Request $request, int $transfer, string $action): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        if (! in_array($action, ['submit', 'dispatch', 'cancel'], true)) abort(404);
        DB::transaction(function () use ($request, $tenant, $transfer, $action, $actor): void {
            $row = DB::table('warehouse_transfers')->where('tenant_id', $tenant)->where('id', $transfer)->lockForUpdate()->first();
            abort_unless($row, 404, 'Transfer not found.');
            $this->assertWarehouses($tenant, $row->source_warehouse_id, $row->destination_warehouse_id, $actor);
            if ($action === 'cancel') {
                if (! in_array($row->status, ['draft', 'pending_approval', 'approved'], true)) throw ValidationException::withMessages(['status' => 'This transfer can no longer be cancelled.']);
                DB::table('warehouse_transfers')->where('id', $transfer)->update(['status' => 'cancelled', 'updated_at' => now()]);
                return;
            }
            if ($action === 'submit') {
                if ($row->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only a draft can be sent for approval.']);
                if (! DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $transfer)->exists()) throw ValidationException::withMessages(['lines' => 'Add at least one item before submitting.']);
                DB::table('warehouse_transfers')->where('id', $transfer)->update(['status' => 'pending_approval', 'submitted_by' => $actor, 'submitted_at' => now(), 'updated_at' => now()]);
                return;
            }
            if (! in_array($row->status, ['approved', 'pending_approval'], true)) throw ValidationException::withMessages(['status' => 'This transfer cannot be dispatched.']);
            // Pending approval is accepted for installations without a separate approver role.
            $lines = DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $transfer)->lockForUpdate()->get();
            if ($lines->isEmpty()) throw ValidationException::withMessages(['lines' => 'Add at least one item before dispatching.']);
            foreach ($lines as $line) {
                $movementId = $this->movements->record($request, $tenant, ['warehouseId' => $row->source_warehouse_id, 'itemId' => $line->inventory_item_id, 'branchId' => DB::table('warehouses')->where('id', $row->source_warehouse_id)->value('branch_id'), 'type' => 'transfer_out', 'quantity' => $line->requested_quantity, 'referenceType' => 'warehouse_transfer', 'referenceId' => $transfer], $actor);
                DB::table('warehouse_transfer_lines')->where('id', $line->id)->update(['dispatched_quantity' => $line->requested_quantity, 'transfer_out_movement_id' => $movementId, 'updated_at' => now()]);
            }
            DB::table('warehouse_transfers')->where('id', $transfer)->update(['status' => 'in_transit', 'approved_by' => $actor, 'approved_at' => $row->approved_at ?? now(), 'dispatched_by' => $actor, 'dispatched_at' => now(), 'updated_at' => now()]);
        });
        return response()->json(['data' => $this->serialize($tenant, $this->find($tenant, $transfer), true)]);
    }

    public function receive(Request $request, int $transfer): JsonResponse
    {
        $data = $request->validate(['idempotencyKey' => ['required', 'string', 'max:120'], 'lines' => ['required', 'array', 'min:1'], 'lines.*.itemId' => ['required', 'integer', 'distinct'], 'lines.*.receivedQuantity' => ['required', 'regex:/^\d+(\.\d{1,3})?$/']]);
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        DB::transaction(function () use ($request, $data, $tenant, $actor, $transfer): void {
            $existing = DB::table('warehouse_transfer_receipts')->where('warehouse_transfer_id', $transfer)->where('idempotency_key', $data['idempotencyKey'])->lockForUpdate()->first();
            if ($existing) return;
            $row = DB::table('warehouse_transfers')->where('tenant_id', $tenant)->where('id', $transfer)->lockForUpdate()->first();
            abort_unless($row, 404, 'Transfer not found.');
            if (! in_array($row->status, ['in_transit', 'partially_received'], true)) throw ValidationException::withMessages(['status' => 'This transfer is not ready to receive.']);
            $this->assertWarehouses($tenant, $row->source_warehouse_id, $row->destination_warehouse_id, $actor);
            DB::table('warehouse_transfer_receipts')->insert(['tenant_id' => $tenant, 'warehouse_transfer_id' => $transfer, 'idempotency_key' => $data['idempotencyKey'], 'received_by' => $actor, 'created_at' => now(), 'updated_at' => now()]);
            foreach ($data['lines'] as $input) {
                $line = DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $transfer)->where('inventory_item_id', $input['itemId'])->lockForUpdate()->first();
                if (! $line) throw ValidationException::withMessages(['lines' => 'The received item is not part of this transfer.']);
                $quantity = InventoryDecimal::units($input['receivedQuantity']);
                $remaining = InventoryDecimal::units($line->dispatched_quantity) - InventoryDecimal::units($line->received_quantity);
                if ($quantity <= 0 || $quantity > $remaining) throw ValidationException::withMessages(['lines' => 'Received quantity must not exceed the quantity still in transit.']);
                $movementId = $this->movements->record($request, $tenant, ['warehouseId' => $row->destination_warehouse_id, 'itemId' => $line->inventory_item_id, 'branchId' => DB::table('warehouses')->where('id', $row->destination_warehouse_id)->value('branch_id'), 'type' => 'transfer_in', 'quantity' => $input['receivedQuantity'], 'unitCost' => $line->unit_cost, 'referenceType' => 'warehouse_transfer_receipt', 'referenceId' => $transfer], $actor);
                DB::table('warehouse_transfer_lines')->where('id', $line->id)->update(['received_quantity' => InventoryDecimal::quantity(InventoryDecimal::units($line->received_quantity) + $quantity), 'transfer_in_movement_id' => $movementId, 'updated_at' => now()]);
            }
            $complete = ! DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $transfer)->whereColumn('received_quantity', '<', 'dispatched_quantity')->exists();
            DB::table('warehouse_transfers')->where('id', $transfer)->update(['status' => $complete ? 'received' : 'partially_received', 'received_by' => $actor, 'received_at' => $complete ? now() : null, 'updated_at' => now()]);
        });
        return response()->json(['data' => $this->serialize($tenant, $this->find($tenant, $transfer), true)]);
    }

    private function validateDraft(Request $request, bool $partial): array
    {
        $rules = ['sourceWarehouseId' => [$partial ? 'sometimes' : 'required', 'integer'], 'destinationWarehouseId' => [$partial ? 'sometimes' : 'required', 'integer'], 'notes' => ['sometimes', 'nullable', 'string', 'max:4000'], 'lines' => ['sometimes', 'array'], 'lines.*.itemId' => ['required_with:lines', 'integer', 'distinct'], 'lines.*.requestedQuantity' => ['required_with:lines', 'regex:/^\d+(\.\d{1,3})?$/']];
        return $request->validate($rules);
    }

    private function assertWarehouses(int $tenant, int $sourceId, int $destinationId, ?int $actor): void
    {
        if ($sourceId === $destinationId) throw ValidationException::withMessages(['destinationWarehouseId' => 'Source and destination warehouses must be different.']);
        $warehouses = DB::table('warehouses')->where('tenant_id', $tenant)->whereIn('id', [$sourceId, $destinationId])->where('is_active', true)->whereNull('deleted_at')->get()->keyBy('id');
        if ($warehouses->count() !== 2 || WarehousePresentation::isLegacy($warehouses[$sourceId]->code) || WarehousePresentation::isLegacy($warehouses[$destinationId]->code)) throw ValidationException::withMessages(['sourceWarehouseId' => 'Select active warehouses within the current tenant.']);
        FinancialActor::assertBranchAccess($actor, $tenant, $warehouses[$sourceId]->branch_id ? (int) $warehouses[$sourceId]->branch_id : null);
        FinancialActor::assertBranchAccess($actor, $tenant, $warehouses[$destinationId]->branch_id ? (int) $warehouses[$destinationId]->branch_id : null);
    }

    private function find(int $tenant, int $id): object
    {
        $row = DB::table('warehouse_transfers as transfers')->join('warehouses as source', 'source.id', '=', 'transfers.source_warehouse_id')->join('warehouses as destination', 'destination.id', '=', 'transfers.destination_warehouse_id')->leftJoin('branches as source_branch', 'source_branch.id', '=', 'source.branch_id')->leftJoin('branches as destination_branch', 'destination_branch.id', '=', 'destination.branch_id')->where('transfers.tenant_id', $tenant)->where('transfers.id', $id)->select('transfers.*', 'source.name as source_name', 'source.type as source_type', 'source_branch.name as source_branch_name', 'destination.name as destination_name', 'destination.type as destination_type', 'destination_branch.name as destination_branch_name')->first();
        abort_unless($row, 404, 'Transfer not found.');
        return $row;
    }

    private function serialize(int $tenant, object $row, bool $detail): array
    {
        $data = ['id' => (int) $row->id, 'number' => 'TR-'.str_pad((string) $row->id, 4, '0', STR_PAD_LEFT), 'sourceWarehouseId' => (int) $row->source_warehouse_id, 'sourceWarehouseName' => WarehousePresentation::displayName($row->source_branch_name, $row->source_type), 'destinationWarehouseId' => (int) $row->destination_warehouse_id, 'destinationWarehouseName' => WarehousePresentation::displayName($row->destination_branch_name, $row->destination_type), 'status' => $row->status, 'notes' => $row->notes, 'createdAt' => $row->created_at, 'submittedAt' => $row->submitted_at, 'approvedAt' => $row->approved_at, 'dispatchedAt' => $row->dispatched_at, 'receivedAt' => $row->received_at];
        if ($detail) $data['lines'] = DB::table('warehouse_transfer_lines as lines')->join('inventory_items as items', 'items.id', '=', 'lines.inventory_item_id')->leftJoin('stock_balances as balances', fn ($join) => $join->on('balances.inventory_item_id', '=', 'lines.inventory_item_id')->where('balances.tenant_id', $tenant)->where('balances.warehouse_id', $row->source_warehouse_id))->where('lines.warehouse_transfer_id', $row->id)->orderBy('lines.id')->get(['lines.*', 'items.name_ar', 'items.name_en', 'items.sku', 'balances.quantity_on_hand', 'balances.reserved_quantity'])->map(fn (object $line) => ['itemId' => (int) $line->inventory_item_id, 'itemName' => $line->name_ar ?: $line->name_en, 'sku' => $line->sku, 'unit' => $line->unit, 'requestedQuantity' => $line->requested_quantity, 'dispatchedQuantity' => $line->dispatched_quantity, 'receivedQuantity' => $line->received_quantity, 'availableQuantity' => InventoryDecimal::quantity(max(0, InventoryDecimal::units($line->quantity_on_hand ?? '0') - InventoryDecimal::units($line->reserved_quantity ?? '0'))), 'discrepancyQuantity' => InventoryDecimal::quantity(max(0, InventoryDecimal::units($line->dispatched_quantity) - InventoryDecimal::units($line->received_quantity)) )])->values();
        return $data;
    }
}
