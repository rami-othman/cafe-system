<?php

namespace App\Domain\Inventory;

use App\Services\OperationalAuditService;
use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\WarehousePresentation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

final class WarehouseTransferService
{
    public function __construct(private readonly InventoryPostingService $posting, private readonly UnitConversionResolver $conversions, private readonly OperationalAuditService $audit, private readonly TransferTransitLedger $transit) {}

    public function create(Request $request, int $tenant, array $data, ?int $actor): int
    {
        if (($key = $data['idempotencyKey'] ?? null) && ($existing = DB::table('warehouse_transfers')->where('tenant_id', $tenant)->where('idempotency_key', $key)->value('id'))) return (int) $existing;
        return DB::transaction(function () use ($request, $tenant, $data, $actor, $key): int {
            if ($key && ($existing = DB::table('warehouse_transfers')->where('tenant_id', $tenant)->where('idempotency_key', $key)->lockForUpdate()->value('id'))) return (int) $existing;
            [$source, $destination] = $this->warehouses($tenant, (int) $data['sourceWarehouseId'], (int) $data['destinationWarehouseId'], $actor);
            $id = (int) DB::table('warehouse_transfers')->insertGetId(['tenant_id' => $tenant, 'source_warehouse_id' => $source->id, 'destination_warehouse_id' => $destination->id, 'status' => 'draft', 'idempotency_key' => $key, 'notes' => $data['notes'] ?? null, 'created_by' => $actor, 'created_at' => now(), 'updated_at' => now()]);
            $this->replaceLines($tenant, $id, $source->id, $destination->id, $data['lines'] ?? []);
            $this->audit($request, $tenant, 'create', $id, $source->branch_id, $actor); return $id;
        });
    }

    public function update(Request $request, int $tenant, int $id, array $data, ?int $actor): void
    {
        DB::transaction(function () use ($request, $tenant, $id, $data, $actor): void {
            $row = $this->row($tenant, $id, true); $this->status($row, 'draft');
            [$source, $destination] = $this->warehouses($tenant, (int) ($data['sourceWarehouseId'] ?? $row->source_warehouse_id), (int) ($data['destinationWarehouseId'] ?? $row->destination_warehouse_id), $actor);
            DB::table('warehouse_transfers')->where('id', $id)->update(['source_warehouse_id' => $source->id, 'destination_warehouse_id' => $destination->id, 'notes' => array_key_exists('notes', $data) ? $data['notes'] : $row->notes, 'updated_at' => now()]);
            if (array_key_exists('lines', $data)) $this->replaceLines($tenant, $id, $source->id, $destination->id, $data['lines']);
            $this->audit($request, $tenant, 'update', $id, $source->branch_id, $actor);
        });
    }

    public function action(Request $request, int $tenant, int $id, string $action, array $data, ?int $actor): void
    {
        DB::transaction(function () use ($request, $tenant, $id, $action, $data, $actor): void {
            $row = $this->row($tenant, $id, true); [$source, $destination] = $this->warehouses($tenant, (int) $row->source_warehouse_id, (int) $row->destination_warehouse_id, $actor);
            if ($this->operationExists($tenant, $id, $action, $data['idempotencyKey'] ?? null)) return;
            if ($action === 'submit') {
                $this->status($row, 'draft'); if (!DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $id)->exists()) throw ValidationException::withMessages(['lines' => 'Add at least one line before submitting.']);
                $changes = ['status' => 'submitted', 'submitted_by' => $actor, 'submitted_at' => now()];
            } elseif ($action === 'approve') {
                $this->status($row, 'submitted'); foreach ($this->lines($id, true) as $line) { $this->posting->adjustReservation($tenant, $source->id, $line->inventory_item_id, InventoryDecimal::units($line->requested_base_quantity)); DB::table('warehouse_transfer_lines')->where('id', $line->id)->update(['reserved_quantity' => $line->requested_base_quantity, 'updated_at' => now()]); }
                $changes = ['status' => 'approved', 'approved_by' => $actor, 'approved_at' => now()];
            } elseif ($action === 'reject') {
                $this->status($row, 'submitted'); $reason = $this->reason($data, 'rejectionReason'); $changes = ['status' => 'rejected', 'rejection_reason' => $reason, 'rejected_by' => $actor, 'rejected_at' => now()];
            } elseif ($action === 'cancel') {
                if (!in_array($row->status, ['draft', 'submitted', 'approved'], true)) throw ValidationException::withMessages(['status' => 'This transfer cannot be cancelled.']);
                if ($row->status === 'approved') $this->release($tenant, $source->id, $id); $reason = $this->reason($data, 'cancellationReason'); $changes = ['status' => 'cancelled', 'cancelled_by' => $actor, 'cancelled_at' => now(), 'cancellation_reason' => $reason];
            } elseif ($action === 'dispatch') {
                $this->status($row, 'approved'); foreach ($this->lines($id, true) as $line) {
                    $reserved = InventoryDecimal::units($line->reserved_quantity); $requested = InventoryDecimal::units($line->requested_base_quantity);
                    if ($reserved !== $requested) throw ValidationException::withMessages(['lines' => 'The approved reservation is incomplete.']);
                    $movement = $this->posting->post($request, $tenant, ['warehouseId' => $source->id, 'branchId' => $source->branch_id, 'itemId' => $line->inventory_item_id, 'type' => 'transfer_out', 'quantity' => InventoryDecimal::quantity($requested), 'unit' => $this->baseUnit($tenant, $line->inventory_item_id), 'consumeReservation' => true, 'reason' => 'Warehouse transfer dispatch', 'referenceType' => 'warehouse_transfer', 'referenceId' => $id, 'idempotencyKey' => "transfer-$id-dispatch-line-$line->id"], $actor);
                    $this->transit->dispatch($tenant, $row, $line, $requested, $actor);
                    $this->posting->adjustReservation($tenant, $source->id, $line->inventory_item_id, -$reserved);
                    DB::table('warehouse_transfer_lines')->where('id', $line->id)->update(['dispatched_quantity' => InventoryDecimal::quantity($requested), 'dispatched_base_quantity' => InventoryDecimal::quantity($requested), 'reserved_quantity' => '0.000', 'transfer_out_movement_id' => $movement->movementId, 'updated_at' => now()]);
                }
                $changes = ['status' => 'dispatched', 'dispatched_by' => $actor, 'dispatched_at' => now()];
            } elseif ($action === 'close_shortage') {
                if (!in_array($row->status, ['dispatched', 'partially_received'], true)) throw ValidationException::withMessages(['status' => 'Only a dispatched transfer with an outstanding quantity can be closed short.']);
                $reason = $this->reason($data, 'discrepancyReason'); foreach ($this->lines($id, true) as $line) { $remaining = InventoryDecimal::units($line->dispatched_base_quantity) - InventoryDecimal::units($line->received_base_quantity); if ($remaining > 0) { $this->transit->shortage($tenant, $row, $line, $remaining, $reason, $actor); DB::table('warehouse_transfer_lines')->where('id', $line->id)->update(['shortage_closed_quantity' => InventoryDecimal::quantity($remaining), 'discrepancy_reason' => $reason, 'updated_at' => now()]); } }
                $changes = ['status' => 'closed_shortage', 'shortage_reason' => $reason, 'closed_by' => $actor, 'closed_at' => now()];
            } else throw ValidationException::withMessages(['action' => 'Unsupported transfer action.']);
            DB::table('warehouse_transfers')->where('id', $id)->update($changes + ['updated_at' => now()]); $this->recordOperation($tenant, $id, $action, $data['idempotencyKey'], $actor); $this->audit($request, $tenant, $action, $id, $source->branch_id, $actor);
        });
    }

    public function receive(Request $request, int $tenant, int $id, array $data, ?int $actor): void
    {
        DB::transaction(function () use ($request, $tenant, $id, $data, $actor): void {
            $row = $this->row($tenant, $id, true); if (DB::table('warehouse_transfer_receipts')->where('warehouse_transfer_id', $id)->where('idempotency_key', $data['idempotencyKey'])->exists()) return; if (!in_array($row->status, ['dispatched', 'partially_received'], true)) throw ValidationException::withMessages(['status' => 'This transfer is not ready to receive.']);
            [$source, $destination] = $this->warehouses($tenant, (int) $row->source_warehouse_id, (int) $row->destination_warehouse_id, $actor);
            $receiptId = (int) DB::table('warehouse_transfer_receipts')->insertGetId(['tenant_id' => $tenant, 'warehouse_transfer_id' => $id, 'idempotency_key' => $data['idempotencyKey'], 'received_by' => $actor, 'created_at' => now(), 'updated_at' => now()]);
            foreach ($data['lines'] as $input) {
                $line = DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $id)->where('inventory_item_id', $input['itemId'])->lockForUpdate()->first(); if (!$line) throw ValidationException::withMessages(['lines' => 'The received item is not part of this transfer.']);
                $item = $this->item($tenant, $line->inventory_item_id, $source->id, $destination->id); $converted = $this->conversions->resolve($tenant, $item, $input['receivedQuantity'], $input['unit'] ?? $line->unit);
                $remaining = InventoryDecimal::units($line->dispatched_base_quantity) - InventoryDecimal::units($line->received_base_quantity); if ($converted['baseQuantity'] <= 0 || $converted['baseQuantity'] > $remaining) throw ValidationException::withMessages(['lines' => 'Received quantity must not exceed the quantity in transit.']);
                $short = $converted['baseQuantity'] < $remaining; $reason = trim((string) ($input['discrepancyReason'] ?? '')); if ($short && $reason === '') throw ValidationException::withMessages(['discrepancyReason' => 'A discrepancy reason is required when receiving less than the remaining quantity.']);
                $movement = $this->posting->post($request, $tenant, ['warehouseId' => $destination->id, 'branchId' => $destination->branch_id, 'itemId' => $line->inventory_item_id, 'type' => 'transfer_in', 'quantity' => $input['receivedQuantity'], 'unit' => $converted['inputUnit'], 'unitCost' => $line->unit_cost, 'reason' => $short ? $reason : 'Warehouse transfer receipt', 'referenceType' => 'warehouse_transfer_receipt', 'referenceId' => $receiptId, 'idempotencyKey' => "transfer-$id-receipt-$receiptId-line-$line->id"], $actor);
                $this->transit->receipt($tenant, $row, $line, $converted['baseQuantity'], $actor, $receiptId);
                $received = InventoryDecimal::units($line->received_base_quantity) + $converted['baseQuantity']; DB::table('warehouse_transfer_receipt_lines')->insert(['tenant_id' => $tenant, 'warehouse_transfer_receipt_id' => $receiptId, 'warehouse_transfer_line_id' => $line->id, 'entered_quantity' => InventoryDecimal::quantity(InventoryDecimal::units($input['receivedQuantity'])), 'entered_unit' => $converted['inputUnit'], 'conversion_factor' => InventoryDecimal::conversionFactor($converted['factor']), 'base_quantity' => InventoryDecimal::quantity($converted['baseQuantity']), 'stock_movement_id' => $movement->movementId, 'discrepancy_reason' => $reason ?: null, 'created_at' => now(), 'updated_at' => now()]);
                DB::table('warehouse_transfer_lines')->where('id', $line->id)->update(['received_quantity' => InventoryDecimal::quantity($received), 'received_base_quantity' => InventoryDecimal::quantity($received), 'transfer_in_movement_id' => $movement->movementId, 'discrepancy_reason' => $reason ?: $line->discrepancy_reason, 'updated_at' => now()]);
            }
            $complete = !DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $id)->whereColumn('received_base_quantity', '<', 'dispatched_base_quantity')->exists(); DB::table('warehouse_transfers')->where('id', $id)->update(['status' => $complete ? 'received' : 'partially_received', 'received_by' => $actor, 'received_at' => $complete ? now() : null, 'updated_at' => now()]); $this->audit($request, $tenant, 'receive', $id, $destination->branch_id, $actor);
        });
    }

    private function replaceLines(int $tenant, int $transfer, int $source, int $destination, array $lines): void { DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id', $transfer)->delete(); foreach ($lines as $line) { $item = $this->item($tenant, $line['itemId'], $source, $destination); $resolved = $this->conversions->resolve($tenant, $item, $line['requestedQuantity'], $line['unit'] ?? null); if ($resolved['baseQuantity'] <= 0) throw ValidationException::withMessages(['lines' => 'Requested quantity must be greater than zero.']); DB::table('warehouse_transfer_lines')->insert(['tenant_id'=>$tenant,'warehouse_transfer_id'=>$transfer,'inventory_item_id'=>$item->id,'unit'=>$resolved['inputUnit'],'requested_quantity'=>InventoryDecimal::quantity($resolved['baseQuantity']),'requested_base_quantity'=>InventoryDecimal::quantity($resolved['baseQuantity']),'requested_conversion_factor'=>InventoryDecimal::conversionFactor($resolved['factor']),'unit_cost'=>InventoryDecimal::unitCost(InventoryDecimal::cost($item->latest_unit_cost)),'created_at'=>now(),'updated_at'=>now()]); } }
    private function warehouses(int $tenant, int $source, int $destination, ?int $actor): array { if ($source === $destination) throw ValidationException::withMessages(['destinationWarehouseId'=>'Source and destination warehouses must differ.']); $rows=DB::table('warehouses')->where('tenant_id',$tenant)->whereIn('id',[$source,$destination])->where('is_active',true)->whereNull('deleted_at')->get()->keyBy('id'); if($rows->count()!==2||WarehousePresentation::isLegacy($rows[$source]->code)||WarehousePresentation::isLegacy($rows[$destination]->code)) throw ValidationException::withMessages(['sourceWarehouseId'=>'Select active current-tenant warehouses.']); FinancialActor::assertBranchAccess($actor,$tenant,$rows[$source]->branch_id?(int)$rows[$source]->branch_id:null); FinancialActor::assertBranchAccess($actor,$tenant,$rows[$destination]->branch_id?(int)$rows[$destination]->branch_id:null); return [$rows[$source],$rows[$destination]]; }
    private function item(int $tenant,int $id,int $source,int $destination): object { $item=DB::table('inventory_items')->where('tenant_id',$tenant)->where('id',$id)->where('is_active',true)->whereNull('deleted_at')->first(); if(!$item) throw ValidationException::withMessages(['lines'=>'A transfer item is inactive or unavailable.']); if(Schema::hasTable('inventory_item_warehouses') && (!DB::table('inventory_item_warehouses')->where('tenant_id',$tenant)->where('inventory_item_id',$id)->where('warehouse_id',$source)->exists() || !DB::table('inventory_item_warehouses')->where('tenant_id',$tenant)->where('inventory_item_id',$id)->where('warehouse_id',$destination)->exists())) throw ValidationException::withMessages(['lines'=>'Each item must be assigned to both source and destination warehouses.']); return $item; }
    private function release(int $tenant,int $warehouse,int $id): void { foreach($this->lines($id,true) as $line){$amount=InventoryDecimal::units($line->reserved_quantity);if($amount>0){$this->posting->adjustReservation($tenant,$warehouse,$line->inventory_item_id,-$amount);DB::table('warehouse_transfer_lines')->where('id',$line->id)->update(['reserved_quantity'=>'0.000','updated_at'=>now()]);}} }
    private function operationExists(int $tenant,int $id,string $operation,?string $key): bool { return $key !== null && DB::table('warehouse_transfer_operations')->where('tenant_id',$tenant)->where('warehouse_transfer_id',$id)->where('operation',$operation)->where('idempotency_key',$key)->exists(); }
    private function recordOperation(int $tenant,int $id,string $operation,string $key,?int $actor): void { DB::table('warehouse_transfer_operations')->insert(['tenant_id'=>$tenant,'warehouse_transfer_id'=>$id,'operation'=>$operation,'idempotency_key'=>$key,'created_by'=>$actor,'created_at'=>now(),'updated_at'=>now()]); }
    private function reason(array $data,string $field): string { $value=trim((string)($data[$field]??''));if($value==='')throw ValidationException::withMessages([$field=>'A reason is required.']);return $value; }
    private function row(int $tenant,int $id,bool $lock=false): object {$q=DB::table('warehouse_transfers')->where('tenant_id',$tenant)->where('id',$id);if($lock)$q->lockForUpdate();$row=$q->first();abort_unless($row,404,'Transfer not found.');return $row;} private function lines(int $id,bool $lock=false){$q=DB::table('warehouse_transfer_lines')->where('warehouse_transfer_id',$id);if($lock)$q->lockForUpdate();return $q->get();} private function status(object $row,string $status):void{if($row->status!==$status)throw ValidationException::withMessages(['status'=>'The current transfer status does not permit this action.']);} private function baseUnit(int $tenant,int $item):string{return (string)DB::table('inventory_items')->where('tenant_id',$tenant)->where('id',$item)->value('unit');} private function audit(Request $r,int $tenant,string $action,int $id,?int $branch,?int $actor):void{$this->audit->record($r,$tenant,'warehouse_transfer.'.$action,'warehouse_transfer',$id,[],['status'=>$action],$branch?(int)$branch:null,$actor);}
}
