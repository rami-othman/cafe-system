<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class AutomaticShiftCloseService
{
    public function __construct(private readonly ShiftCashSummaryService $cash, private readonly CashTransferService $transfers) {}

    public function close(int $tenantId, int $shiftId): void
    {
        DB::transaction(function () use ($tenantId, $shiftId): void {
            $shift = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shiftId)->lockForUpdate()->first();
            if (! $shift || $shift->status !== 'open') return;
            if (! $shift->close_destination_financial_location_id) {
                throw ValidationException::withMessages(['destination' => 'لم يتم تحديد وجهة النقد عند إغلاق الوردية لهذا الفرع.']);
            }
            $pendingCheck = DB::table('bar_check_templates as t')
                ->where('t.tenant_id', $tenantId)->where('t.branch_id', $shift->branch_id)
                ->where('t.is_active', true)->where('t.required_for_shift_close', true)
                ->whereNotExists(fn ($query) => $query->selectRaw('1')->from('stock_counts as c')
                    ->whereColumn('c.bar_check_template_id', 't.id')->where('c.shift_id', $shift->id)
                    ->where('c.status', 'posted'))->exists();
            if ($pendingCheck) {
                throw ValidationException::withMessages(['barCheck' => 'Complete the required bar check before closing the shift.']);
            }
            $summary = $this->cash->summarize($tenantId, $shift);
            $amount = max(0, Money::cents($summary['expectedCash']) - Money::cents($shift->closing_float_amount));
            $transferId = null;
            if ($amount > 0) {
                $request = Request::create('/internal/shift-close', 'POST');
                $request->attributes->set('auth_user', \App\Models\User::query()->where('tenant_id', $tenantId)->findOrFail($shift->user_id));
                $transfer = $this->transfers->create($request, $tenantId, [
                    'branchId' => (int) $shift->branch_id,
                    'fromFinancialLocationId' => (int) $shift->financial_location_id,
                    'toFinancialLocationId' => (int) $shift->close_destination_financial_location_id,
                    'amount' => Money::decimal($amount),
                    'transferDate' => now()->toDateString(),
                    'description' => 'Automatic shift close '.$shift->id,
                    'idempotencyKey' => 'shift-close-transfer:'.$shift->id,
                ], (int) $shift->user_id);
                $transferId = $transfer->id;
                DB::table('cash_transfers')->where('id', $transferId)->update(['shift_id' => $shift->id, 'actor_type' => 'system']);
            }
            DB::table('shifts')->where('id', $shift->id)->update([
                'expected_cash' => $summary['expectedCash'], 'closing_cash' => null,
                'cash_difference' => '0.00', 'close_type' => 'automatic',
                'close_transfer_id' => $transferId, 'status' => 'closed',
                'closed_at' => now(), 'updated_at' => now(),
            ]);
        });
    }
}
