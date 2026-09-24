<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The canonical shift-close primitives shared by the manual close endpoint and
 * AutomaticShiftCloseService. There is exactly one accounting algorithm:
 *
 *   ShiftCashSummaryService (expected cash)
 *   -> ShiftCloseTransferService (drawer == ledger, counted - float, one transfer)
 *   -> one shift update (status, close type, close_transfer_id)
 *
 * Callers own the surrounding DB transaction and must pass a shift row that
 * they locked FOR UPDATE inside it, so the transfer and the status change
 * commit or roll back together.
 */
final class ShiftCloseService
{
    public const TYPE_MANUAL = 'manual';

    public const TYPE_AUTOMATIC = 'automatic';

    public const TYPE_LEGACY_RECONCILE = 'legacy_reconcile';

    public function __construct(
        private readonly ShiftCashSummaryService $cashSummary,
        private readonly ShiftCloseTransferService $transfers,
    ) {}

    /** Locks a tenant's shift row (live rows only) inside the caller's transaction. */
    public function lock(int $tenantId, int $shiftId): ?object
    {
        return DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shiftId)
            ->whereNull('deleted_at')->lockForUpdate()->first();
    }

    public function assertRequiredBarChecksComplete(int $tenantId, object $shift): void
    {
        $pending = DB::table('bar_check_templates as t')
            ->where('t.tenant_id', $tenantId)->where('t.branch_id', $shift->branch_id)
            ->where('t.is_active', true)->where('t.required_for_shift_close', true)
            ->whereNotExists(fn ($query) => $query->selectRaw('1')->from('stock_counts as c')
                ->whereColumn('c.bar_check_template_id', 't.id')->where('c.shift_id', $shift->id)
                ->where('c.status', 'posted'))
            ->exists();
        if ($pending) {
            throw ValidationException::withMessages(['barCheck' => __('shifts.bar_check_required')]);
        }
    }

    /**
     * Closes a locked, open shift.
     *
     * Manual: $countedCash is the physical count and must equal expected cash
     * (no approved variance policy exists), it is stored as closing_cash.
     * Automatic: no physical count exists; the expected cash is what the
     * drawer ledger must hold, and closing_cash stays NULL so reports can tell
     * an unattended expected close from a counted one.
     *
     * @param  array<string, mixed>  $extra  additional non-financial shift columns (notes, reasons)
     */
    public function close(Request $request, int $tenantId, object $shift, string $closeType, ?string $countedCash, array $extra = []): object
    {
        if ($shift->status !== 'open') {
            throw ValidationException::withMessages(['shift' => __('shifts.shift_not_open')]);
        }
        $this->assertRequiredBarChecksComplete($tenantId, $shift);
        $summary = $this->cashSummary->summarize($tenantId, $shift);
        $expectedCents = Money::cents($summary['expectedCash']);

        if ($closeType === self::TYPE_MANUAL) {
            $countedCents = Money::cents((string) $countedCash, 'closingCash');
            if ($countedCents !== $expectedCents) {
                throw ValidationException::withMessages(['closingCash' => __('shifts.counted_differs_from_expected')]);
            }
            $actorType = 'user';
        } elseif ($closeType === self::TYPE_AUTOMATIC) {
            $countedCents = $expectedCents;
            $actorType = 'system';
        } else {
            throw new \InvalidArgumentException("Unsupported shift close type [{$closeType}].");
        }

        $transferId = $this->transfers->create($request, $tenantId, $shift, $countedCents, $actorType);
        if (! $shift->shift_number) {
            $this->lockShiftNumbering($tenantId);
        }
        $number = $shift->shift_number ?: $this->nextShiftNumber($tenantId, now()->toDateString());
        $now = now();
        DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shift->id)->where('status', 'open')->update($extra + [
            'shift_number' => $number,
            'report_number' => $shift->report_number ?: 'RPT-'.str_replace('SH-', '', $number),
            'closing_cash' => $closeType === self::TYPE_MANUAL ? Money::decimal($countedCents) : null,
            'expected_cash' => $summary['expectedCash'],
            'cash_difference' => '0.00',
            'close_type' => $closeType,
            'close_transfer_id' => $transferId,
            'status' => 'closed',
            'closed_at' => $now,
            'updated_at' => $now,
        ]);

        return DB::table('shifts')->where('id', $shift->id)->first();
    }

    /**
     * Tenant/day shift number. Callers inside a transaction that insert a shift
     * must hold lockShiftNumbering() first so two drawers opening at the same
     * moment cannot mint the same number.
     */
    public function nextShiftNumber(int $tenantId, string $date): string
    {
        $count = DB::table('shifts')->where('tenant_id', $tenantId)->whereDate('opened_at', $date)->count() + 1;
        $number = sprintf('SH-%s-%03d', str_replace('-', '', $date), $count);
        while (DB::table('shifts')->where('tenant_id', $tenantId)->where('shift_number', $number)->exists()) {
            $number = sprintf('SH-%s-%03d', str_replace('-', '', $date), ++$count);
        }

        return $number;
    }

    /** A transaction-scoped numbering lock that does not block drawer or tenant rows. */
    public function lockShiftNumbering(int $tenantId): void
    {
        if (DB::connection()->getDriverName() === 'pgsql') {
            DB::statement('SELECT pg_advisory_xact_lock(?, ?)', [0x5348, $tenantId]);
        }
    }
}
