<?php

namespace App\Services;

use App\Domain\Inventory\UnitConversionResolver;
use App\Support\InventoryDecimal;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Atomic period split. No operational document or journal is re-posted. */
final class HistoricalShiftCloseService
{
    public function __construct(
        private readonly ShiftClosePreviewService $previews,
        private readonly ShiftCloseService $closer,
        private readonly ShiftCloseTransferService $transfers,
        private readonly CashVarianceService $variance,
        private readonly StockCountService $counts,
        private readonly HistoricalBarBalanceService $bar,
        private readonly UnitConversionResolver $conversions,
        private readonly OperationalAuditService $audit,
    ) {}

    /**
     * Historical reassignment writes domain rows, unlike normal closing.
     * Drain existing operational writers BEFORE locking the shift, because
     * those writers lock their order/document before its shift. PostgreSQL
     * table locks give a short, transaction-scoped barrier without requiring
     * existing clients to know a new advisory-lock convention.
     */
    public function lockInputs(): void
    {
        if (DB::connection()->getDriverName() === 'pgsql') {
            DB::statement("SET LOCAL lock_timeout = '5s'");
            DB::statement('LOCK TABLE branches, financial_locations, shifts, orders, payments, payment_refunds, shift_cash_movements, customer_payments, customer_refunds, supplier_payments, expenses, finance_documents, cash_transfers, journal_entries, journal_entry_lines, bar_check_templates, bar_check_template_lines, inventory_items, inventory_item_unit_conversions, stock_counts, stock_count_lines, stock_balances, stock_movements IN SHARE ROW EXCLUSIVE MODE');
        }
    }

    public function requestIdentity(array $data): array
    {
        $lines = array_map(fn ($line) => ['inventoryItemId' => (int) $line['inventoryItemId'], 'counted' => InventoryDecimal::quantity(InventoryDecimal::units($line['counted'])), 'reason' => trim($line['reason'] ?? '')], $data['barCountLines'] ?? []);
        usort($lines, fn ($a, $b) => $a['inventoryItemId'] <=> $b['inventoryItemId']);

        return [
            'closingDate' => $data['closingDate'] ?? null, 'closingCash' => Money::decimal(Money::cents($data['closingCash'])),
            'cashCountBasis' => $data['cashCountBasis'] ?? null, 'barCountBasis' => $data['barCountBasis'] ?? null,
            'barCountLines' => $lines, 'note' => $data['note'] ?? null,
            'cashDifferenceReason' => $data['cashDifferenceReason'] ?? null,
            'cashDifferenceReasonDetail' => $data['cashDifferenceReasonDetail'] ?? null,
        ];
    }

    public function assertSameRetry(object $shift, array $data): void
    {
        if (json_decode($shift->close_request, true, 512, JSON_THROW_ON_ERROR) !== $this->requestIdentity($data)) {
            throw ValidationException::withMessages(['closingDate' => __('shifts.historical_retry_changed')]);
        }
    }

    public function close(Request $request, int $tenant, object $shift, ShiftClosePeriod $period, array $data): object
    {
        if (empty($data['previewVersion'])) {
            throw ValidationException::withMessages(['closingDate' => __('shifts.historical_preview_required')]);
        }
        foreach (['cashCountBasis', 'barCountBasis'] as $field) {
            if (! in_array($data[$field] ?? null, ['period_recorded', 'current'], true)) {
                throw ValidationException::withMessages([$field => __('shifts.historical_invalid_basis')]);
            }
        }
        $preview = $this->previews->build($tenant, $shift, $period);
        if (! hash_equals($preview['period']['version'], $data['previewVersion'])) {
            throw ValidationException::withMessages(['previewVersion' => __('shifts.historical_preview_changed')]);
        }
        if (! $preview['period']['canClose']) {
            throw ValidationException::withMessages(['closingDate' => $preview['period']['issues']]);
        }

        $metadata = $preview['period'];
        $expected = Money::cents($metadata['expectedCash']);
        $counted = Money::cents($data['closingCash']);
        if ($data['cashCountBasis'] === 'current') {
            $counted -= Money::cents($metadata['laterNetCash']);
        }
        $differenceCents = $counted - $expected;
        if ($differenceCents !== 0 && empty($data['cashDifferenceReason'])) {
            throw ValidationException::withMessages(['cashDifferenceReason' => __('shifts.difference_reason_required')]);
        }
        $snapshot = $preview['snapshot'];
        if (! $shift->shift_number) {
            $this->closer->lockShiftNumbering($tenant);
            $shift->shift_number = $this->closer->nextShiftNumber($tenant, CarbonImmutable::parse($shift->opened_at, 'UTC')->toDateString());
            $snapshot['identity']['shiftNumber'] = $shift->shift_number;
        }
        $varianceEntryId = $this->variance->post($request, $tenant, (int) $shift->branch_id, (int) $shift->financial_location_id,
            $differenceCents, $period->date, 'shift_cash_variance', (int) $shift->id,
            'فرق صندوق الوردية '.$shift->shift_number, (int) $shift->user_id);
        $this->submitCounts($request, $tenant, $shift, $period, $data, $snapshot);
        $this->closer->assertRequiredBarChecksComplete($tenant, $shift);

        $closedAt = $period->end->subSecond()->format('Y-m-d H:i:s');
        // Release the unique open-drawer constraint within the transaction.
        DB::table('shifts')->where('tenant_id', $tenant)->where('id', $shift->id)->update([
            'status' => 'closed', 'close_type' => ShiftCloseService::TYPE_MANUAL, 'shift_number' => $shift->shift_number,
            'closing_cash' => Money::decimal($counted), 'expected_cash' => Money::decimal($expected), 'cash_difference' => Money::decimal($differenceCents),
            'cash_variance_journal_entry_id' => $varianceEntryId,
            'closed_at' => $closedAt, 'close_executed_at' => now(), 'business_date' => $period->date,
            'period_end_exclusive' => $period->timestamp(), 'cash_count_basis' => $data['cashCountBasis'], 'bar_count_basis' => $data['barCountBasis'],
            'notes' => $data['note'] ?? $shift->notes, 'report_number' => $shift->report_number ?: 'RPT-'.str_replace('SH-', '', $shift->shift_number),
            'cash_difference_reason' => $data['cashDifferenceReason'] ?? null,
            'cash_difference_reason_detail' => $data['cashDifferenceReasonDetail'] ?? null,
            'close_request' => json_encode($this->requestIdentity($data), JSON_THROW_ON_ERROR), 'updated_at' => now(),
        ]);

        $continuation = null;
        if ($metadata['willContinue']) {
            $this->closer->lockShiftNumbering($tenant);
            $continuation = (int) DB::table('shifts')->insertGetId([
                'tenant_id' => $tenant, 'branch_id' => $shift->branch_id, 'user_id' => $shift->user_id,
                'financial_location_id' => $shift->financial_location_id, 'close_destination_financial_location_id' => $shift->close_destination_financial_location_id,
                'closing_float_amount' => $shift->closing_float_amount, 'float_amount' => $shift->float_amount, 'opening_cash' => Money::decimal($counted),
                'shift_number' => $this->closer->nextShiftNumber($tenant, $period->end->setTimezone($period->timezone)->toDateString()),
                'status' => 'open', 'opened_at' => $period->timestamp(), 'continuation_of_shift_id' => $shift->id,
                'notes' => 'استمرار الوردية '.$shift->shift_number, 'created_at' => now(), 'updated_at' => now(),
            ]);
            foreach (ShiftClosePreviewService::TABLES as $table) {
                $query = $this->previews->laterQuery($tenant, (int) $shift->id, $table, $period);
                // Newly created historical counts are attached to the closing
                // period even though their actual posting happened today.
                if ($table === 'stock_counts') {
                    $query->where(fn ($q) => $q->whereNull('period_end_exclusive')->orWhere('period_end_exclusive', '!=', $period->timestamp()));
                }
                $ids = $query->pluck('id');
                foreach ($ids as $id) {
                    DB::table('shift_period_reassignments')->insert([
                        'tenant_id' => $tenant, 'from_shift_id' => $shift->id, 'to_shift_id' => $continuation,
                        'record_table' => $table, 'record_id' => $id, 'created_by' => $shift->user_id, 'created_at' => now(),
                    ]);
                }
                DB::table($table)->where('tenant_id', $tenant)->whereIn('id', $ids)->update(['shift_id' => $continuation]);
            }
        }
        $transfer = $this->transfers->create($request, $tenant, $shift, $counted, 'user',
            $period->date, Money::cents($metadata['currentLedgerCash']) + $differenceCents, $continuation);
        if ($continuation && $transfer) {
            DB::table('shift_cash_movements')->insert([
                'tenant_id' => $tenant, 'branch_id' => $shift->branch_id, 'shift_id' => $continuation,
                'kind' => 'withdrawal', 'amount' => Money::decimal(max(0, $counted - Money::cents($shift->closing_float_amount))),
                'description' => 'تحويل إغلاق الوردية '.$shift->shift_number,
                'source_type' => 'historical_shift_close_transfer', 'source_id' => $transfer,
                'created_by' => $shift->user_id, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
        $metadata['transferAmount'] = Money::decimal(max(0, $counted - Money::cents($shift->closing_float_amount)));
        $snapshot['identity']['lifecycle'] = 'closed';
        $snapshot['identity']['closedAt'] = $period->end->subSecond()->toIso8601String();
        $snapshot['identity']['closedBy'] = $snapshot['identity']['cashierName'];
        $snapshot['pendingOperations'] = [];
        $snapshot['period'] = $metadata + ['continuationShiftId' => $continuation, 'cashCountBasis' => $data['cashCountBasis'], 'barCountBasis' => $data['barCountBasis'], 'closeExecutedAt' => now()->toIso8601String()];
        DB::table('shifts')->where('tenant_id', $tenant)->where('id', $shift->id)->update(['close_transfer_id' => $transfer, 'close_snapshot' => json_encode($snapshot, JSON_THROW_ON_ERROR)]);
        $this->audit->record($request, $tenant, 'shift.historical_closed', 'shift', (int) $shift->id,
            ['status' => 'open'], ['businessDate' => $period->date, 'continuationShiftId' => $continuation, 'transferId' => $transfer, 'period' => $metadata], (int) $shift->branch_id, (int) $shift->user_id);

        return DB::table('shifts')->where('id', $shift->id)->first();
    }

    private function submitCounts(Request $request, int $tenant, object $shift, ShiftClosePeriod $period, array $data, array &$snapshot): void
    {
        $inputs = collect($data['barCountLines'] ?? [])->keyBy('inventoryItemId');
        $templates = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('branch_id', $shift->branch_id)->where('is_active', true)->where('required_for_shift_close', true)->get();
        foreach ($templates as $template) {
            $count = $this->counts->startBarCheck($request, $tenant, (int) $shift->id, (int) $template->warehouse_id, (int) $shift->user_id, $period, $data['barCountBasis']);
            $lines = DB::table('stock_count_lines')->where('tenant_id', $tenant)->where('stock_count_id', $count)->get();
            foreach ($lines as $line) {
                $input = $inputs->get($line->inventory_item_id);
                if (! $input) {
                    if ($line->is_required) {
                        throw ValidationException::withMessages(['barCountLines' => __('shifts.bar_check_required')]);
                    }

                    continue;
                }
                $quantity = $input['counted'];
                if ($data['barCountBasis'] === 'current') {
                    $item = DB::table('inventory_items')->where('tenant_id', $tenant)->where('id', $line->inventory_item_id)->first();
                    $converted = $this->conversions->resolve($tenant, $item, $quantity, $line->entered_unit);
                    $base = $converted['baseQuantity'] - $this->bar->quantities($tenant, (int) $template->warehouse_id, (int) $line->inventory_item_id, $period)['later'];
                    if ($base < 0) {
                        throw ValidationException::withMessages(['barCountLines' => __('shifts.historical_bar_incomplete')]);
                    }
                    $numerator = $base * 1000000;
                    if ($numerator % $converted['factor'] !== 0) {
                        throw ValidationException::withMessages(['barCountLines' => __('shifts.historical_bar_incomplete')]);
                    }
                    $quantity = InventoryDecimal::quantity(intdiv($numerator, $converted['factor']));
                }
                $this->counts->upsertLine($tenant, $count, ['itemId' => $line->inventory_item_id, 'countedQuantity' => (string) $quantity, 'reason' => $input['reason'] ?? null], (int) $shift->user_id);
                $snapshot['barCount']['lines'] = collect($snapshot['barCount']['lines'])->map(function ($entry) use ($line, $quantity) {
                    if ((int) $entry['id'] === (int) $line->inventory_item_id) {
                        $entry['counted'] = $quantity;
                    }

                    return $entry;
                })->all();
            }
            $this->counts->transition($request, $tenant, $count, 'submit', (int) $shift->user_id);
            $this->counts->transition($request, $tenant, $count, 'approve', (int) $shift->user_id);
            $this->counts->transition($request, $tenant, $count, 'post', (int) $shift->user_id);
            $snapshot['barCount']['lastCountedAt'] = now()->toIso8601String();
        }
    }
}
