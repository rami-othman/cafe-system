<?php

namespace App\Console\Commands;

use App\Domain\Inventory\InventoryReconciliationService;
use Illuminate\Console\Command;

class ReconcileInventoryBalances extends Command
{
    protected $signature = 'inventory:reconcile {--tenant=} {--warehouse=} {--item=}';
    protected $description = 'Dry-run comparison of stock movements and stock balances; never writes data.';

    public function handle(InventoryReconciliationService $reconciliation): int
    {
        $report = $reconciliation->dryRun(
            $this->option('tenant') === null ? null : (int) $this->option('tenant'),
            $this->option('warehouse') === null ? null : (int) $this->option('warehouse'),
            $this->option('item') === null ? null : (int) $this->option('item'),
        );
        $this->info("Checked {$report['checked']} inventory scopes; found ".count($report['differences']).' differences.');
        if ($report['differences'] !== []) $this->table(['Tenant', 'Warehouse', 'Item', 'Movements', 'Balance', 'Difference'], array_map(fn (array $row) => [$row['tenantId'], $row['warehouseId'], $row['itemId'], $row['movementQuantity'], $row['balanceQuantity'], $row['difference']], $report['differences']));

        return self::SUCCESS;
    }
}
