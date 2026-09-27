<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
final class BackfillFactoryRecipeBranches extends Command {
    protected $signature = 'factory:backfill-recipes {--apply}';
    protected $description = 'Preview or assign legacy recipes when exactly one factory branch exists.';
    public function handle(): int {
        $candidates = []; $conflicts = [];
        foreach (DB::table('manufacturing_recipes')->whereNull('branch_id')->get() as $recipe) {
            $ids = DB::table('branches')->where('tenant_id', $recipe->tenant_id)->where('branch_type', 'factory')->whereNull('deleted_at')->pluck('id');
            if ($ids->count() !== 1) { $conflicts[] = [$recipe->id, $recipe->tenant_id, $ids->implode(',')]; continue; }
            $candidates[] = [$recipe->id, (int) $ids->first()];
        }
        $this->info('Candidates: '.count($candidates).'; conflicts: '.count($conflicts));
        if ($conflicts) { $this->table(['recipe', 'tenant', 'factories'], $conflicts); return self::FAILURE; }
        if ($this->option('apply')) DB::transaction(function () use ($candidates) { foreach ($candidates as [$id, $branch]) DB::table('manufacturing_recipes')->where('id', $id)->whereNull('branch_id')->update(['branch_id' => $branch]); });
        return self::SUCCESS;
    }
}
