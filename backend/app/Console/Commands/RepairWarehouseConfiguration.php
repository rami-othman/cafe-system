<?php

namespace App\Console\Commands;

use App\Services\Inventory\WarehouseConfigurationRepairService;
use Illuminate\Console\Command;

final class RepairWarehouseConfiguration extends Command
{
    protected $signature = 'inventory:repair-warehouse-configuration {--apply : Apply safe fixes; without this flag the command is a dry-run} {--tenant= : Limit the audit to one tenant id}';
    protected $description = 'Audit and safely repair branch-main warehouse configuration without touching stock or movements.';

    public function handle(WarehouseConfigurationRepairService $repair): int
    {
        $tenant = $this->option('tenant');
        if ($tenant !== null && (! ctype_digit((string) $tenant) || (int) $tenant <= 0)) {
            $this->error('--tenant must be a positive integer.');
            return self::INVALID;
        }
        $apply = (bool) $this->option('apply');
        $result = $repair->run($apply, $tenant === null ? null : (int) $tenant);
        foreach ($result['findings'] as $finding) {
            $this->line(json_encode($finding, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
        }
        $this->info(($apply ? 'Applied' : 'Dry-run').": {$result['fixed']} safe fix(es); ".count($result['findings']).' finding(s).');

        return collect($result['findings'])->contains(fn (array $finding) => $finding['action'] === 'manual_review')
            ? self::FAILURE
            : self::SUCCESS;
    }
}
