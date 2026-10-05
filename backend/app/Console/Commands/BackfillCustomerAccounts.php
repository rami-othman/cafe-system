<?php

namespace App\Console\Commands;

use App\Services\CustomerAccountBackfill;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use RuntimeException;

final class BackfillCustomerAccounts extends Command
{
    protected $signature = 'finance:backfill-customer-accounts {tenantId} {--apply} {--backup= : Existing local pg_dump custom-format archive}';

    protected $description = 'Preview or complete missing registered-customer account links on a local Phinix restore';

    public function handle(CustomerAccountBackfill $service): int
    {
        try {
            $connection = DB::connection();
            if (! app()->environment('local') || $connection->getDriverName() !== 'pgsql' || $connection->getConfig('url')
                || ! in_array($connection->getConfig('host'), ['postgres', 'localhost', '127.0.0.1', '::1'], true)) {
                throw new RuntimeException('Only the local PostgreSQL restore is supported; remote execution is disabled.');
            }
            $backupHash = null;
            if ($this->option('apply')) {
                $path = $this->option('backup');
                if (! $path || ! is_file($path) || file_get_contents($path, false, null, 0, 5) !== 'PGDMP') {
                    throw new RuntimeException('Provide the local pg_dump archive with --backup.');
                }
                $backupHash = hash_file('sha256', $path);
            }
            $report = $service->run((int) $this->argument('tenantId'), (bool) $this->option('apply'), $backupHash);
            $this->line(json_encode($report, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));

            return self::SUCCESS;
        } catch (\Throwable $error) {
            $this->error($error->getMessage());

            return self::FAILURE;
        }
    }
}
