<?php

namespace App\Console\Commands;

use App\Services\LegacyShiftCloseConfigurationAdoptionService;
use Illuminate\Console\Command;

/**
 * Lets one legacy open shift (no close destination snapshot) adopt the
 * branch's current validated close configuration. Creates no financial
 * entries. Dry-run by default; --apply is required to mutate.
 */
final class AdoptLegacyShiftCloseConfiguration extends Command
{
    protected $signature = 'shifts:adopt-close-config
        {tenantId : Tenant id}
        {shiftId : Legacy open shift id}
        {--reason= : Why the configuration is being adopted (required with --apply)}
        {--actor= : User id of the operator (required with --apply)}
        {--dry-run : Analyse only (default)}
        {--apply : Copy the validated close destination / closing float onto the shift}';

    protected $description = 'Adopt the current branch close configuration for a legacy open shift (dry-run by default)';

    public function handle(LegacyShiftCloseConfigurationAdoptionService $service): int
    {
        if ($this->option('apply') && $this->option('dry-run')) {
            $this->error('Choose either --dry-run or --apply, not both.');

            return self::INVALID;
        }
        $apply = (bool) $this->option('apply');
        $report = $service->adopt(
            (int) $this->argument('tenantId'),
            (int) $this->argument('shiftId'),
            $this->option('reason'),
            $this->option('actor') !== null ? (int) $this->option('actor') : null,
            $apply,
        );
        $this->line($apply ? 'Mode: APPLY' : 'Mode: DRY-RUN (no changes will be written)');
        $this->line('Shift: '.json_encode($report['shift'], JSON_UNESCAPED_UNICODE));
        $this->line('Configuration to adopt: '.json_encode($report['adopted'], JSON_UNESCAPED_UNICODE));
        foreach ($report['blockers'] as $blocker) {
            $this->error("[{$blocker['code']}] {$blocker['message']}");
        }
        if ($report['blockers'] !== []) {
            $this->error('Adoption refused. No changes were written.');

            return self::FAILURE;
        }
        $this->info($apply ? 'Close configuration adopted and audited. No financial entries were created.' : 'Dry run passed. Re-run with --apply --reason=... --actor=... to adopt.');

        return self::SUCCESS;
    }
}
