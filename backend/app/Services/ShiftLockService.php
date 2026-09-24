<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Canonical primitive for any write that depends on a shift *remaining open*
 * for the life of its own transaction: order creation, payment attachment,
 * cash refunds, shift cash movements. It acquires a row lock on `shifts` that
 * is held until the caller's transaction commits or rolls back, so the caller
 * can never observe a shift as "open" that shifts:reconcile-overlap is
 * concurrently in the process of closing (H1).
 *
 * Two lock strengths are offered:
 *  - sharedOpenShift(): `SELECT ... FOR SHARE`. Any number of operational
 *    writers may hold this concurrently on the same shift, but it blocks (and
 *    is blocked by) reconciliation's exclusive `FOR UPDATE` lock on the same
 *    row for the writer's whole transaction. This is what payment attachment
 *    and order creation use — they never mutate the shift row itself.
 *  - exclusiveOpenShift(): `SELECT ... FOR UPDATE`, for writers that also
 *    mutate the shift row (cash movements, refunds already use lockForUpdate
 *    directly via ShiftCloseService/PosCashLocationResolver callers).
 *
 * Lock order: callers MUST lock their own domain rows (order, payment,
 * finance_document, ...) BEFORE calling here — the shift lock is always taken
 * last, immediately before the write that depends on it. Reconciliation only
 * ever locks `financial_locations` then `shifts` (never orders/payments), so
 * this ordering has no lock-order cycle with reconciliation. See
 * ShiftOverlapReconciliationService for the reconciliation side of this
 * contract.
 */
final class ShiftLockService
{
    public function sharedOpenShift(int $tenantId, int $shiftId, ?int $branchId = null, ?int $userId = null): object
    {
        return $this->lockedOpenShift($tenantId, $shiftId, $branchId, $userId, false);
    }

    public function exclusiveOpenShift(int $tenantId, int $shiftId, ?int $branchId = null, ?int $userId = null): object
    {
        return $this->lockedOpenShift($tenantId, $shiftId, $branchId, $userId, true);
    }

    private function lockedOpenShift(int $tenantId, int $shiftId, ?int $branchId, ?int $userId, bool $exclusive): object
    {
        $query = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shiftId)->whereNull('deleted_at');
        if ($branchId !== null) {
            $query->where('branch_id', $branchId);
        }
        if ($userId !== null) {
            $query->where('user_id', $userId);
        }
        $exclusive ? $query->lockForUpdate() : $query->sharedLock();
        $shift = $query->first();

        if (! $shift || $shift->status !== 'open') {
            throw ValidationException::withMessages([
                'shiftId' => 'No open shift found. Open a shift before continuing.',
            ]);
        }

        return $shift;
    }
}
