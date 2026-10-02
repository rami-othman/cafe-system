<?php

namespace App\Console\Commands;

use App\Services\PartyAccountService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/** Gives every supplier exactly one ledger account, under the suppliers parent. */
final class ConsolidateSupplierAccounts extends Command
{
    protected $signature = 'finance:consolidate-supplier-accounts {tenantId? : Only this tenant} {--apply : Apply the fixes after reviewing the dry run}';

    protected $description = 'One account per supplier under Suppliers: move old customer-side accounts and adopt imported duplicates (dry-run by default)';

    public function handle(PartyAccountService $parties): int
    {
        $tenants = $this->argument('tenantId')
            ? [(int) $this->argument('tenantId')]
            : DB::table('tenants')->pluck('id')->map(fn ($id) => (int) $id)->all();
        $rows = [];
        foreach ($tenants as $tenantId) {
            $rows[] = [$tenantId, $parties->consolidateSuppliers($tenantId, (bool) $this->option('apply'))];
        }
        $this->table(['Tenant', $this->option('apply') ? 'Suppliers fixed' : 'Suppliers to fix'], $rows);
        if (! $this->option('apply')) {
            $this->info('Dry run only. Use --apply to fix them.');
        }

        return self::SUCCESS;
    }
}
