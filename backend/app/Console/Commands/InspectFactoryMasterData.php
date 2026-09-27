<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class InspectFactoryMasterData extends Command
{
    protected $signature = 'factory:inspect-master-data';
    protected $description = 'Read-only report of suppliers and customers used exclusively by a factory';

    public function handle(): int
    {
        $candidates = [];
        foreach ([['suppliers', 'supplier_invoices', 'supplier_id'], ['customers', 'sales_invoices', 'customer_id']] as [$table, $documents, $key]) {
            foreach (DB::table($table)->whereNull('owner_branch_id')->get() as $row) {
                $branches = DB::table($documents.' as d')->leftJoin('branches as b', 'b.id', '=', 'd.branch_id')
                    ->where('d.tenant_id', $row->tenant_id)->where('d.'.$key, $row->id)
                    ->distinct()->get(['d.branch_id', 'b.branch_type']);
                if ($branches->count() === 1 && $branches->first()->branch_type === 'factory') {
                    $candidates[] = [$table, $row->id, $row->name, $branches->first()->branch_id];
                }
            }
        }
        $this->table(['Table', 'ID', 'Name', 'Candidate factory'], $candidates);
        $this->info('Candidates: '.count($candidates).'. Read only; existing records remain in the cafe scope. Manual approval is required to move them.');
        return self::SUCCESS;
    }
}
