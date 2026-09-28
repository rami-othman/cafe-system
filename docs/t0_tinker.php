<?php
/**
 * T0 bullet 5 — read-only. Paste into `php artisan tinker` (or pipe it in:
 * `php artisan tinker < docs/t0_tinker.php`) on the production server.
 *
 * For every open shift: compares ShiftCashSummaryService::summarize()'s
 * expectedCash against ShiftDrawerReadinessService::drawerLedgerBalance()
 * and prints the difference, plus any journal_entry_lines posted on that
 * drawer's financial_location_id since the shift opened that are not tied
 * to this shift as their source (i.e. cash movement the shift's own
 * summary never saw).
 *
 * Does not save/update/delete anything.
 */

use App\Services\ShiftCashSummaryService;
use App\Services\ShiftDrawerReadinessService;
use Illuminate\Support\Facades\DB;

$cashSummary = app(ShiftCashSummaryService::class);
$readiness = app(ShiftDrawerReadinessService::class);

$openShifts = DB::table('shifts')->where('status', 'open')->whereNull('deleted_at')->orderBy('id')->get();

echo "== Open shifts: {$openShifts->count()} ==\n";

foreach ($openShifts as $shift) {
    $tenantId = (int) $shift->tenant_id;
    $branchId = (int) $shift->branch_id;
    $locationId = (int) $shift->financial_location_id;

    $summary = $cashSummary->summarize($tenantId, $shift);
    $expectedFromSummary = $summary['expectedCash'];

    $drawer = $readiness->drawerLocation($tenantId, $branchId, $locationId);
    $ledgerBalance = $drawer ? $readiness->drawerLedgerBalance($tenantId, $drawer) : null;

    $diff = $drawer ? bcsub($ledgerBalance, $expectedFromSummary, 2) : null;

    echo sprintf(
        "shift #%s (id=%d, branch=%d, location=%d): expectedCash(summary)=%s  drawerLedgerBalance=%s  diff=%s\n",
        $shift->shift_number ?? '?',
        $shift->id,
        $branchId,
        $locationId,
        $expectedFromSummary,
        $ledgerBalance ?? 'N/A (no drawer location found)',
        $diff ?? 'N/A'
    );

    if ($diff !== null && bccomp($diff, '0.00', 2) !== 0) {
        $unexplained = DB::table('journal_entry_lines as l')
            ->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')
            ->where('l.tenant_id', $tenantId)
            ->where('l.financial_location_id', $locationId)
            ->where('e.status', 'posted')
            ->where('e.created_at', '>=', $shift->opened_at)
            ->where(function ($q) use ($shift) {
                $q->where('e.source_type', '<>', 'shift_close')
                    ->orWhere('e.source_id', '<>', $shift->id);
            })
            ->select('e.id', 'e.source_type', 'e.source_id', 'e.description', 'l.debit', 'l.credit', 'e.entry_date')
            ->get();

        if ($unexplained->isNotEmpty()) {
            echo "  حركات على الصندوق منذ فتح الوردية وغير مرتبطة بها كمصدر:\n";
            foreach ($unexplained as $line) {
                echo sprintf(
                    "    entry #%d [%s#%s] %s — debit=%s credit=%s (%s)\n",
                    $line->id,
                    $line->source_type,
                    $line->source_id,
                    $line->description,
                    $line->debit,
                    $line->credit,
                    $line->entry_date
                );
            }
        }
    }
}

echo "== done ==\n";
