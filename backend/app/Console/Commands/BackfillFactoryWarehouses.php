<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
final class BackfillFactoryWarehouses extends Command {
    protected $signature = 'factory:backfill-warehouses {--apply}';
    protected $description = 'Preview factory warehouse decoupling; apply through the reversible migration.';
    public function handle(): int {
        $rows = DB::table('branches')->where('branch_type', 'factory')->get(['id', 'tenant_id', 'pos_inventory_warehouse_id']);
        $this->table(['branch', 'tenant', 'POS warehouse to copy'], $rows->map(fn ($b) => [$b->id, $b->tenant_id, $b->pos_inventory_warehouse_id])->all());
        if ($this->option('apply')) return $this->call('migrate', ['--force' => true]);
        return self::SUCCESS;
    }
}
