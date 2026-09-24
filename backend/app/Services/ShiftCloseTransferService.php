<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Creates the one transfer for a locked, open shift inside its closing transaction. */
final class ShiftCloseTransferService
{
    public function __construct(
        private readonly CashTransferService $transfers,
        private readonly FinancialAccountBalanceQuery $balances,
    ) {}

    public function create(Request $request, int $tenantId, object $shift, int $countedCents, string $actorType): ?int
    {
        $floatCents = Money::cents($shift->closing_float_amount);
        if ($floatCents < 0 || $countedCents < 0 || $countedCents < $floatCents) {
            throw ValidationException::withMessages(['closingCash' => 'Counted cash must cover the configured closing float.']);
        }
        if (! $shift->financial_location_id || ! $shift->close_destination_financial_location_id) {
            throw ValidationException::withMessages(['destination' => 'A valid shift drawer and close destination are required.']);
        }

        $location = function (int $id, bool $drawer) use ($tenantId, $shift): ?object {
            return DB::table('financial_locations as locations')
                ->join('financial_accounts as accounts', function ($join) use ($tenantId): void {
                    $join->on('accounts.id', '=', 'locations.financial_account_id')->where('accounts.tenant_id', '=', $tenantId);
                })
                ->where('locations.tenant_id', $tenantId)->where('locations.id', $id)
                ->where('locations.kind', 'cash')->where('locations.is_active', true)
                ->where('accounts.is_active', true)->whereNull('accounts.deleted_at')
                ->where(function ($query) use ($drawer, $shift): void {
                    if ($drawer) {
                        $query->where('locations.branch_id', $shift->branch_id);
                    } else {
                        $query->whereNull('locations.branch_id')->orWhere('locations.branch_id', $shift->branch_id);
                    }
                })
                ->when($drawer, fn ($query) => $query->where('locations.type', 'cash_drawer'))
                ->select('locations.id', 'locations.financial_account_id')->lockForUpdate()->first();
        };
        $source = $location((int) $shift->financial_location_id, true);
        $destination = $location((int) $shift->close_destination_financial_location_id, false);
        if (! $source || ! $destination || (int) $source->id === (int) $destination->id) {
            throw ValidationException::withMessages(['destination' => 'The close destination must be an active cash location for this tenant, different from the shift drawer.']);
        }

        $ledgerCents = Money::cents($this->balances->summary(
            $tenantId, (int) $source->financial_account_id, locationId: (int) $source->id,
        )['balance']);
        if ($ledgerCents !== $countedCents) {
            throw ValidationException::withMessages(['closingCash' => 'The drawer ledger balance does not match counted cash. Reconcile the opening cash and posted cash movements before closing.']);
        }

        $amount = $countedCents - $floatCents;
        if ($amount === 0) return null;

        $transfer = $this->transfers->create($request, $tenantId, [
            'branchId' => (int) $shift->branch_id,
            'fromFinancialLocationId' => (int) $source->id,
            'toFinancialLocationId' => (int) $destination->id,
            'amount' => Money::decimal($amount),
            'transferDate' => now()->toDateString(),
            'description' => ucfirst($actorType).' shift close '.$shift->id,
            'idempotencyKey' => 'shift-close-transfer:'.$shift->id,
        ], (int) $shift->user_id, true);
        DB::table('cash_transfers')->where('tenant_id', $tenantId)->where('id', $transfer->id)
            ->update(['shift_id' => $shift->id, 'actor_type' => $actorType, 'updated_at' => now()]);

        return (int) $transfer->id;
    }
}
