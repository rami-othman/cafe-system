<?php

namespace App\Services;

use App\Domain\Inventory\InventoryPostingService;
use App\Domain\Inventory\UnitConversionResolver;
use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\WarehousePresentation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class StockCountService
{
    public function __construct(
        private readonly InventoryPostingService $posting,
        private readonly UnitConversionResolver $conversions,
        private readonly OperationalAuditService $audit,
    ) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        $warehouse = $this->warehouse($tenantId, (int) $data['warehouseId']);
        FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);

        return DB::transaction(function () use ($tenantId, $warehouse, $data, $actorId): int {
            $categories = array_values(array_filter($data['categoryFilters'] ?? [], fn ($value) => is_string($value) && $value !== ''));
            $countType = $data['countType'] ?? 'full';
            if ($countType === 'cycle' && $categories === []) {
                throw ValidationException::withMessages(['categoryFilters' => 'Choose at least one category for a cycle count.']);
            }
            DB::table('warehouses')->where('id', $warehouse->id)->lockForUpdate()->first();
            if (DB::table('stock_counts')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouse->id)
                ->whereDate('count_date', $data['countDate'])->where('count_type', $countType)
                ->whereIn('status', ['draft', 'in_progress', 'submitted', 'approved'])->exists()) {
                throw ValidationException::withMessages(['warehouseId' => 'An active count of this type already exists for this warehouse and date.']);
            }
            $countId = (int) DB::table('stock_counts')->insertGetId([
                'tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'branch_id' => $warehouse->branch_id,
                'count_date' => $data['countDate'], 'count_type' => $countType,
                'category_filters' => $categories === [] ? null : json_encode($categories), 'status' => 'draft',
                'notes' => $data['notes'] ?? null, 'counted_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
            ]);
            $items = DB::table('inventory_items as items')
                ->leftJoin('stock_balances as balances', function ($join) use ($tenantId, $warehouse): void {
                    $join->on('balances.inventory_item_id', '=', 'items.id')->where('balances.tenant_id', $tenantId)->where('balances.warehouse_id', $warehouse->id);
                })->where('items.tenant_id', $tenantId)->where('items.is_active', true)->whereNull('items.deleted_at')
                ->whereNotIn('items.item_type', ['non_stock_item', 'service'])->when($categories !== [], fn ($query) => $query->whereIn('items.category', $categories))
                ->when(Schema::hasTable('inventory_item_warehouses'), fn ($query) => $query->whereExists(fn ($assigned) => $assigned->selectRaw('1')->from('inventory_item_warehouses as availability')->whereColumn('availability.inventory_item_id', 'items.id')->where('availability.tenant_id', $tenantId)->where('availability.warehouse_id', $warehouse->id)))
                ->orderBy('items.name_en')->get(['items.id', 'items.unit', 'balances.quantity_on_hand', 'balances.average_unit_cost']);
            $this->insertLines($tenantId, $countId, $items, fn (object $item) => ['is_required' => true, 'entered_unit' => $item->unit, 'tolerance_type' => 'quantity', 'quantity_tolerance' => '0.000', 'manager_review_threshold' => null, 'requires_review_when_exceeded' => false]);
            return $countId;
        });
    }

    public function startBarCheck(Request $request, int $tenantId, int $shiftId, int $warehouseId, ?int $actorId): int
    {
        return DB::transaction(function () use ($tenantId, $shiftId, $warehouseId, $actorId): int {
            $shift = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shiftId)->where('status', 'open')->whereNull('deleted_at')->lockForUpdate()->first();
            abort_unless($shift, 422, 'There is no valid open shift for this bar check.');
            $warehouse = $this->warehouse($tenantId, $warehouseId);
            if ((int) $warehouse->branch_id !== (int) $shift->branch_id) throw ValidationException::withMessages(['warehouseId' => 'The warehouse must belong to the shift branch.']);
            FinancialActor::assertBranchAccess($actorId, $tenantId, (int) $shift->branch_id);
            $template = DB::table('bar_check_templates')->where('tenant_id', $tenantId)->where('branch_id', $shift->branch_id)->where('warehouse_id', $warehouseId)->where('is_active', true)->lockForUpdate()->first();
            abort_unless($template, 422, 'No active bar check template exists for this warehouse.');
            $templateLines = DB::table('bar_check_template_lines as lines')->join('inventory_items as items', 'items.id', '=', 'lines.inventory_item_id')
                ->where('lines.tenant_id', $tenantId)->where('lines.bar_check_template_id', $template->id)->where('items.is_active', true)->whereNull('items.deleted_at')->orderBy('lines.sort_order')->get(['lines.*']);
            if ($templateLines->isEmpty()) throw ValidationException::withMessages(['template' => 'An active bar check template must contain at least one valid line.']);
            $existing = DB::table('stock_counts')->where('tenant_id', $tenantId)->where('shift_id', $shift->id)->where('warehouse_id', $warehouseId)->where('count_type', 'shift_check')->lockForUpdate()->first();
            if ($existing) return (int) $existing->id;
            $id = (int) DB::table('stock_counts')->insertGetId(['tenant_id' => $tenantId, 'warehouse_id' => $warehouseId, 'branch_id' => $shift->branch_id, 'shift_id' => $shift->id, 'bar_check_template_id' => $template->id, 'count_date' => now()->toDateString(), 'count_type' => 'shift_check', 'status' => 'in_progress', 'counted_by' => $actorId, 'created_at' => now(), 'updated_at' => now()]);
            $items = $templateLines->map(function (object $line) use ($tenantId, $warehouseId): object {
                $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $line->inventory_item_id)->first();
                $this->assertItemAssigned($tenantId, $warehouseId, $item, 'lines');
                $conversion = $this->conversions->resolve($tenantId, $item, '1.000', $line->count_unit);
                $balance = DB::table('stock_balances')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $item->id)->first();
                $line->quantity_on_hand = $balance->quantity_on_hand ?? '0.000'; $line->average_unit_cost = $balance->average_unit_cost ?? '0.0000'; $line->conversion_factor_snapshot = $conversion['factor'];
                return $line;
            });
            $this->insertLines($tenantId, $id, $items, fn (object $line) => ['is_required' => (bool) $line->is_required, 'entered_unit' => $line->count_unit, 'conversion_factor' => InventoryDecimal::conversionFactor($line->conversion_factor_snapshot), 'tolerance_type' => $line->tolerance_type ?? 'quantity', 'quantity_tolerance' => $line->quantity_tolerance, 'manager_review_threshold' => $line->manager_review_threshold, 'requires_review_when_exceeded' => (bool) ($line->requires_review_when_exceeded ?? false)]);
            return $id;
        });
    }

    public function upsertLine(int $tenantId, int $countId, array $data, ?int $actorId): void
    {
        DB::transaction(function () use ($tenantId, $countId, $data, $actorId): void {
            $count = $this->find($tenantId, $countId, true); $this->assertEditable($count);
            $warehouse = $this->warehouse($tenantId, (int) $count->warehouse_id); FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouse->branch_id ? (int) $warehouse->branch_id : null);
            $line = DB::table('stock_count_lines')->where('tenant_id', $tenantId)->where('stock_count_id', $countId)->where('inventory_item_id', $data['itemId'])->lockForUpdate()->first(); abort_unless($line, 404, 'The item is not part of this count.');
            $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $line->inventory_item_id)->where('is_active', true)->whereNull('deleted_at')->first(); abort_unless($item, 422, 'The inventory item is no longer active.');
            $entered = InventoryDecimal::units($data['countedQuantity'], 'countedQuantity');
            $converted = $this->conversions->resolve($tenantId, $item, $data['countedQuantity'], $data['unit'] ?? $line->entered_unit ?? $item->unit);
            $expected = InventoryDecimal::units($line->expected_quantity); $variance = $converted['baseQuantity'] - $expected; $status = $this->varianceStatus($line, $expected, $variance);
            $reason = array_key_exists('reason', $data) ? trim((string) ($data['reason'] ?? '')) : $line->reason;
            DB::table('stock_count_lines')->where('id', $line->id)->update(['counted_quantity' => InventoryDecimal::quantity($converted['baseQuantity']), 'entered_quantity' => InventoryDecimal::quantity($entered), 'entered_unit' => $converted['inputUnit'], 'conversion_factor' => InventoryDecimal::conversionFactor($converted['factor']), 'base_quantity' => InventoryDecimal::quantity($converted['baseQuantity']), 'variance_quantity' => InventoryDecimal::quantity($variance), 'variance_status' => $status, 'reason' => $reason === '' ? null : $reason, 'reason_entered_by' => $reason === '' ? null : $actorId, 'is_counted' => true, 'counted_at' => now(), 'manager_review_status' => null, 'manager_reviewed_by' => null, 'manager_reviewed_at' => null, 'manager_review_notes' => null, 'updated_at' => now()]);
        });
    }

    public function reviewLine(Request $request, int $tenantId, int $countId, int $itemId, array $data, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $countId, $itemId, $data, $actorId): void {
            $count = $this->find($tenantId, $countId, true); $this->requireStatus($count, 'submitted');
            if (! $actorId) throw ValidationException::withMessages(['managerReview' => 'A manager actor is required for this review.']);
            FinancialActor::assertBranchAccess($actorId, $tenantId, $count->branch_id ? (int) $count->branch_id : null);
            $line = DB::table('stock_count_lines')->where('tenant_id', $tenantId)->where('stock_count_id', $countId)->where('inventory_item_id', $itemId)->lockForUpdate()->first(); abort_unless($line, 404, 'Count line not found.');
            if ($line->variance_status !== 'needs_manager_review') throw ValidationException::withMessages(['line' => 'This line does not require manager review.']);
            DB::table('stock_count_lines')->where('id', $line->id)->update(['manager_review_status' => $data['decision'], 'manager_reviewed_by' => $actorId, 'manager_reviewed_at' => now(), 'manager_review_notes' => $data['notes'] ?? null, 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'stock_count.manager_review', 'stock_count_line', $line->id, [], ['decision' => $data['decision']], $count->branch_id, $actorId);
        });
    }

    public function transition(Request $request, int $tenantId, int $countId, string $action, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $countId, $action, $actorId): void {
            $count = $this->find($tenantId, $countId, true); $warehouseBranchId = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $count->warehouse_id)->value('branch_id'); FinancialActor::assertBranchAccess($actorId, $tenantId, $warehouseBranchId ? (int) $warehouseBranchId : null);
            if ($action === 'start') { $this->requireStatus($count, 'draft'); $changes = ['status' => 'in_progress']; }
            elseif ($action === 'submit') {
                $this->requireStatus($count, 'in_progress');
                if (DB::table('stock_count_lines')->where('stock_count_id', $countId)->where('is_required', true)->where('is_counted', false)->exists()) throw ValidationException::withMessages(['lines' => 'Every required count line must be counted before submission.']);
                if (DB::table('stock_count_lines')->where('stock_count_id', $countId)->where('is_counted', true)->whereIn('variance_status', ['needs_reason', 'needs_manager_review'])->where(fn ($q) => $q->whereNull('reason')->orWhereRaw("TRIM(reason) = ''"))->exists()) throw ValidationException::withMessages(['reason' => 'A reason is required for every variance outside tolerance.']);
                $changes = ['status' => 'submitted', 'submitted_at' => now(), 'counted_by' => $actorId];
            } elseif ($action === 'approve') {
                $this->requireStatus($count, 'submitted');
                if (DB::table('stock_count_lines')->where('stock_count_id', $countId)->where('variance_status', 'needs_manager_review')->where(fn ($q) => $q->whereNull('manager_review_status')->orWhere('manager_review_status', '!=', 'approved'))->exists()) throw ValidationException::withMessages(['managerReview' => 'All manager-review variances must be approved before approval.']);
                $changes = ['status' => 'approved', 'approved_at' => now(), 'approved_by' => $actorId];
            } elseif ($action === 'cancel') {
                if (in_array($count->status, ['posted', 'cancelled'], true)) throw ValidationException::withMessages(['status' => 'A posted or cancelled count cannot be cancelled.']); $changes = ['status' => 'cancelled', 'cancelled_at' => now()];
            } elseif ($action === 'post') {
                $this->requireStatus($count, 'approved'); $lines = DB::table('stock_count_lines')->where('stock_count_id', $countId)->lockForUpdate()->get();
                foreach ($lines as $line) {
                    if (! $line->is_counted) continue;
                    if ($line->variance_status === 'needs_manager_review' && $line->manager_review_status !== 'approved') throw ValidationException::withMessages(['managerReview' => 'A required manager review is still pending.']);
                    $variance = InventoryDecimal::signedUnits($line->variance_quantity); if ($variance === 0) continue;
                    $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $line->inventory_item_id)->first();
                    $this->posting->post($request, $tenantId, ['warehouseId' => $count->warehouse_id, 'branchId' => $count->branch_id ?: $warehouseBranchId, 'itemId' => $line->inventory_item_id, 'type' => 'stock_count_variance', 'countDirection' => $variance > 0 ? 'in' : 'out', 'quantity' => InventoryDecimal::quantity(abs($variance)), 'unit' => $item->unit, 'reason' => $line->reason ?: 'Stock count variance', 'referenceType' => 'stock_count', 'referenceId' => $countId, 'idempotencyKey' => 'stock-count-'.$countId.'-line-'.$line->id, 'occurredAt' => now()], $actorId);
                }
                $changes = ['status' => 'posted', 'posted_at' => now()];
            } else throw ValidationException::withMessages(['action' => 'Unsupported count action.']);
            DB::table('stock_counts')->where('id', $countId)->update($changes + ['updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'stock_count.'.$action, 'stock_count', $countId, ['status' => $count->status], $changes, $warehouseBranchId ? (int) $warehouseBranchId : null, $actorId);
        });
    }

    public function find(int $tenantId, int $countId, bool $lock = false): object { $query = DB::table('stock_counts')->where('tenant_id', $tenantId)->where('id', $countId); if ($lock) $query->lockForUpdate(); $count = $query->first(); abort_unless($count, 404, 'Stock count not found.'); return $count; }

    private function insertLines(int $tenantId, int $countId, iterable $items, callable $extras): void
    {
        $now = now(); $rows = [];
        foreach ($items as $item) { $extra = $extras($item); $rows[] = ['tenant_id' => $tenantId, 'stock_count_id' => $countId, 'inventory_item_id' => $item->inventory_item_id ?? $item->id, 'is_required' => $extra['is_required'], 'is_counted' => false, 'expected_quantity' => InventoryDecimal::quantity(InventoryDecimal::units($item->quantity_on_hand ?? '0')), 'counted_quantity' => '0.000', 'entered_quantity' => null, 'entered_unit' => $extra['entered_unit'], 'conversion_factor' => $extra['conversion_factor'] ?? null, 'base_quantity' => null, 'variance_quantity' => '0.000', 'quantity_tolerance' => InventoryDecimal::quantity(InventoryDecimal::units($extra['quantity_tolerance'] ?? '0')), 'tolerance_type' => $extra['tolerance_type'], 'manager_review_threshold' => $extra['manager_review_threshold'], 'requires_review_when_exceeded' => $extra['requires_review_when_exceeded'], 'variance_status' => null, 'average_unit_cost' => InventoryDecimal::unitCost(InventoryDecimal::cost($item->average_unit_cost ?? '0')), 'created_at' => $now, 'updated_at' => $now]; }
        if ($rows !== []) DB::table('stock_count_lines')->insert($rows);
    }

    private function varianceStatus(object $line, int $expected, int $variance): string
    {
        $absolute = abs($variance); $tolerance = InventoryDecimal::units($line->quantity_tolerance ?? '0'); $percentage = ($line->tolerance_type ?? 'quantity') === 'percentage';
        $within = $percentage ? ($expected === 0 ? $absolute === 0 : $absolute * 100000 <= $expected * $tolerance) : $absolute <= $tolerance;
        if ($within) return 'within_tolerance';
        $threshold = $line->manager_review_threshold === null ? null : InventoryDecimal::units($line->manager_review_threshold);
        $thresholdExceeded = $threshold !== null && ($percentage ? ($expected === 0 ? $absolute > 0 : $absolute * 100000 > $expected * $threshold) : $absolute > $threshold);
        return ((bool) ($line->requires_review_when_exceeded ?? false) || $thresholdExceeded) ? 'needs_manager_review' : 'needs_reason';
    }

    private function assertItemAssigned(int $tenantId, int $warehouseId, ?object $item, string $field): void
    {
        if (! $item || ! $item->is_active || $item->deleted_at !== null) throw ValidationException::withMessages([$field => 'The template contains an inactive inventory item.']);
        if (Schema::hasTable('inventory_item_warehouses') && ! DB::table('inventory_item_warehouses')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $item->id)->exists()) throw ValidationException::withMessages([$field => 'Every template item must be assigned to its bar warehouse.']);
    }

    private function warehouse(int $tenantId, int $warehouseId): object { $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->where('is_active', true)->whereNull('deleted_at')->first(); abort_unless($warehouse, 404, 'Warehouse not found.'); if (WarehousePresentation::isLegacy($warehouse->code)) throw ValidationException::withMessages(['warehouseId' => 'Legacy warehouses are read-only and cannot be counted.']); return $warehouse; }
    private function assertEditable(object $count): void { if (! in_array($count->status, ['draft', 'in_progress'], true)) throw ValidationException::withMessages(['status' => 'Count lines cannot be edited after submission.']); }
    private function requireStatus(object $count, string $status): void { if ($count->status !== $status) throw ValidationException::withMessages(['status' => 'The current count status does not permit this action.']); }
}
