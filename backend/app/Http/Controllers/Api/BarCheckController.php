<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\FinancialActor;
use App\Support\InventoryDecimal;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class BarCheckController extends Controller
{
    public function templates(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $rows = DB::table('bar_check_templates as templates')
            ->join('warehouses as warehouses', 'warehouses.id', '=', 'templates.warehouse_id')
            ->join('branches as branches', 'branches.id', '=', 'templates.branch_id')
            ->where('templates.tenant_id', $tenant)
            ->when($request->filled('warehouseId'), fn ($query) => $query->where('templates.warehouse_id', $request->integer('warehouseId')))
            ->orderByDesc('templates.is_active')->orderBy('templates.name')
            ->get(['templates.*', 'warehouses.name as warehouse_name', 'branches.name as branch_name']);

        return response()->json(['data' => $rows->map(fn (object $row) => $this->template($tenant, $row, true))->values()]);
    }

    public function storeTemplate(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate([
            'name' => ['nullable', 'string', 'max:160'],
            'branchId' => ['required', 'integer'],
            'warehouseId' => ['required', 'integer'],
            'active' => ['boolean'],
            'requiredForShiftClose' => ['boolean'],
            'lines' => ['nullable', 'array'],
            'lines.*.itemId' => ['required_with:lines', 'integer', 'distinct'],
            'lines.*.countUnit' => ['required_with:lines', 'string', 'max:40'],
            'lines.*.required' => ['nullable', 'boolean'],
            'lines.*.toleranceType' => ['nullable', Rule::in(['quantity', 'percentage'])],
            'lines.*.tolerance' => ['nullable', 'numeric', 'min:0'],
            'lines.*.requiresReviewWhenExceeded' => ['nullable', 'boolean'],
        ]);
        $actor = FinancialActor::id($request, $tenant);
        $id = DB::transaction(function () use ($tenant, $data, $actor): int {
            $warehouse = DB::table('warehouses')->where('tenant_id', $tenant)->where('id', $data['warehouseId'])->where('branch_id', $data['branchId'])->first();
            abort_unless($warehouse, 422, 'يجب اختيار مخزن بار تابع للفرع المحدد.');
            if (($data['active'] ?? true) === true) {
                DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('warehouse_id', $warehouse->id)->update(['is_active' => false, 'updated_at' => now()]);
            }
            $id = (int) DB::table('bar_check_templates')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $data['branchId'], 'warehouse_id' => $warehouse->id, 'name' => filled($data['name'] ?? null) ? $data['name'] : $warehouse->name, 'is_active' => $data['active'] ?? true, 'required_for_shift_close' => $data['requiredForShiftClose'] ?? false, 'created_by' => $actor, 'updated_by' => $actor, 'created_at' => now(), 'updated_at' => now()]);
            $items = DB::table('inventory_items')->where('tenant_id', $tenant)->whereIn('id', collect($data['lines'] ?? [])->pluck('itemId'))->whereNull('deleted_at')->pluck('unit', 'id');
            foreach (($data['lines'] ?? []) as $order => $line) {
                if (! $items->has($line['itemId'])) {
                    throw ValidationException::withMessages(['lines' => 'تتضمن القائمة مادة مخزنية غير صالحة.']);
                }
                if (($line['toleranceType'] ?? 'quantity') === 'percentage' && ($line['tolerance'] ?? 0) > 100) throw ValidationException::withMessages(['lines' => 'Percentage tolerance cannot exceed 100%.']);
                DB::table('bar_check_template_lines')->insert(['tenant_id' => $tenant, 'bar_check_template_id' => $id, 'inventory_item_id' => $line['itemId'], 'count_unit' => $line['countUnit'], 'is_required' => $line['required'] ?? true, 'tolerance_type' => $line['toleranceType'] ?? 'quantity', 'quantity_tolerance' => $line['tolerance'] ?? 0, 'requires_review_when_exceeded' => $line['requiresReviewWhenExceeded'] ?? false, 'sort_order' => $order, 'created_at' => now(), 'updated_at' => now()]);
            }
            return $id;
        });
        $row = DB::table('bar_check_templates')->where('id', $id)->first();
        return response()->json(['data' => $this->template($tenant, $row, true)], 201);
    }

    public function showTemplate(Request $request, int $template): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $row = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('id', $template)->first();
        abort_unless($row, 404, 'Bar check template not found.');
        return response()->json(['data' => $this->template($tenant, $row, true)]);
    }

    public function updateTemplate(Request $request, int $template): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['name' => ['sometimes', 'string', 'max:160'], 'branchId' => ['sometimes', 'integer'], 'warehouseId' => ['sometimes', 'integer'], 'active' => ['sometimes', 'boolean'], 'requiredForShiftClose' => ['sometimes', 'boolean'], 'lines' => ['sometimes', 'array'], 'lines.*.itemId' => ['required_with:lines', 'integer', 'distinct'], 'lines.*.countUnit' => ['required_with:lines', 'string', 'max:40'], 'lines.*.required' => ['nullable', 'boolean'], 'lines.*.toleranceType' => ['nullable', Rule::in(['quantity', 'percentage'])], 'lines.*.tolerance' => ['nullable', 'numeric', 'min:0'], 'lines.*.requiresReviewWhenExceeded' => ['nullable', 'boolean']]);
        $actor = FinancialActor::id($request, $tenant);
        DB::transaction(function () use ($tenant, $template, $data, $actor): void {
            $current = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('id', $template)->lockForUpdate()->first();
            abort_unless($current, 404, 'Bar check template not found.');
            $branchId = $data['branchId'] ?? $current->branch_id;
            $warehouseId = $data['warehouseId'] ?? $current->warehouse_id;
            $warehouse = DB::table('warehouses')->where('tenant_id', $tenant)->where('id', $warehouseId)->where('branch_id', $branchId)->where('is_active', true)->first();
            abort_unless($warehouse, 422, 'Select an active bar warehouse within the selected branch.');
            $active = $data['active'] ?? (bool) $current->is_active;
            if ($active) DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('id', '!=', $template)->update(['is_active' => false, 'updated_at' => now()]);
            DB::table('bar_check_templates')->where('id', $template)->update(['branch_id' => $branchId, 'warehouse_id' => $warehouseId, 'name' => $data['name'] ?? $current->name, 'is_active' => $active, 'required_for_shift_close' => $data['requiredForShiftClose'] ?? $current->required_for_shift_close, 'updated_by' => $actor, 'updated_at' => now()]);
            if (! array_key_exists('lines', $data)) return;
            $items = DB::table('inventory_items')->where('tenant_id', $tenant)->whereIn('id', collect($data['lines'])->pluck('itemId'))->whereNull('deleted_at')->pluck('unit', 'id');
            DB::table('bar_check_template_lines')->where('bar_check_template_id', $template)->delete();
            foreach ($data['lines'] as $order => $line) {
                if (! $items->has($line['itemId'])) throw ValidationException::withMessages(['lines' => 'The template contains an unavailable inventory item.']);
                if (($line['toleranceType'] ?? 'quantity') === 'percentage' && ($line['tolerance'] ?? 0) > 100) throw ValidationException::withMessages(['lines' => 'Percentage tolerance cannot exceed 100%.']);
                DB::table('bar_check_template_lines')->insert(['tenant_id' => $tenant, 'bar_check_template_id' => $template, 'inventory_item_id' => $line['itemId'], 'count_unit' => $line['countUnit'], 'is_required' => $line['required'] ?? true, 'tolerance_type' => $line['toleranceType'] ?? 'quantity', 'quantity_tolerance' => $line['tolerance'] ?? 0, 'requires_review_when_exceeded' => $line['requiresReviewWhenExceeded'] ?? false, 'sort_order' => $order, 'created_at' => now(), 'updated_at' => now()]);
            }
        });
        return response()->json(['data' => $this->template($tenant, DB::table('bar_check_templates')->where('id', $template)->first(), true)]);
    }

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $rows = DB::table('stock_counts as counts')->join('shifts', 'shifts.id', '=', 'counts.shift_id')->join('warehouses', 'warehouses.id', '=', 'counts.warehouse_id')->join('branches', 'branches.id', '=', 'counts.branch_id')->leftJoin('bar_check_templates as templates', 'templates.id', '=', 'counts.bar_check_template_id')->where('counts.tenant_id', $tenant)->where('counts.count_type', 'shift_check')->when($request->filled('status'), fn ($query) => $query->where('counts.status', $request->query('status')))->when($request->filled('warehouseId'), fn ($query) => $query->where('counts.warehouse_id', $request->integer('warehouseId')))->orderByDesc('counts.id')->get(['counts.*', 'branches.name as branch_name', 'warehouses.name as warehouse_name', 'templates.name as template_name', 'shifts.opened_at']);
        return response()->json(['data' => $rows->map(fn (object $row) => $this->check($row))->values()]);
    }

    public function start(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['shiftId' => ['required', 'integer'], 'warehouseId' => ['required', 'integer']]);
        $actor = FinancialActor::id($request, $tenant);
        $id = DB::transaction(function () use ($tenant, $data, $actor): int {
            $shift = DB::table('shifts')->where('tenant_id', $tenant)->where('id', $data['shiftId'])->where('status', 'open')->first();
            abort_unless($shift, 422, 'لا يوجد شفت مفتوح صالح لفحص البار.');
            $template = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('branch_id', $shift->branch_id)->where('warehouse_id', $data['warehouseId'])->where('is_active', true)->first();
            abort_unless($template, 422, 'لا يوجد قالب فحص بار نشط لهذا المخزن.');
            $existing = DB::table('stock_counts')->where('tenant_id', $tenant)->where('shift_id', $shift->id)->where('warehouse_id', $template->warehouse_id)->where('count_type', 'shift_check')->first();
            if ($existing) return (int) $existing->id;
            $id = (int) DB::table('stock_counts')->insertGetId(['tenant_id' => $tenant, 'warehouse_id' => $template->warehouse_id, 'branch_id' => $shift->branch_id, 'shift_id' => $shift->id, 'bar_check_template_id' => $template->id, 'count_date' => now()->toDateString(), 'count_type' => 'shift_check', 'status' => 'in_progress', 'counted_by' => $actor, 'created_at' => now(), 'updated_at' => now()]);
            $lines = DB::table('bar_check_template_lines as lines')->join('inventory_items as items', 'items.id', '=', 'lines.inventory_item_id')->leftJoin('stock_balances as balances', fn ($join) => $join->on('balances.inventory_item_id', '=', 'items.id')->where('balances.tenant_id', $tenant)->where('balances.warehouse_id', $template->warehouse_id))->where('lines.tenant_id', $tenant)->where('lines.bar_check_template_id', $template->id)->orderBy('lines.sort_order')->get(['lines.*', 'balances.quantity_on_hand', 'balances.average_unit_cost']);
            foreach ($lines as $line) DB::table('stock_count_lines')->insert(['tenant_id' => $tenant, 'stock_count_id' => $id, 'inventory_item_id' => $line->inventory_item_id, 'is_required' => $line->is_required, 'expected_quantity' => InventoryDecimal::quantity(InventoryDecimal::units($line->quantity_on_hand ?? '0')), 'counted_quantity' => null, 'variance_quantity' => '0.000', 'quantity_tolerance' => $line->quantity_tolerance, 'manager_review_threshold' => $line->manager_review_threshold, 'average_unit_cost' => InventoryDecimal::unitCost($line->average_unit_cost ?? '0'), 'created_at' => now(), 'updated_at' => now()]);
            return $id;
        });
        return response()->json(['data' => ['stockCountId' => $id]], 201);
    }

    private function template(int $tenant, object $row, bool $detail): array
    {
        $data = ['id' => (int) $row->id, 'name' => $row->name, 'branchId' => (int) $row->branch_id, 'warehouseId' => (int) $row->warehouse_id, 'branchName' => $row->branch_name ?? null, 'warehouseName' => $row->warehouse_name ?? null, 'active' => (bool) $row->is_active, 'requiredForShiftClose' => (bool) $row->required_for_shift_close];
        if ($detail) $data['lines'] = DB::table('bar_check_template_lines as lines')->join('inventory_items as items', 'items.id', '=', 'lines.inventory_item_id')->where('lines.bar_check_template_id', $row->id)->orderBy('lines.sort_order')->get(['lines.*', 'items.name_en', 'items.name_ar', 'items.sku'])->map(fn (object $line) => ['itemId' => (int) $line->inventory_item_id, 'itemName' => $line->name_ar ?: $line->name_en, 'sku' => $line->sku, 'countUnit' => $line->count_unit, 'required' => (bool) $line->is_required, 'toleranceType' => $line->tolerance_type ?? 'quantity', 'tolerance' => $line->quantity_tolerance, 'requiresReviewWhenExceeded' => (bool) ($line->requires_review_when_exceeded ?? false), 'sortOrder' => $line->sort_order])->values();
        return $data;
    }

    private function check(object $row): array { return ['stockCountId' => (int) $row->id, 'shiftId' => (int) $row->shift_id, 'branchName' => $row->branch_name, 'warehouseName' => $row->warehouse_name, 'templateName' => $row->template_name, 'status' => $row->status, 'openedAt' => $row->opened_at]; }
}
