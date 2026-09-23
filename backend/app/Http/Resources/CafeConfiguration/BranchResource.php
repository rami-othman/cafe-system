<?php

namespace App\Http\Resources\CafeConfiguration;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\DB;

class BranchResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $effective = $this->effectivePosWarehouse();

        return [
            'id' => $this->id,
            'name' => $this->name,
            'address' => $this->address,
            'phone' => $this->phone,
            'timezone' => $this->timezone,
            'currency' => $this->currency,
            'isActive' => $this->is_active,
            'posCashFinancialLocationId' => $this->pos_cash_financial_location_id,
            'shiftCloseDestinationFinancialLocationId' => $this->shift_close_destination_financial_location_id,
            'shiftClosingFloatAmount' => $this->shift_closing_float_amount,
            'shiftCloseTime' => $this->shift_close_time ? substr($this->shift_close_time, 0, 5) : null,
            'receiptPrintingEnabled' => $this->receipt_printing_enabled,
            'defaultPaperWidth' => $this->default_paper_width,
            'autoPrintAfterPayment' => $this->auto_print_after_payment,
            'defaultPrinterName' => $this->default_printer_name,
            'defaultPrinterIp' => $this->default_printer_ip,
            'defaultPrinterPort' => $this->default_printer_port,
            'availableShiftCloseDestinations' => DB::table('financial_locations as l')
                ->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
                ->where('l.tenant_id', $this->tenant_id)->where('l.kind', 'cash')->where('l.is_active', true)
                ->where('a.tenant_id', $this->tenant_id)->where('a.is_active', true)->whereNull('a.deleted_at')
                ->where(fn ($q) => $q->whereNull('l.branch_id')->orWhere('l.branch_id', $this->id))
                ->where('l.id', '<>', $this->pos_cash_financial_location_id ?? 0)
                ->orderBy('l.name')->get(['l.id', 'l.name'])->map(fn ($l) => ['id' => (int) $l->id, 'name' => $l->name]),
            'availablePosCashLocations' => DB::table('financial_locations as l')
                ->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
                ->where('l.tenant_id', $this->tenant_id)->where('l.branch_id', $this->id)
                ->where('l.kind', 'cash')->where('l.type', 'cash_drawer')->where('l.is_active', true)
                ->where('a.tenant_id', $this->tenant_id)->where('a.is_active', true)->whereNull('a.deleted_at')
                ->orderBy('l.name')->get(['l.id', 'l.name'])->map(fn ($l) => ['id' => (int) $l->id, 'name' => $l->name]),
            'posInventoryWarehouseId' => $this->pos_inventory_warehouse_id,
            'posInventoryWarehouse' => $this->whenLoaded('posInventoryWarehouse', fn () => $this->posInventoryWarehouse ? [
                'id' => $this->posInventoryWarehouse->id,
                'name' => $this->posInventoryWarehouse->name,
                'type' => $this->posInventoryWarehouse->type,
            ] : null),
            'effectivePosInventoryWarehouseId' => $effective['warehouse']?->id,
            'effectivePosInventoryWarehouse' => $effective['warehouse'] ? [
                'id' => $effective['warehouse']->id,
                'name' => $effective['warehouse']->name,
                'type' => $effective['warehouse']->type,
            ] : null,
            'posInventoryWarehouseSource' => $effective['source'],
            'availablePosWarehouses' => $this->whenLoaded('warehouses', fn () => $this->warehouses->map(fn ($warehouse) => [
                'id' => $warehouse->id,
                'name' => $warehouse->name,
                'type' => $warehouse->type,
            ])->values()),
            'createdAt' => $this->created_at?->toISOString(),
            'updatedAt' => $this->updated_at?->toISOString(),
        ];
    }

    /**
     * There is no "primary"/"bar" precedence — a branch is a flat set of
     * warehouses. An explicit `pos_inventory_warehouse_id` always wins;
     * otherwise this only resolves when the branch has exactly one
     * warehouse (mirrors PosInventoryWarehouseResolver exactly, so the UI
     * can never show a different answer than what POS actually uses).
     *
     * @return array{warehouse:mixed,source:string}
     */
    private function effectivePosWarehouse(): array
    {
        if (! $this->relationLoaded('warehouses')) {
            return ['warehouse' => null, 'source' => 'not_loaded'];
        }
        if ($this->pos_inventory_warehouse_id !== null) {
            $configured = $this->warehouses->firstWhere('id', (int) $this->pos_inventory_warehouse_id);

            return ['warehouse' => $configured, 'source' => $configured ? 'configured' : 'invalid_configured'];
        }
        if ($this->warehouses->count() === 1) {
            return ['warehouse' => $this->warehouses->first(), 'source' => 'single_warehouse'];
        }

        return ['warehouse' => null, 'source' => $this->warehouses->count() > 1 ? 'ambiguous' : 'not_configured'];
    }
}
