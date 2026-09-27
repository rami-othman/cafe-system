<?php

namespace App\Services;

use App\Domain\Inventory\UnitConversionResolver;
use App\Support\InventoryDecimal;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class HistoricalBarBalanceService
{
    public function __construct(private readonly UnitConversionResolver $conversions) {}

    /** Require a complete movement ledger, rather than treating a current balance as history. */
    public function quantities(int $tenant, int $warehouse, int $item, ShiftClosePeriod $period): array
    {
        $balance = DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouse)->where('inventory_item_id', $item)->first();
        $movements = DB::table('stock_movements')->where('tenant_id', $tenant)->where('warehouse_id', $warehouse)->where('inventory_item_id', $item)->orderBy('id')->get();
        $all = 0;
        $later = 0;
        foreach ($movements as $movement) {
            $delta = InventoryDecimal::units($movement->quantity_in) - InventoryDecimal::units($movement->quantity_out);
            $all += $delta;
            $occurred = $movement->occurred_at ?: $movement->created_at;
            if ($occurred >= $period->timestamp()) {
                $later += $delta;
            }
            // A later stock count can conceal the timing of an earlier shortage.
            if ($occurred >= $period->timestamp() && $movement->type === 'stock_count_variance') {
                throw ValidationException::withMessages(['barCheck' => __('shifts.historical_bar_adjusted')]);
            }
        }
        $current = InventoryDecimal::signedUnits($balance->quantity_on_hand ?? '0');
        if ($all !== $current) {
            throw ValidationException::withMessages(['barCheck' => __('shifts.historical_bar_incomplete')]);
        }

        return ['historical' => $all - $later, 'later' => $later, 'current' => $current];
    }

    public function enrich(int $tenant, object $shift, ShiftClosePeriod $period, array $bar): array
    {
        $template = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('branch_id', $shift->branch_id)
            ->where('is_active', true)->orderByDesc('required_for_shift_close')->first();
        if (! $template) {
            return $bar;
        }
        $bar['lines'] = collect($bar['lines'])->all();
        foreach ($bar['lines'] as &$line) {
            $item = DB::table('inventory_items')->where('tenant_id', $tenant)->where('id', (int) $line['id'])->first();
            if (! $item || ! $item->is_active || $item->deleted_at !== null) {
                throw ValidationException::withMessages(['barCheck' => __('shifts.historical_bar_incomplete')]);
            }
            $factor = $this->conversions->resolve($tenant, $item, '1.000', $line['unit'])['factor'];
            $quantities = $this->quantities($tenant, (int) $template->warehouse_id, (int) $line['id'], $period);
            // API quantities use the selected count unit; ledger quantities use base units.
            $line['theoretical'] = $quantities['historical'] * 1000 / $factor;
            $line['currentTheoretical'] = $quantities['current'] * 1000 / $factor;
            $line['laterNetQuantity'] = $quantities['later'] * 1000 / $factor;
            $line['counted'] = null;
            $line['unitCost'] = (float) $line['unitCost'] * $factor / 1000000;
        }
        unset($line);
        $bar['lastCountedAt'] = null;

        return $bar;
    }
}
