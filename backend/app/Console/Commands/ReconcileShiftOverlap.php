<?php

namespace App\Console\Commands;

use App\Services\ShiftOverlapReconciliationService;
use Illuminate\Console\Command;

/**
 * Administrative reconciliation of historical overlapping open shifts on one
 * physical cash drawer. Dry-run by default; --apply is required to mutate.
 * See docs/SHIFT_DRAWER_OPERATIONS.md.
 */
final class ReconcileShiftOverlap extends Command
{
    protected $signature = 'shifts:reconcile-overlap
        {tenantId : Tenant id}
        {financialLocationId : Cash drawer financial_location id}
        {--confirmed-cash= : Physically counted drawer cash; must equal the posted drawer ledger balance}
        {--reason= : Why the overlap is being reconciled (required with --apply)}
        {--actor= : User id of the operator performing the reconciliation (required with --apply)}
        {--dry-run : Analyse only (default)}
        {--apply : Actually close the overlapping shifts administratively}';

    protected $description = 'Administratively reconcile legacy overlapping open shifts on one cash drawer (dry-run by default)';

    public function handle(ShiftOverlapReconciliationService $service): int
    {
        if ($this->option('apply') && $this->option('dry-run')) {
            $this->error('Choose either --dry-run or --apply, not both.');

            return self::INVALID;
        }
        $apply = (bool) $this->option('apply');
        $report = $service->reconcile(
            (int) $this->argument('tenantId'),
            (int) $this->argument('financialLocationId'),
            $this->option('confirmed-cash'),
            $this->option('reason'),
            $this->option('actor') !== null ? (int) $this->option('actor') : null,
            $apply,
        );

        $this->line($apply ? 'Mode: APPLY' : 'Mode: DRY-RUN (no changes will be written)');
        $this->line('Drawer: '.json_encode($report['drawer'], JSON_UNESCAPED_UNICODE).' branch='.($report['branchId'] ?? '-'));
        $this->line('Posted drawer ledger balance: '.($report['ledgerBalance'] ?? '-').' | confirmed physical cash: '.($report['confirmedCash'] ?? '-'));
        if ($report['shifts'] !== []) {
            $this->table(['Shift', 'Number', 'Branch', 'User', 'Opened at', 'Opening cash', 'Orders by status', 'Completed payments'], array_map(fn (array $s) => [
                $s['id'], $s['shiftNumber'], $s['branchId'], $s['userId'], $s['openedAt'], $s['openingCash'],
                json_encode($s['orderCounts']), $s['completedPaymentCount'],
            ], $report['shifts']));
        }
        if ($report['activeOrders'] !== []) {
            $this->warn('Active (non-terminal) linked orders:');
            $this->table(['Order', 'Shift', 'Number', 'Status', 'Payment', 'Total'], array_map(fn (array $o) => array_values($o), $report['activeOrders']));
        }
        foreach ($report['blockers'] as $blocker) {
            $this->error("[{$blocker['code']}] {$blocker['message']}");
        }
        if ($report['blockers'] !== []) {
            $this->error('Reconciliation refused. No changes were written.');

            return self::FAILURE;
        }
        if (! $apply) {
            $this->info('Dry run passed. Re-run with --apply --confirmed-cash=... --reason=... --actor=... to close these shifts administratively.');

            return self::SUCCESS;
        }
        $this->info('Reconciled '.count($report['shifts']).' overlapping shift(s) at '.$report['reconciledAt'].' as legacy_reconcile. No cash transfer was created; cash remains in the drawer.');
        $this->info('Next: open a new shift through the normal API with openingCash = '.$report['ledgerBalance'].'.');

        return self::SUCCESS;
    }
}
