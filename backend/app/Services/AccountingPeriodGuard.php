<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** The single guard for every transition from a draft into the posted ledger. */
final class AccountingPeriodGuard
{
    public function assertPostingAllowed(int $tenantId, string $entryDate): void
    {
        $period = DB::table('accounting_periods')
            ->where('tenant_id', $tenantId)
            ->whereDate('start_date', '<=', $entryDate)
            ->whereDate('end_date', '>=', $entryDate)
            ->whereIn('status', ['closed', 'locked'])
            ->orderByDesc('id')
            ->first(['id', 'status', 'name']);

        if (! $period) {
            return;
        }

        $message = $period->status === 'locked'
            ? 'الفترة المحاسبية لهذا التاريخ مقفلة بشكل نهائي ولا يمكن الترحيل إليها.'
            : 'الفترة المحاسبية لهذا التاريخ مغلقة، يرجى مراجعة المحاسب المسؤول.';
        throw ValidationException::withMessages(['accountingPeriod' => [$message]]);
    }
}
