<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** The single guard for every transition from a draft into the posted ledger. */
final class AccountingPeriodGuard
{
    public function assertPostingAllowed(int $tenantId, string $entryDate): void
    {
        // An expired fiscal year must be closed before work can enter the
        // next year. Shorter monthly/quarterly periods are unaffected.
        $expiredYear = DB::table('accounting_periods')
            ->where('tenant_id', $tenantId)->where('status', 'open')
            ->whereDate('end_date', '<', $entryDate)
            ->whereRaw('(end_date - start_date) >= 300')
            ->orderBy('end_date')->first(['id', 'name', 'end_date']);
        if ($expiredYear) {
            throw ValidationException::withMessages(['accountingPeriod' => [
                "يجب إقفال السنة المحاسبية «{$expiredYear->name}» المنتهية في {$expiredYear->end_date} قبل ترحيل عمليات جديدة.",
            ]]);
        }
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
