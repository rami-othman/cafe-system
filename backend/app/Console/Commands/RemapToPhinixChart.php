<?php

namespace App\Console\Commands;

use App\Services\PhinixRemapService;
use Illuminate\Console\Command;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

final class RemapToPhinixChart extends Command
{
    protected $signature = 'finance:remap-to-phinix {tenantId} {--apply : Write the changes (dry run otherwise)} {--balances : Also move the legacy account balances with one journal entry} {--date= : Entry date for the balance transfer (default today)}';

    protected $description = 'Re-point a phinix-chart tenant from the legacy seeded accounts to the new chart; dry-run by default';

    public function handle(PhinixRemapService $service): int
    {
        $tenantId = (int) $this->argument('tenantId');
        if (! DB::table('tenants')->where('id', $tenantId)->exists()) {
            $this->error('The tenant does not exist.');

            return self::FAILURE;
        }
        $apply = (bool) $this->option('apply');
        try {
            $report = $service->remapConfiguration($tenantId, $apply);
            $this->table(array_keys($report), [array_values($report)]);
            if ($this->option('balances')) {
                $ownerId = DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
                $result = $service->transferBalances(Request::create('/'), $tenantId, $apply, $this->option('date') ?: null, $ownerId ? (int) $ownerId : null);
                $this->info(count($result['lines']) / 2 .' balance move(s)'.($result['entryId'] ? " posted in journal entry #{$result['entryId']}" : ' (not posted)'));
                foreach ($result['lines'] as $line) {
                    $this->line(sprintf('  %s  dr %s  cr %s', $line['accountCode'], $line['debit'], $line['credit']));
                }
            }
            $this->info($apply ? 'Applied.' : 'Dry run only. Use --apply (back up the database first).');

            return self::SUCCESS;
        } catch (RuntimeException $error) {
            $this->error($error->getMessage());

            return self::FAILURE;
        }
    }
}
