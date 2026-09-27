<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
final class SetupFactoryInternalParties extends Command {
    protected $signature = 'factory:setup-internal-parties {--apply}';
    protected $description = 'Preview or create independent internal factory/cafe counterparties.';
    public function handle(): int {
        $plans = [];
        foreach (DB::table('branches')->where('branch_type', 'factory')->whereNull('deleted_at')->get() as $factory) foreach (DB::table('branches')->where('tenant_id', $factory->tenant_id)->where('branch_type', 'cafe')->whereNull('deleted_at')->get() as $cafe) {
            if (! DB::table('customers')->where('tenant_id', $factory->tenant_id)->where('owner_branch_id', $factory->id)->where('is_internal', true)->where('internal_branch_id', $cafe->id)->whereNull('deleted_at')->exists()) $plans[] = ['customers', $factory->tenant_id, $factory->id, $cafe->id, $cafe->name];
            if (! DB::table('suppliers')->where('tenant_id', $factory->tenant_id)->whereNull('owner_branch_id')->where('is_internal', true)->where('internal_branch_id', $factory->id)->whereNull('deleted_at')->exists() && ! collect($plans)->contains(fn ($p) => $p[0] === 'suppliers' && $p[1] === $factory->tenant_id && $p[3] === $factory->id)) $plans[] = ['suppliers', $factory->tenant_id, null, $factory->id, $factory->name];
        }
        $this->table(['table', 'tenant', 'scope', 'represents branch', 'name'], $plans); $this->info('Candidates: '.count($plans));
        if ($this->option('apply')) DB::transaction(function () use ($plans) { foreach ($plans as [$table, $tenant, $owner, $branch, $name]) {
            DB::table('tenants')->where('id', $tenant)->lockForUpdate()->first();
            $values = ['tenant_id' => $tenant, 'owner_branch_id' => $owner, 'is_internal' => true, 'internal_branch_id' => $branch, 'name' => $name, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()];
            if ($table === 'customers') $values += ['customer_number' => 'INT-F'.$owner.'-C'.$branch, 'normalized_name' => \App\Domain\Customer\CustomerNameNormalizer::normalize($name)['normalizedName'], 'customer_type' => 'registered', 'is_walk_in' => false, 'is_system_protected' => false, 'default_credit_terms_days' => 30, 'total_spent' => 0, 'visits_count' => 0];
            else $values += ['supplier_number' => 'INT-F'.$branch, 'payment_terms_days' => 30];
            DB::table($table)->insert($values);
        } });
        return self::SUCCESS;
    }
}
