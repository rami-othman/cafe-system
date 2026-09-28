<?php

namespace App\Services;

use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class ShiftClosePreviewService
{
    public const TABLES = ['orders', 'payments', 'payment_refunds', 'shift_cash_movements', 'customer_payments', 'customer_refunds', 'supplier_payments', 'expenses', 'finance_documents', 'cash_transfers', 'stock_counts'];

    public function __construct(
        private readonly ShiftSnapshotService $snapshots,
        private readonly ShiftCashSummaryService $cash,
        private readonly ShiftDrawerReadinessService $readiness,
        private readonly FinancialAccountBalanceQuery $balances,
        private readonly HistoricalBarBalanceService $bar,
        private readonly CashVarianceService $variance,
    ) {}

    public function build(int $tenant, object $shift, ShiftClosePeriod $period): array
    {
        $historical = $period->historical();
        $snapshot = $this->snapshots->buildSnapshot($tenant, $shift, $historical ? $period : null);
        $issues = [];
        $drawer = $shift->financial_location_id ? $this->readiness->drawerLocation($tenant, (int) $shift->branch_id, (int) $shift->financial_location_id) : null;
        $destination = $shift->close_destination_financial_location_id ? $this->readiness->destinationLocation($tenant, (int) $shift->branch_id, (int) $shift->close_destination_financial_location_id) : null;
        if (! $drawer || ! $destination || $drawer->id === $destination->id) {
            $issues[] = __('shifts.close_configuration_missing');
        }
        $ledger = $drawer ? $this->readiness->drawerLedgerBalance($tenant, $drawer) : '0.00';
        $previousLedger = $drawer && $historical ? $this->balances->balanceBefore($tenant, (int) $drawer->financial_account_id, (int) $drawer->id, $period->timestamp()) : $ledger;
        $cash = $this->cash->summarize($tenant, $shift, $historical ? $period : null);
        $expected = $historical ? $previousLedger : $ledger;
        $transfer = Money::cents($expected) - Money::cents($shift->closing_float_amount ?? '0');
        if ($transfer < 0) {
            $issues[] = __('shifts.counted_below_float');
        }
        if ($transfer > Money::cents($ledger)) {
            $issues[] = __('shifts.historical_transfer_insufficient');
        }

        $sources = [];
        $later = [];
        foreach (self::TABLES as $table) {
            $sources[$table] = DB::table($table)->where('tenant_id', $tenant)->where('shift_id', $shift->id)->orderBy('id')->get()->all();
            $later[$table] = $historical ? $this->laterQuery($tenant, (int) $shift->id, $table, $period)->count() : 0;
        }
        if ($historical) {
            foreach (['customer_payments', 'customer_refunds', 'expenses'] as $table) {
                foreach ($sources[$table] as $row) {
                    if ($row->created_at < $period->timestamp() && $row->updated_at >= $period->timestamp()
                        && in_array($row->status, ['reversed', 'cancelled'], true)) {
                        $issues[] = __('shifts.historical_reversed_settlement');
                    }
                }
            }
            if (DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('branch_id', $shift->branch_id)->where('is_active', true)->where('required_for_shift_close', true)->count() > 1) {
                $issues[] = __('shifts.historical_multiple_bars');
            }
            // A payment straddling a single order's lifecycle needs an explicit
            // allocation contract; do not silently orphan its earlier receipts.
            $crossing = DB::table('payments as p')->join('orders as o', 'o.id', '=', 'p.order_id')->where('p.tenant_id', $tenant)->where('p.shift_id', $shift->id);
            $period->before($crossing, 'payments', 'p');
            $period->after($crossing, 'orders', 'o');
            if ($crossing->exists()) {
                $issues[] = __('shifts.historical_split_payment');
            }
            try {
                $snapshot['barCount'] = $this->bar->enrich($tenant, $shift, $period, $snapshot['barCount']);
            } catch (ValidationException $error) {
                foreach ($error->errors() as $messages) {
                    $issues = [...$issues, ...$messages];
                }
                // Never expose today's theoretical quantities as yesterday's.
                $snapshot['barCount']['lines'] = [];
            }
        }
        $snapshot['drawer']['expectedCash'] = $expected;
        $varianceAccount = null;
        try {
            $varianceAccount = $this->variance->account($tenant, (int) $shift->branch_id);
        } catch (ValidationException) {
            // No variance account configured yet; the preview still renders,
            // just without a named destination for the difference.
        }
        $metadata = [
            'closingDate' => $period->date, 'timezone' => $period->timezone,
            'openingDate' => CarbonImmutable::parse($shift->opened_at, 'UTC')->setTimezone($period->timezone)->toDateString(),
            'today' => CarbonImmutable::now('UTC')->setTimezone($period->timezone)->toDateString(),
            'openedAt' => $snapshot['identity']['openedAt'],
            'periodEndExclusive' => $period->end->toIso8601String(), 'historical' => $historical,
            'expectedCash' => $expected, 'ledgerAtPeriodEnd' => $previousLedger,
            'currentLedgerCash' => $ledger,
            'summaryExpectedCash' => $cash['expectedCash'],
            'unexplainedCash' => Money::decimal(Money::cents($expected) - Money::cents($cash['expectedCash'])),
            'laterNetCash' => Money::decimal(Money::cents($ledger) - Money::cents($previousLedger)),
            'transferAmount' => Money::decimal(max(0, $transfer)),
            'continuationCashAfterTransfer' => Money::decimal(Money::cents($ledger) - max(0, $transfer)),
            'destinationName' => $destination->name ?? null,
            'varianceAccountCode' => $varianceAccount->code ?? null,
            'varianceAccountName' => $varianceAccount->name_ar ?? null,
            'laterRecords' => $later, 'willContinue' => $historical && (array_sum($later) > 0 || $transfer > 0),
            'issues' => array_values(array_unique($issues)), 'canClose' => $issues === [],
        ];
        // Include all relevant posted location lines and warehouse movements,
        // not just the shift row timestamp, for stale-preview detection. This
        // only applies to a historical close: for today's close, POS sales and
        // bar movements between opening the preview and confirming it are
        // expected and must not fail the version check.
        $ledgerRows = [];
        $inventoryRows = [];
        if ($historical) {
            $ledgerRows = DB::table('journal_entry_lines as l')->join('journal_entries as j', 'j.id', '=', 'l.journal_entry_id')
                ->where('l.tenant_id', $tenant)->where('l.financial_location_id', $shift->financial_location_id)->orderBy('l.id')
                ->get(['l.*', 'j.status as entry_status', 'j.posted_at as entry_posted_at', 'j.entry_date'])->all();
            $warehouseIds = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('branch_id', $shift->branch_id)->where('is_active', true)->pluck('warehouse_id');
            $inventoryRows = DB::table('stock_movements')->where('tenant_id', $tenant)->whereIn('warehouse_id', $warehouseIds)->orderBy('id')->get()->all();
        }
        $metadata['version'] = hash('sha256', json_encode([$shift, $drawer, $destination, $sources, $snapshot, $metadata, $ledgerRows, $inventoryRows], JSON_THROW_ON_ERROR));

        return ['snapshot' => $snapshot, 'period' => $metadata];
    }

    public function laterQuery(int $tenant, int $shift, string $table, ShiftClosePeriod $period): Builder
    {
        $query = DB::table($table)->where('tenant_id', $tenant)->where('shift_id', $shift);
        if ($table === 'orders') {
            return $query->where(fn ($q) => $period->after($q, $table)->orWhereIn('status', ['draft', 'held']));
        }

        return $period->after($query, $table);
    }
}
