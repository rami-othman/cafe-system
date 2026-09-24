<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Creates the one close transfer for a locked, open shift inside its closing
 * transaction. It validates the shift's *snapshotted* drawer/destination with
 * the canonical ShiftDrawerReadinessService rules, requires the counted drawer
 * cash to equal the location-specific posted ledger balance, and moves
 * (counted - closing float) from the drawer to the destination under the
 * idempotency key `shift-close-transfer:{shiftId}`.
 */
final class ShiftCloseTransferService
{
    public function __construct(
        private readonly CashTransferService $transfers,
        private readonly ShiftDrawerReadinessService $readiness,
    ) {}

    public static function idempotencyKey(int $shiftId): string
    {
        return 'shift-close-transfer:'.$shiftId;
    }

    public function create(Request $request, int $tenantId, object $shift, int $countedCents, string $actorType): ?int
    {
        $floatCents = Money::cents($shift->closing_float_amount ?? '0');
        if ($floatCents < 0 || $countedCents < 0 || $countedCents < $floatCents) {
            throw ValidationException::withMessages(['closingCash' => __('shifts.counted_below_float')]);
        }
        if (! $shift->financial_location_id || ! $shift->close_destination_financial_location_id) {
            throw ValidationException::withMessages(['destination' => __('shifts.close_configuration_missing')]);
        }

        $source = $this->readiness->drawerLocation($tenantId, (int) $shift->branch_id, (int) $shift->financial_location_id, true);
        $destination = $this->readiness->destinationLocation($tenantId, (int) $shift->branch_id, (int) $shift->close_destination_financial_location_id, true);
        if (! $source || ! $destination || (int) $source->id === (int) $destination->id) {
            throw ValidationException::withMessages(['destination' => __('shifts.close_destination_invalid')]);
        }

        // A shift has at most one close transfer. The idempotency key already
        // guarantees this; the explicit check keeps a corrupted/partial state
        // from ever producing a second movement.
        $existing = DB::table('cash_transfers')->where('tenant_id', $tenantId)
            ->where('idempotency_key', self::idempotencyKey((int) $shift->id))->first();
        if ($existing) {
            throw ValidationException::withMessages(['closingCash' => __('shifts.close_transfer_exists')]);
        }

        $ledgerCents = Money::cents($this->readiness->drawerLedgerBalance($tenantId, $source));
        if ($ledgerCents !== $countedCents) {
            throw ValidationException::withMessages(['closingCash' => __('shifts.drawer_ledger_mismatch')]);
        }

        $amount = $countedCents - $floatCents;
        if ($amount === 0) {
            return null;
        }

        $transfer = $this->transfers->create($request, $tenantId, [
            'branchId' => (int) $shift->branch_id,
            'fromFinancialLocationId' => (int) $source->id,
            'toFinancialLocationId' => (int) $destination->id,
            'amount' => Money::decimal($amount),
            'transferDate' => now()->toDateString(),
            'description' => ucfirst($actorType).' shift close '.$shift->id,
            'idempotencyKey' => self::idempotencyKey((int) $shift->id),
        ], (int) $shift->user_id, true);
        DB::table('cash_transfers')->where('tenant_id', $tenantId)->where('id', $transfer->id)
            ->update(['shift_id' => $shift->id, 'actor_type' => $actorType, 'updated_at' => now()]);

        return (int) $transfer->id;
    }
}
