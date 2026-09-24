<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Resolves only cash locations proven by the order's shift or posted sale. */
final class PosCashLocationResolver
{
    public function forSale(int $tenantId, object $order, string $accountCode): int
    {
        $shift = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $order->shift_id)
            ->where('branch_id', $order->branch_id)->where('status', 'open')->whereNull('deleted_at')
            ->lockForUpdate()->first();
        if (! $shift || ! $shift->financial_location_id) {
            throw ValidationException::withMessages(['shiftId' => 'The order shift has no valid cash drawer.']);
        }

        $location = $this->validLocation($tenantId, (int) $order->branch_id, (int) $shift->financial_location_id, $accountCode, true);
        if (! $location) {
            throw ValidationException::withMessages(['shiftId' => 'The order shift cash drawer is invalid or does not match the cash payment account.']);
        }

        return (int) $location->id;
    }

    /** Historical sales without a proven location retain an unlocated refund. */
    public function forRefund(int $tenantId, object $order, object $payment, string $accountCode): ?int
    {
        $saleLocationIds = DB::table('journal_entries as entries')
            ->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')
            ->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('entries.tenant_id', $tenantId)->where('entries.branch_id', $order->branch_id)
            ->where('entries.source_type', 'pos_order')->where('entries.source_id', $order->id)
            ->where('entries.source_event', 'POS_ORDER_PAID')->where('entries.status', 'posted')
            ->where('lines.tenant_id', $tenantId)->where('accounts.tenant_id', $tenantId)
            ->where('accounts.code', $accountCode)->where('lines.debit', '>', 0)
            ->pluck('lines.financial_location_id')->all();

        if (count($saleLocationIds) !== 1 || $saleLocationIds[0] === null
            || $payment->shift_id === null || (int) $payment->shift_id !== (int) $order->shift_id) {
            return null;
        }

        $locationId = (int) $saleLocationIds[0];
        $shiftExists = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $payment->shift_id)
            ->where('branch_id', $order->branch_id)->exists();
        if (! $shiftExists) {
            return null;
        }

        return $this->validLocation($tenantId, (int) $order->branch_id, $locationId, $accountCode, false, false)
            ? $locationId : null;
    }

    private function validLocation(int $tenantId, int $branchId, int $locationId, string $accountCode, bool $lock = false, bool $active = true): ?object
    {
        $query = DB::table('financial_locations as locations')
            ->join('financial_accounts as accounts', function ($join) use ($tenantId): void {
                $join->on('accounts.id', '=', 'locations.financial_account_id')->where('accounts.tenant_id', '=', $tenantId);
            })
            ->where('locations.tenant_id', $tenantId)->where('locations.id', $locationId)
            ->where('locations.branch_id', $branchId)->where('locations.kind', 'cash')
            ->where('locations.type', 'cash_drawer')
            ->where('accounts.code', $accountCode)->where('accounts.is_active', true)->whereNull('accounts.deleted_at')
            ->select('locations.id');
        if ($active) $query->where('locations.is_active', true);
        if ($lock) $query->lockForUpdate();

        return $query->first();
    }
}
