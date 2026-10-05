<?php

namespace App\Console\Commands;

use App\Services\PhinixHistoryConsolidation;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use RuntimeException;

final class ConsolidatePhinixHistory extends Command
{
    protected $signature = 'finance:consolidate-phinix-history {tenantId} {--plan= : JSON file mapping service voucher IDs to reviewed account codes} {--apply} {--expect= : Fingerprint from dry run} {--backup= : Existing pg_dump archive}';

    protected $description = 'Consolidate restored LOCAL Phinix history with exact balance checks and a full before-state audit';

    public function handle(PhinixHistoryConsolidation $service): int
    {
        try {
            $connection = DB::connection();
            if (! app()->environment('local') || $connection->getDriverName() !== 'pgsql'
                || ! in_array($connection->getConfig('host'), ['postgres', '127.0.0.1', 'localhost', '::1'], true)
                || $connection->getConfig('url')) {
                throw new RuntimeException('This command only supports the local PostgreSQL restore. Remote/production execution is disabled.');
            }
            $planPath = $this->option('plan');
            if (! $planPath || ! is_file($planPath)) {
                throw new RuntimeException('Provide a reviewed --plan JSON file.');
            }
            $plan = json_decode(file_get_contents($planPath), true, 512, JSON_THROW_ON_ERROR);
            if (! is_array($plan) || ! isset($plan['serviceDocuments']) || ! is_array($plan['serviceDocuments'])) {
                throw new RuntimeException('Plan must contain serviceDocuments.');
            }
            $backupHash = null;
            if ($this->option('apply')) {
                $path = $this->option('backup');
                if (! $path || ! is_file($path) || file_get_contents($path, false, null, 0, 5) !== 'PGDMP') {
                    throw new RuntimeException('Provide a PostgreSQL custom-format --backup archive.');
                }
                $backupHash = hash_file('sha256', $path);
            }
            $result = $service->run((int) $this->argument('tenantId'), $plan['serviceDocuments'], (bool) $this->option('apply'), $this->option('expect'), $backupHash);
            $this->line(json_encode($result, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));

            return self::SUCCESS;
        } catch (\Throwable $exception) {
            $this->error($exception->getMessage());

            return self::FAILURE;
        }
    }
}
