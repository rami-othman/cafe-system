<?php

namespace App\Http\Controllers\Api;

use App\Domain\Inventory\BarCheckTemplateService;
use App\Http\Controllers\Controller;
use App\Services\StockCountService;
use App\Support\FinancialActor;
use App\Support\InventoryAccess;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class BarCheckController extends Controller
{
    public function __construct(private readonly BarCheckTemplateService $templatesService, private readonly StockCountService $counts) {}

    public function templates(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = DB::table('bar_check_templates as templates')->join('warehouses as warehouses', 'warehouses.id', '=', 'templates.warehouse_id')->join('branches as branches', 'branches.id', '=', 'templates.branch_id')->where('templates.tenant_id', $tenant)->when($request->filled('warehouseId'), fn ($q) => $q->where('templates.warehouse_id', $request->integer('warehouseId')))->orderByDesc('templates.is_active')->orderBy('templates.name');
        InventoryAccess::scopeWarehouseBranches($query, $request, 'warehouses.branch_id');
        $rows = $query->get(['templates.*', 'warehouses.name as warehouse_name', 'branches.name as branch_name']);
        return response()->json(['data' => $rows->map(fn (object $row) => $this->template($row, true))->values()]);
    }

    public function storeTemplate(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $data = $this->templateData($request, false); $actor = FinancialActor::id($request, $tenant);
        $id = DB::transaction(function () use ($request, $tenant, $data, $actor): int {
            $active = $data['active'] ?? true; $required = $data['requiredForShiftClose'] ?? false;
            $validated = $this->templatesService->validate($tenant, (int) $data['branchId'], (int) $data['warehouseId'], $data['lines'] ?? [], $required);
            InventoryAccess::assertBranchAccess($request, $validated['warehouse']->branch_id ? (int) $validated['warehouse']->branch_id : null);
            if ($active) DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('warehouse_id', $validated['warehouse']->id)->update(['is_active' => false, 'updated_at' => now()]);
            $id = (int) DB::table('bar_check_templates')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $data['branchId'], 'warehouse_id' => $validated['warehouse']->id, 'name' => filled($data['name'] ?? null) ? $data['name'] : $validated['warehouse']->name, 'is_active' => $active, 'required_for_shift_close' => $required, 'created_by' => $actor, 'updated_by' => $actor, 'created_at' => now(), 'updated_at' => now()]);
            $this->replaceLines($id, $validated['lines']); return $id;
        });
        return response()->json(['data' => $this->template(DB::table('bar_check_templates')->where('id', $id)->first(), true)], 201);
    }

    public function showTemplate(Request $request, int $template): JsonResponse
    {
        $row = DB::table('bar_check_templates')->where('tenant_id', TenantContext::id($request))->where('id', $template)->first(); abort_unless($row, 404, 'Bar check template not found.'); InventoryAccess::assertBranchAccess($request, $row->branch_id ? (int) $row->branch_id : null);
        return response()->json(['data' => $this->template($row, true)]);
    }

    public function updateTemplate(Request $request, int $template): JsonResponse
    {
        $tenant = TenantContext::id($request); $data = $this->templateData($request, true); $actor = FinancialActor::id($request, $tenant);
        DB::transaction(function () use ($request, $tenant, $template, $data, $actor): void {
            $current = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('id', $template)->lockForUpdate()->first(); abort_unless($current, 404, 'Bar check template not found.'); InventoryAccess::assertBranchAccess($request, $current->branch_id ? (int) $current->branch_id : null);
            $branchId = (int) ($data['branchId'] ?? $current->branch_id); $warehouseId = (int) ($data['warehouseId'] ?? $current->warehouse_id); $required = $data['requiredForShiftClose'] ?? (bool) $current->required_for_shift_close;
            $lineInput = array_key_exists('lines', $data) ? $data['lines'] : $this->rawLines($template);
            $validated = $this->templatesService->validate($tenant, $branchId, $warehouseId, $lineInput, $required); InventoryAccess::assertBranchAccess($request, $validated['warehouse']->branch_id ? (int) $validated['warehouse']->branch_id : null); $active = $data['active'] ?? (bool) $current->is_active;
            if ($active) DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('id', '!=', $template)->update(['is_active' => false, 'updated_at' => now()]);
            DB::table('bar_check_templates')->where('id', $template)->update(['branch_id' => $branchId, 'warehouse_id' => $warehouseId, 'name' => $data['name'] ?? $current->name, 'is_active' => $active, 'required_for_shift_close' => $required, 'updated_by' => $actor, 'updated_at' => now()]);
            if (array_key_exists('lines', $data)) $this->replaceLines($template, $validated['lines']);
        });
        return response()->json(['data' => $this->template(DB::table('bar_check_templates')->where('id', $template)->first(), true)]);
    }

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = DB::table('stock_counts as counts')->join('shifts', 'shifts.id', '=', 'counts.shift_id')->join('warehouses', 'warehouses.id', '=', 'counts.warehouse_id')->join('branches', 'branches.id', '=', 'counts.branch_id')->leftJoin('bar_check_templates as templates', 'templates.id', '=', 'counts.bar_check_template_id')->where('counts.tenant_id', $tenant)->where('counts.count_type', 'shift_check')->when($request->filled('status'), fn ($q) => $q->where('counts.status', $request->query('status')))->when($request->filled('warehouseId'), fn ($q) => $q->where('counts.warehouse_id', $request->integer('warehouseId')))->orderByDesc('counts.id');
        InventoryAccess::scopeWarehouseBranches($query, $request, 'warehouses.branch_id');
        $rows = $query->get(['counts.*', 'branches.name as branch_name', 'warehouses.name as warehouse_name', 'templates.name as template_name', 'shifts.opened_at']);
        return response()->json(['data' => $rows->map(fn (object $row) => ['stockCountId' => (int) $row->id, 'shiftId' => (int) $row->shift_id, 'branchName' => $row->branch_name, 'warehouseName' => $row->warehouse_name, 'templateName' => $row->template_name, 'status' => $row->status, 'openedAt' => $row->opened_at])->values()]);
    }

    public function start(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $data = $request->validate(['shiftId' => ['required', 'integer'], 'warehouseId' => ['required', 'integer']]);
        $id = $this->counts->startBarCheck($request, $tenant, (int) $data['shiftId'], (int) $data['warehouseId'], FinancialActor::id($request, $tenant));
        return response()->json(['data' => ['stockCountId' => $id]], 201);
    }

    private function templateData(Request $request, bool $partial): array
    {
        return $request->validate([
            'name' => [$partial ? 'sometimes' : 'nullable', 'string', 'max:160'], 'branchId' => [$partial ? 'sometimes' : 'required', 'integer'], 'warehouseId' => [$partial ? 'sometimes' : 'required', 'integer'], 'active' => [$partial ? 'sometimes' : 'nullable', 'boolean'], 'requiredForShiftClose' => [$partial ? 'sometimes' : 'nullable', 'boolean'], 'lines' => [$partial ? 'sometimes' : 'nullable', 'array'],
            'lines.*.itemId' => ['required_with:lines', 'integer', 'distinct'], 'lines.*.countUnit' => ['required_with:lines', 'string', 'max:40'], 'lines.*.required' => ['nullable', 'boolean'], 'lines.*.toleranceType' => ['nullable', Rule::in(['quantity', 'percentage'])], 'lines.*.tolerance' => ['nullable', 'regex:/^\d+(\.\d{1,3})?$/'], 'lines.*.managerReviewThreshold' => ['nullable', 'regex:/^\d+(\.\d{1,3})?$/'], 'lines.*.requiresReviewWhenExceeded' => ['nullable', 'boolean'],
        ]);
    }

    private function replaceLines(int $templateId, array $lines): void
    {
        DB::table('bar_check_template_lines')->where('bar_check_template_id', $templateId)->delete(); $now = now();
        if ($lines !== []) DB::table('bar_check_template_lines')->insert(array_map(fn (array $line) => $line + ['bar_check_template_id' => $templateId, 'created_at' => $now, 'updated_at' => $now], $lines));
    }

    private function rawLines(int $templateId): array
    {
        return DB::table('bar_check_template_lines')->where('bar_check_template_id', $templateId)->orderBy('sort_order')->get()->map(fn (object $line) => ['itemId' => $line->inventory_item_id, 'countUnit' => $line->count_unit, 'required' => (bool) $line->is_required, 'toleranceType' => $line->tolerance_type ?? 'quantity', 'tolerance' => $line->quantity_tolerance, 'managerReviewThreshold' => $line->manager_review_threshold, 'requiresReviewWhenExceeded' => (bool) ($line->requires_review_when_exceeded ?? false)])->all();
    }

    private function template(object $row, bool $detail): array
    {
        $data = ['id' => (int) $row->id, 'name' => $row->name, 'branchId' => (int) $row->branch_id, 'warehouseId' => (int) $row->warehouse_id, 'branchName' => $row->branch_name ?? null, 'warehouseName' => $row->warehouse_name ?? null, 'active' => (bool) $row->is_active, 'requiredForShiftClose' => (bool) $row->required_for_shift_close];
        if ($detail) $data['lines'] = DB::table('bar_check_template_lines as lines')->join('inventory_items as items', 'items.id', '=', 'lines.inventory_item_id')->where('lines.bar_check_template_id', $row->id)->orderBy('lines.sort_order')->get(['lines.*', 'items.name_en', 'items.name_ar', 'items.sku'])->map(fn (object $line) => ['itemId' => (int) $line->inventory_item_id, 'itemName' => $line->name_ar ?: $line->name_en, 'sku' => $line->sku, 'countUnit' => $line->count_unit, 'required' => (bool) $line->is_required, 'toleranceType' => $line->tolerance_type ?? 'quantity', 'tolerance' => $line->quantity_tolerance, 'managerReviewThreshold' => $line->manager_review_threshold, 'requiresReviewWhenExceeded' => (bool) ($line->requires_review_when_exceeded ?? false), 'sortOrder' => $line->sort_order])->values();
        return $data;
    }
}
