<?php

namespace App\Domain\Inventory;

use App\Support\InventoryDecimal;
use App\Services\PosInventoryWarehouseResolver;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class BarCheckTemplateService
{
    public function __construct(private readonly UnitConversionResolver $conversions, private readonly InventoryWarehouseAssignment $assignments) {}

    /** @return array{warehouse: object, lines: array<int, array>} */
    public function validate(int $tenantId, int $branchId, int $warehouseId, array $lines, bool $requiredForShiftClose): array
    {
        $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->where('branch_id', $branchId)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $warehouse) throw ValidationException::withMessages(['warehouseId' => 'Select an active bar warehouse within the selected branch.']);
        if ($requiredForShiftClose && $lines === []) throw ValidationException::withMessages(['lines' => 'A template required for shift close must contain at least one line.']);
        $prepared = [];
        foreach ($lines as $order => $line) {
            $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $line['itemId'])->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $item) throw ValidationException::withMessages(['lines' => 'The template contains an inactive inventory item.']);
            $this->assignments->assertAssigned($tenantId, (int) $item->id, $warehouseId, 'lines');
            $tolerance = InventoryDecimal::units($line['tolerance'] ?? '0', 'lines');
            $type = $line['toleranceType'] ?? 'quantity';
            if ($type === 'percentage' && $tolerance > 100000) throw ValidationException::withMessages(['lines' => 'Percentage tolerance cannot exceed 100%.']);
            $threshold = array_key_exists('managerReviewThreshold', $line) && $line['managerReviewThreshold'] !== null ? InventoryDecimal::units($line['managerReviewThreshold'], 'managerReviewThreshold') : null;
            if ($type === 'percentage' && $threshold !== null && $threshold > 100000) throw ValidationException::withMessages(['managerReviewThreshold' => 'Percentage review threshold cannot exceed 100%.']);
            $this->conversions->resolve($tenantId, $item, '1.000', $line['countUnit']);
            $prepared[] = ['tenant_id' => $tenantId, 'inventory_item_id' => $item->id, 'count_unit' => $line['countUnit'], 'is_required' => $line['required'] ?? true, 'tolerance_type' => $type, 'quantity_tolerance' => InventoryDecimal::quantity($tolerance), 'manager_review_threshold' => $threshold === null ? null : InventoryDecimal::quantity($threshold), 'requires_review_when_exceeded' => $line['requiresReviewWhenExceeded'] ?? false, 'sort_order' => $order];
        }
        return ['warehouse' => $warehouse, 'lines' => $prepared];
    }

    /**
     * A branch that has never configured a bar check still has to count what its sales consumed.
     * The first time a shift of that branch is closed, a template is created for the POS warehouse
     * from every material the sales already took out of it (or, before any sale, from what the warehouse holds), and it is required for shift close.
     * Once any template exists for that warehouse (even a deactivated one) the owner is in control
     * and nothing is created again. The owner can edit the generated template like any other.
     */
    public function ensureDefaultForBranch(int $tenantId, int $branchId, ?int $actorId = null): ?object
    {
        try {
            $warehouse = app(PosInventoryWarehouseResolver::class)->forBranch($tenantId, $branchId);
        } catch (\Throwable) {
            return null;
        }
        $warehouseId = (int) $warehouse->id;
        $exists = fn () => DB::table('bar_check_templates')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('warehouse_id', $warehouseId)->exists();
        if ($exists()) {
            return null;
        }
        $lines = [];
        $itemIds = DB::table('stock_movements')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)->where('type', 'sale_consumption')->distinct()->pluck('inventory_item_id');
        if ($itemIds->isEmpty()) {
            // Nothing was consumed by a sale yet: count what the bar actually holds.
            $itemIds = DB::table('stock_balances')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)->where('quantity_on_hand', '>', 0)->pluck('inventory_item_id');
        }
        foreach (DB::table('inventory_items')->where('tenant_id', $tenantId)->whereIn('id', $itemIds)->where('is_active', true)->whereNull('deleted_at')->orderBy('name_ar')->orderBy('id')->get() as $item) {
            $line = ['itemId' => (int) $item->id, 'countUnit' => $item->unit, 'required' => true, 'toleranceType' => 'quantity', 'tolerance' => '0'];
            try {
                $this->validate($tenantId, $branchId, $warehouseId, [$line], true);
            } catch (ValidationException) {
                continue;
            }
            $lines[] = $line;
        }
        if ($lines === []) {
            return null;
        }
        $validated = $this->validate($tenantId, $branchId, $warehouseId, $lines, true);

        return DB::transaction(function () use ($tenantId, $branchId, $warehouseId, $warehouse, $validated, $actorId, $exists): ?object {
            DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->lockForUpdate()->first();
            if ($exists()) {
                return null;
            }
            $now = now();
            $id = (int) DB::table('bar_check_templates')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $branchId, 'warehouse_id' => $warehouseId,
                'name' => 'جرد البار - '.$warehouse->name, 'is_active' => true, 'required_for_shift_close' => true,
                'created_by' => $actorId, 'updated_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            DB::table('bar_check_template_lines')->insert(array_map(fn (array $line) => $line + ['bar_check_template_id' => $id, 'created_at' => $now, 'updated_at' => $now], $validated['lines']));

            return DB::table('bar_check_templates')->where('id', $id)->first();
        });
    }

    /** Legacy invalid/empty templates must not permanently block shift close. */
    public function isUsable(int $tenantId, object $template): bool
    {
        try {
            $lines = DB::table('bar_check_template_lines')->where('tenant_id', $tenantId)->where('bar_check_template_id', $template->id)->get();
            if ($lines->isEmpty()) return false;
            $this->validate($tenantId, (int) $template->branch_id, (int) $template->warehouse_id, $lines->map(fn (object $line) => [
                'itemId' => $line->inventory_item_id, 'countUnit' => $line->count_unit,
                'required' => (bool) $line->is_required, 'toleranceType' => $line->tolerance_type ?? 'quantity',
                'tolerance' => $line->quantity_tolerance, 'managerReviewThreshold' => $line->manager_review_threshold,
                'requiresReviewWhenExceeded' => (bool) ($line->requires_review_when_exceeded ?? false),
            ])->all(), true);
            return true;
        } catch (ValidationException) {
            return false;
        }
    }
}
