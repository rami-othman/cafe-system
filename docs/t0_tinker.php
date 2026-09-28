<?php
/**
 * T0 bullet 5 — read-only. Paste into `php artisan tinker` (or pipe it in:
 * `php artisan tinker < docs/t0_tinker.php`) on the production server.
 *
 * For every open shift: compares ShiftCashSummaryService::summarize()'s
 * expectedCash against ShiftDrawerReadinessService::drawerLedgerBalance()
 * and prints the difference, plus any journal_entry_lines posted on that
 * drawer's financial_location_id since the shift opened whose source_type
 * is not one of the shift's own known cash-movement sources and that
 * aren't this shift's own close/continuation transfer.
 *
 * Does not save/update/delete anything.
 */

use App\Services\ShiftCashSummaryService;
use App\Services\ShiftDrawerReadinessService;
use App\Support\Money;
use Illuminate\Support\Facades\DB;

// Actual AccountingPostingService::post* source types that legitimately move
// a shift's own drawer (see app/Services/AccountingPostingService.php).
// Note: there is no 'sale' or 'refund' source_type in this codebase — sales
// post as 'pos_order' and refunds as 'payment_refund'.
$knownShiftCashSourceTypes = [
    'pos_order',
    'payment_refund',
    'expense',
    'customer_payment',
    'customer_refund',
    'supplier_payment',
];

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

    $diffCents = $drawer ? Money::cents($ledgerBalance) - Money::cents($expectedFromSummary) : null;
    $diff = $diffCents !== null ? Money::decimal($diffCents) : null;

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

    if ($diffCents !== null && $diffCents !== 0) {
        $shiftCashTransferIds = DB::table('cash_transfers')
            ->where('tenant_id', $tenantId)
            ->where('shift_id', $shift->id)
            ->pluck('id');

        $unexplained = DB::table('journal_entry_lines as l')
            ->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')
            ->where('l.tenant_id', $tenantId)
            ->where('l.financial_location_id', $locationId)
            ->where('e.status', 'posted')
            ->where('e.created_at', '>=', $shift->opened_at)
            ->whereNotIn('e.source_type', $knownShiftCashSourceTypes)
            ->where(function ($q) use ($shiftCashTransferIds) {
                $q->where('e.source_type', '<>', 'cash_transfer')
                    ->orWhereNotIn('e.source_id', $shiftCashTransferIds->all() ?: [0]);
            })
            ->select('e.id', 'e.source_type', 'e.source_id', 'e.description', 'l.debit', 'l.credit', 'e.entry_date')
            ->limit(30)
            ->get();

        if ($unexplained->isNotEmpty()) {
            echo "  حركات على الصندوق منذ فتح الوردية غير مفسّرة بمصادرها المعروفة (أول 30):\n";
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
