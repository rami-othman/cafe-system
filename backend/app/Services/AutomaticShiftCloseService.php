<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Unattended close at the branch's configured shift_close_time. It uses the
 * exact same primitives as the manual close (ShiftCloseService ->
 * ShiftCashSummaryService -> ShiftCloseTransferService); there is no separate
 * accounting algorithm here.
 *
 * No physical count exists, so closing_cash stays NULL and close_type is
 * `automatic`: reports present it as an expected (uncounted) close.
 */
final class AutomaticShiftCloseService
{
    public function __construct(private readonly ShiftCloseService $closer) {}

    /** @return bool true when this call closed the shift, false when it was already closed/absent */
    public function close(int $tenantId, int $shiftId): bool
    {
        return DB::transaction(function () use ($tenantId, $shiftId): bool {
            $shift = $this->closer->lock($tenantId, $shiftId);
            if (! $shift || $shift->status !== 'open') {
                return false;
            }
            $request = Request::create('/internal/shift-close', 'POST');
            $request->attributes->set('auth_user', User::query()->where('tenant_id', $tenantId)->findOrFail($shift->user_id));
            $this->closer->close($request, $tenantId, $shift, ShiftCloseService::TYPE_AUTOMATIC, null);

            return true;
        });
    }
}
