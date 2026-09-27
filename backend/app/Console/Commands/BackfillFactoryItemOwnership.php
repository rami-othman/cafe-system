<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class BackfillFactoryItemOwnership extends Command
{
    protected $signature = 'factory:backfill-items {--apply : Apply unambiguous ownership assignments}';
    protected $description = 'Preview factory material ownership; refuse application when assignments conflict';

    public function handle(): int
    {
        $candidates = [];
        $conflicts = [];
        foreach (DB::table('inventory_items')->whereNull('deleted_at')->orderBy('id')->get() as $item) {
            $assignments = DB::table('inventory_item_warehouses as a')
                ->join('warehouses as w', 'w.id', '=', 'a.warehouse_id')
                ->leftJoin('branches as b', 'b.id', '=', 'w.branch_id')
                ->where('a.tenant_id', $item->tenant_id)->where('a.inventory_item_id', $item->id)
                ->get(['w.branch_id', 'b.branch_type']);
            $factories = $assignments->where('branch_type', 'factory')->pluck('branch_id')->unique()->values();
            if ($factories->isEmpty()) continue;
            if ($factories->count() !== 1 || $assignments->contains(fn ($a) => $a->branch_type !== 'factory')
                || ($item->owner_branch_id !== null && (int) $item->owner_branch_id !== (int) $factories[0])) {
                $conflicts[] = [$item->id, $item->sku, $factories->implode(','), 'Mixed warehouse scopes or existing ownership'];
                continue;
            }
            if ($item->owner_branch_id === null) $candidates[] = [$item->id, $item->sku, (int) $factories[0]];
        }
        $this->table(['Item', 'SKU', 'Factory branch'], $candidates);
        if ($conflicts) $this->table(['Item', 'SKU', 'Factory branches', 'Conflict'], $conflicts);
        $this->line('Candidates: '.count($candidates).'; conflicts: '.count($conflicts));
        if ($conflicts) {
            $this->error('Resolve ownership conflicts manually before applying. No data changed.');
            return self::FAILURE;
        }
        if ($this->option('apply')) {
            DB::transaction(function () use ($candidates): void {
                foreach ($candidates as [$id, $sku, $branch]) {
                    DB::table('inventory_items')->where('id', $id)->whereNull('owner_branch_id')->update(['owner_branch_id' => $branch]);
                }
            });
            $this->info('Ownership assignments applied.');
        } else $this->info('Dry run; no data changed.');
        return self::SUCCESS;
    }
}
