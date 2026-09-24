<?php

namespace App\Console\Commands;

use App\Services\ShiftOverlapReconciliationService;
use Illuminate\Console\Command;

/** Read-only: lists cash drawers that currently have more than one open shift. */
final class DetectShiftOverlaps extends Command
{
    protected $signature = 'shifts:detect-overlaps {--tenant= : Limit to one tenant id}';

    protected $description = 'List cash drawers with overlapping open shifts (read-only)';

    public function handle(ShiftOverlapReconciliationService $service): int
    {
        $rows = $service->detect($this->option('tenant') !== null ? (int) $this->option('tenant') : null);
        if ($rows->isEmpty()) {
            $this->info('No overlapping open shifts found.');

            return self::SUCCESS;
        }
        $this->table(['Tenant', 'Drawer location', 'Open shifts', 'First opened at', 'Shift ids'], $rows->map(fn (object $r) => [
            $r->tenant_id, $r->financial_location_id, $r->open_shift_count, $r->first_opened_at, implode(', ', $r->shift_ids),
        ])->all());
        $this->warn('Run shifts:reconcile-overlap {tenantId} {financialLocationId} (dry-run first) for each drawer listed.');

        return self::FAILURE;
    }
}
