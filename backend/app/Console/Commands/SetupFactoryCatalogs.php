<?php

namespace App\Console\Commands;

use App\Services\FactoryCatalogService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SetupFactoryCatalogs extends Command
{
    protected $signature = 'factory:setup-catalogs {--apply}';
    protected $description = 'Create independent factory invoice catalogs from cafe defaults without moving records';

    public function handle(FactoryCatalogService $catalogs): int
    {
        $count = 0;
        foreach (DB::table('branches')->where('branch_type', 'factory')->whereNull('deleted_at')->get() as $branch) {
            $created = $catalogs->ensureForBranch((int) $branch->tenant_id, (int) $branch->id, (bool) $this->option('apply'));
            foreach ($created as $record) $this->line('Create '.$record.' for branch '.$branch->id);
            $count += count($created);
        }
        $this->info('New records: '.$count.'. '.($this->option('apply') ? 'Applied.' : 'Dry run.'));
        return self::SUCCESS;
    }
}