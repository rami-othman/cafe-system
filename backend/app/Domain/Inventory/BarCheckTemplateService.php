<?php

namespace App\Domain\Inventory;

use App\Support\InventoryDecimal;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

final class BarCheckTemplateService
{
    public function __construct(private readonly UnitConversionResolver $conversions) {}

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
            if (Schema::hasTable('inventory_item_warehouses') && ! DB::table('inventory_item_warehouses')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $item->id)->exists()) throw ValidationException::withMessages(['lines' => 'Every template item must be assigned to the selected warehouse.']);
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
