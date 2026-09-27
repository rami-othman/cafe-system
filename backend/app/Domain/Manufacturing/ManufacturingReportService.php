<?php

namespace App\Domain\Manufacturing;

use Illuminate\Support\Facades\DB;

/** Overview + Reports. Reuses inventory_items.reorder_level/minimum_stock for
 * "materials needing attention" — the same definition InventoryBalanceController
 * uses (quantity_on_hand <= reorder_level) — rather than a second low-stock engine. */
final class ManufacturingReportService
{
    public function overview(int $tenantId, ?int $warehouseId, array $branchIds = []): array
    {
        $today = now()->toDateString();
        $orders = DB::table('manufacturing_orders')->where('tenant_id', $tenantId)->whereIn('branch_id', $branchIds)->when($warehouseId, fn ($q) => $q->where('warehouse_id', $warehouseId));
        $todays = (clone $orders)->where('status', 'completed')->whereDate('production_date', $today)->get();

        $producedToday = (float) $todays->sum('actual_quantity');
        $costToday = (float) $todays->sum('actual_material_cost');
        $effs = $todays->filter(fn ($o) => (float) $o->planned_quantity > 0)->map(fn ($o) => (float) $o->actual_quantity / (float) $o->planned_quantity * 100);
        $avgEff = $effs->isNotEmpty() ? round($effs->avg(), 1) : null;
        $wasteToday = $todays->whereNotNull('waste_quantity')->count();

        $balanceQuery = DB::table('stock_balances as b')->join('inventory_items as i', 'i.id', '=', 'b.inventory_item_id')
            ->where('b.tenant_id', $tenantId)->where('i.is_active', true)->whereNull('i.deleted_at')
            ->whereIn('i.owner_branch_id', $branchIds)
            ->whereIn('i.item_type', ['raw_material', 'packaging', 'semi_finished_good'])
            ->whereColumn('b.quantity_on_hand', '<=', 'i.reorder_level');
        if ($warehouseId) {
            $balanceQuery->where('b.warehouse_id', $warehouseId);
        }
        $attention = $balanceQuery->select('i.name_ar', 'i.name_en', 'i.unit', 'b.quantity_on_hand', 'i.reorder_level')->limit(10)->get()
            ->map(fn ($r) => ['name' => $r->name_ar ?: $r->name_en, 'available' => $r->quantity_on_hand.' '.$r->unit, 'need' => 'الحد الأدنى '.$r->reorder_level.' '.$r->unit, 'status' => 'مخزون منخفض', 'level' => 'warning'])->all();

        $recent = (clone $orders)->orderByDesc('created_at')->limit(6)->get()->map(fn ($o) => $this->summarizeOrder($o))->all();

        $expiring = DB::table('manufacturing_batches as b')
            ->join('manufacturing_orders as o', 'o.id', '=', 'b.manufacturing_order_id')
            ->join('inventory_items as i', 'i.id', '=', 'b.inventory_item_id')
            ->where('b.tenant_id', $tenantId)->where('o.tenant_id', $tenantId)
            ->whereIn('o.branch_id', $branchIds)
            ->where('o.status', 'completed')->where('b.remaining_quantity', '>', 0)
            ->whereNotNull('b.expiry_date')->whereDate('b.expiry_date', '>=', $today)
            ->when($warehouseId, fn ($q) => $q->where('b.warehouse_id', $warehouseId))
            ->orderBy('b.expiry_date')->limit(4)
            ->select('o.reference', 'o.id', 'b.expiry_date', 'b.remaining_quantity', 'o.planned_unit', 'i.name_ar', 'i.name_en')->get()
            ->map(fn ($r) => ['id' => $r->reference ?: (string) $r->id, 'product' => $r->name_ar ?: $r->name_en, 'batch' => $r->reference, 'remaining' => $r->remaining_quantity.' '.$r->planned_unit, 'date' => $r->expiry_date])->all();

        $topCost = $todays->groupBy('output_item_id')->map(function ($group) {
            $item = DB::table('inventory_items')->where('id', $group->first()->output_item_id)->first();

            return ['product' => $item->name_ar ?: $item->name_en, 'cost' => (float) $group->sum('actual_material_cost')];
        })->sortByDesc('cost')->take(3)->values();
        $max = $topCost->max('cost') ?: 1;

        return [
            'kpis' => ['producedToday' => $producedToday, 'productionCostToday' => $costToday, 'avgEfficiency' => $avgEff, 'wasteToday' => $wasteToday, 'attentionCount' => count($attention), 'expiringCount' => count($expiring)],
            'recent' => $recent, 'attention' => $attention, 'expiring' => $expiring,
            'topCost' => $topCost->map(fn ($t) => $t + ['pct' => (int) round($t['cost'] / $max * 100)])->all(),
        ];
    }

    public function reports(int $tenantId, ?int $warehouseId, ?string $type, ?string $dateFrom, ?string $dateTo, array $branchIds = []): array
    {
        $query = DB::table('manufacturing_orders as o')->join('inventory_items as i', 'i.id', '=', 'o.output_item_id')
            ->where('o.tenant_id', $tenantId)->where('o.status', 'completed');
        $query->whereIn('o.branch_id', $branchIds);
        if ($warehouseId) {
            $query->where('o.warehouse_id', $warehouseId);
        }
        if ($type && $type !== 'all') {
            $query->where('i.item_type', $type);
        }
        if ($dateFrom) {
            $query->whereDate('o.production_date', '>=', $dateFrom);
        }
        if ($dateTo) {
            $query->whereDate('o.production_date', '<=', $dateTo);
        }
        $rows = $query->select('o.*', 'i.name_ar', 'i.name_en')->get();

        $totalQty = (float) $rows->sum('actual_quantity');
        $totalCost = (float) $rows->sum('actual_material_cost');
        $effs = $rows->filter(fn ($o) => (float) $o->planned_quantity > 0)->map(fn ($o) => (float) $o->actual_quantity / (float) $o->planned_quantity * 100);
        $wasteRows = $rows->whereNotNull('waste_quantity');

        $byProduct = $rows->groupBy('output_item_id')->map(function ($group) {
            $item = DB::table('inventory_items')->where('id', $group->first()->output_item_id)->first();

            return ['product' => $item->name_ar ?: $item->name_en, 'qty' => (float) $group->sum('actual_quantity'), 'cost' => (float) $group->sum('actual_material_cost')];
        })->sortByDesc('cost')->values();

        $byWarehouse = $rows->groupBy('warehouse_id')->map(function ($group, $warehouseId) {
            $w = DB::table('warehouses')->where('id', $warehouseId)->first();

            return ['warehouse' => $w->name ?? (string) $warehouseId, 'qty' => (float) $group->sum('actual_quantity')];
        })->values();

        $lineRows = DB::table('manufacturing_order_lines as l')->join('manufacturing_orders as o', 'o.id', '=', 'l.manufacturing_order_id')
            ->join('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')->where('o.tenant_id', $tenantId)->where('o.status', 'completed')
            ->whereIn('l.manufacturing_order_id', $rows->pluck('id'))
            ->select('i.name_ar', 'i.name_en', 'l.unit', DB::raw('SUM(l.actual_quantity) as qty'))->groupBy('i.name_ar', 'i.name_en', 'l.unit')->get()
            ->map(fn ($r) => ['name' => $r->name_ar ?: $r->name_en, 'unit' => $r->unit, 'qty' => (float) $r->qty])->all();

        return [
            'kpis' => ['totalQty' => $totalQty, 'totalCost' => $totalCost, 'avgUnitCost' => $totalQty > 0 ? round($totalCost / $totalQty, 2) : 0, 'avgEfficiency' => $effs->isNotEmpty() ? round($effs->avg(), 1) : 0, 'totalWasteEvents' => $wasteRows->count()],
            'costByProduct' => $byProduct->all(),
            'expectedVsActual' => $rows->map(fn ($o) => ['id' => $o->reference, 'product' => $o->name_ar ?: $o->name_en, 'expected' => (float) $o->expected_material_cost, 'actual' => (float) $o->actual_material_cost])->all(),
            'waste' => $wasteRows->map(fn ($o) => ['id' => $o->reference, 'product' => $o->name_ar ?: $o->name_en, 'qty' => $o->waste_quantity, 'unit' => $o->waste_unit, 'reason' => $o->waste_reason])->values()->all(),
            'materialConsumption' => $lineRows, 'byProduct' => $byProduct->all(), 'byWarehouse' => $byWarehouse->all(), 'hasData' => $rows->isNotEmpty(),
        ];
    }

    private function summarizeOrder(object $o): array
    {
        $item = DB::table('inventory_items')->where('id', $o->output_item_id)->first();

        return ['id' => $o->reference ?: ('draft_'.$o->id), 'product' => $item->name_ar ?: $item->name_en, 'actual' => $o->actual_quantity !== null ? (string) $o->actual_quantity : null, 'unit' => $o->planned_unit, 'actualCost' => $o->actual_material_cost, 'date' => $o->created_at, 'status' => $o->status];
    }
}
